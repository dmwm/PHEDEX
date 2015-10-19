package PHEDEX::File::Download::Circuits::ResourceManager;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging', 'Exporter';

use List::Util qw(min);
use Module::Load;
use POE;
use Switch;

use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::File::Download::Circuits::Helpers::GenericFunctions;
use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpServer;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;
use PHEDEX::File::Download::Circuits::Constants;

my $ownHandles = {
    HANDLE_TIMER        =>      'handleTimer',
    REQUEST_CIRCUIT     =>      'requestCircuit',
    REQUEST_BW          =>      'requestBandwidth',
    REQUEST_REPLY       =>      'handleRequestResponse',
    VERIFY_STATE        =>      'verifyStateConsistency',
};

my $backHandles = {
	BACKEND_UPDATE_BANDWIDTH    =>      'backendUpdateBandwidth',
    BACKEND_REQUEST_CIRCUIT     =>      'backendRequestCircuit',
    BACKEND_TEARDOWN_CIRCUIT    =>      'backendTeardownCircuit',
};

# Right now we only support the creation of *one* circuit for each link {(from, to) node pair}
# This assumption implies that each {(from, to) node pair} is unique
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (

            # Main circuit related parameters
            # TODO: Allow the use of more than one circuit/bandwidth available per link pair
            RESOURCES                       => {},          # All online resources grouped by link (requesting/established circuits, online/updating bandwidth)
            STATE_DIR                       => '',          # Default location to place circuit state files
            SCOPE                           =>  'GENERIC',  # NOT USED atm

            # Resource booking backend options
            # TODO: Allow the use of multiple backends (may not be the same backend for circuits or BW)
            BACKEND_TYPE                    => 'Dummy',
            BACKEND                         => undef,

            # Parameters related to circuit history
            RESOURCE_HISTORY                => {},          # Last MAX_HISTORY_SIZE circuits, which are offline, grouped by link the ID (LINK -> ID -> [CIRCUIT1,...])
            RESOURCE_HISTORY_QUEUE          => [],          # Queue used to keep track of previously active resources (now in 'offline' mode)
            MAX_HISTORY_SIZE                => 1000,        # Keep the last xx circuits in memory
            SYNC_HISTORY_FOLDER             => 0,           # If this is set, it will also remove circuits from 'offline' folder


            # Parameters related to blacklisting circuist
	  	    LINKS_BLACKLISTED               => {},          # All links currently blacklisted from creating circuits
            BLACKLIST_DURATION              => HOUR,        # Time in seconds, after which a circuit will be reconsidered
            MAX_HOURLY_FAILURE_RATE         => 100,         # Maximum of 100 (file) transfers in one hour can fail. Note that failure can be caused by other reasons than circuit prb.

            # Parameters related to various timings
            PERIOD_CONSISTENCY_CHECK        => MINUTE,      # Period for event verify_state_consistency
            REQUEST_TIMEOUT                 => 5 * MINUTE,  # If we don't get it by then, we'll most likely not get them at all

            # POE related stuff
            SESSION_ID                      => undef,
            DELAYS                          => undef,

            # Allows the Circuit Manager to be controlled directly via HTTP
            HTTP_CONTROL                    => 0,           # Enable (or not) control of the ResourceManager via web
            HTTP_HOSTNAME                   => 'localhost',
            HTTP_PORT                       => 8080,
            
            HTTP_SERVER                     => undef,
            HTTP_HANDLE_DETAILS             => [
                                                { HANDLER => 'handleHTTPCircuitCreation', URI => '/createCircuit', METHOD => "POST"},
                                                { HANDLER => 'handleHTTPCircuitTeardown', URI => '/removeCircuit', METHOD => "POST"},
                                                { HANDLER => 'handleHTTPinfo', URI => '/getInfo', METHOD => "GET"},
                                               ],

            # Other parameters
            VERBOSE                         => 0,
        );

    my %args = (@_);
    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    # Load circuit booking backend
    my $backend = $args{BACKEND_TYPE};
    my %backendArgs = defined %{$args{BACKEND_ARGS}} ? %{$args{BACKEND_ARGS}} : undef;
    
    # Import and create backend
    eval {
        # Import backend at runtime
        my $module = "PHEDEX::File::Download::Circuits::Backend::$backend";
        (my $file = $module) =~ s|::|/|g;
        require $file . '.pm';
        $module->import();
        
        # Create new backend after import
        $self->{BACKEND} = new $module(%backendArgs);
    } or do {
        die "Failed to load/create backend: $@\n"
    };
    
    if ($self->{HTTP_CONTROL}) {
        $self->{HTTP_SERVER} = PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpServer->new();
        $self->{HTTP_SERVER}->startServer($self->{HTTP_HOSTNAME}, $self->{HTTP_PORT});
    }

    bless $self, $class;
    return $self;
}

=pod

# Initialize all POE events (and specifically those related to circuits)

=cut

sub _poe_init
{
    my ($self, $kernel, $session) = @_;
    my $msg = 'ResourceManager->_poe_init';

    # Remembering the session ID for when we need to stop and tear down all the circuits
    $self->{SESSION_ID} = $session->ID;

    $self->Logmsg("$msg: Initializing all POE events") if ($self->{VERBOSE});

    foreach my $key (keys %{$ownHandles}) {
        $kernel->state($ownHandles->{$key}, $self);
    }

    # Share the session with the circuit booking backend as well
    $self->Logmsg("$msg: Initializing all POE events for backend") if ($self->{VERBOSE});
    $self->{BACKEND}->_poe_init($kernel, $session);

    # Get the periodic events going
    $kernel->yield($ownHandles->{VERIFY_STATE}) if (defined $self->{PERIOD_CONSISTENCY_CHECK});

    # Add the handlers for the HTTP events which we want to process
    if (defined $self->{HTTP_SERVER}) {
        foreach my $situation (@{$self->{HTTP_HANDLE_DETAILS}}) {
            $kernel->state($situation->{HANDLER}, $self);
            $self->{HTTP_SERVER}->addHandler($situation->{METHOD}, $situation->{URI}, $session->postback($situation->{HANDLER}, $self));
        }
    }
}

# Returns the *online* resource, if it exists for a particular link
sub getManagedResource {
    my $msg = "ResourceManager->getManagedResource";
    my ($self, $nodeA, $nodeB, $type) = @_;
    
    if (! defined $nodeA || ! defined $nodeB) {
        $self->Logmsg("$msg: Cannot do anything without valid nodes");
        return;
    }
    
    my $linkID = &getPath($nodeA, $nodeB);
    my $resource = $self->{RESOURCES}{$linkID};
    
    if (! defined $resource) {
        $self->Logmsg("$msg: Unable to find useful resources");
        return;
    }
    
    if ($resource->{STATUS} == STATUS_UPDATING || $resource->{STATUS} == STATUS_UPDATING) {
        $self->Logmsg("$msg: Found resources but they are busy with updates");
        return;
    }
    
    # If we didn't define the type or the type matches what we requested, return the resource which we found
    if (! defined $type || $resource->{RESOURCE_TYPE} eq $type) {
        $self->Logmsg("$msg: Found usable resource");
        return $resource;
    } else {
        $self->Logmsg("$msg: Found resources but it's not matching what we requested");
        return;
    }
}

# TODO: Needs a revision based on workflow
# Method used to check if we can request a certain resource
# - it checks with the backend to see if it supports managing the resource type 
# - it checks with the backend to see if the link supports it
# - it checks if a resource hasn't already been requested/is online
# - it checks if the link isn't currently blacklisted
sub canRequestResource {
    my $msg = "ResourceManager->canRequestResource";
    my ($self, $nodeA, $nodeB, $type) = @_;
    
    if (! defined $nodeA || ! defined $nodeB || ! defined $type) {
        $self->Logmsg("$msg: Cannot do anything without valid parameters");
        return;
    }
    
    my $linkID = &getPath($nodeA, $nodeB);
    my $resource = $self->{RESOURCES}{$linkID};

    # A resource is already online (or updating/requesting)
    if (defined $resource) {
        $self->Logmsg("$msg: A resource already exists for the given link");
        return RESOURCE_ALREADY_EXISTS;
    }
    
    # Current link is blacklisted
    my $blacklisted = $self->{LINKS_BLACKLISTED}{$linkID};
    if ($blacklisted) {
        $self->Logmsg("$msg: Link is blacklisted");
        return LINK_BLACKLISTED;
    }
    
    # Current backend doesn't support the type of resource we're interested in
    if ($self->{BACKEND}->{SUPPORTED_RESOURCE} ne $type) {
        $self->Logmsg("$msg: Current backend doesn't support the type of resource we're interested in");
        return RESOURCE_TYPE_UNSUPPORTED;
    }
    
    # Cannot request resource on given link
    if (!$self->{BACKEND}->checkLinkSupport($nodeA, $nodeB)) {
        $self->Logmsg("$msg: Cannot request resource on given link");
        return LINK_UNSUPPORTED;
    }

    return RESOURCE_REQUEST_POSSIBLE;
}

# This (recurrent) event is used to ensure consistency between data on disk and data in memory
# If the download agent crashed, these are scenarios that we need to check for:
#   internal data is lost, but file(s) exist in :
#   - circuits/requested
#   - circuits/online
#   - circuits/offline
#   - bod/online
#   - bod/offline
sub verifyStateConsistency
{
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION];
    my $msg = "ResourceManager->$ownHandles->{VERIFY_STATE}";

    $self->Logmsg("$msg: enter event") if ($self->{VERBOSE});
    $self->delay_max($kernel, $ownHandles->{VERIFY_STATE}, $self->{PERIOD_CONSISTENCY_CHECK}) if (defined $self->{PERIOD_CONSISTENCY_CHECK});

    my ($allResources, @circuits, @bod);
    # Read all the folders for each resource time (online, offline, etc)
    &getdir($self->{STATE_DIR}."/circuits", \@circuits);
    &getdir($self->{STATE_DIR}."/bod", \@bod);
    
    # For each circuit folder, add what you find to the resource hash with the appropiate tag
    foreach my $tag (@circuits) {
        my @circuitsSubset;
        &getdir($self->{STATE_DIR}."/circuits/".$tag, \@circuitsSubset);
        $allResources->{'circuits/'.$tag} = \@circuitsSubset;
    }
    
    # For each bandwidth folder, add what you find to the resource hash with the appropiate tag
    foreach my $tag (@bod) {
        my @bodSubset;
        &getdir($self->{STATE_DIR}."/bod/".$tag, \@bodSubset);
        $allResources->{'bod/'.$tag} = \@bodSubset;
    }
    
    my $timeNow = &mytimeofday();

    foreach my $tag (keys %{$allResources}) {

        # Skip if there are no files in one of the folders
        if (!scalar @{$allResources->{$tag}}) {
            $self->Logmsg("$msg: No files found in /$tag") if ($self->{VERBOSE});
            next;
        }

        foreach my $file (@{$allResources->{$tag}}) {
            my $path = $self->{STATE_DIR}.'/'.$tag.'/'.$file;
            $self->Logmsg("$msg: Now handling $path") if ($self->{VERBOSE});

            # Attempt to open resource
            my $resource = &openState($path);

            # Remove the state file if the read didn't return OK
            if (!$resource) {
                $self->Logmsg("$msg: Removing invalid resource file $path");
                unlink $path;
                next;
            }
            
            if ($resource->checkCorrectPlacement($path) == ERROR_GENERIC) {
                $self->Logmsg("$msg: Resource found in incorrect folder. Removing and resaving...");
                unlink $path;
                $resource->saveState();
            }

            my $linkName = $resource->{NAME};

            # The following three IFs could very well have been condensed into one, but
            # I wanted to provide custom debug messages whenever we skipped them

            # If the scope doesn't match
            if ($self->{SCOPE} ne $resource->{SCOPE}) {
                $self->Logmsg("$msg: Skipping resource since its scope don't match ($resource->{SCOPE} vs $self->{SCOPE})")  if ($self->{VERBOSE});
                next;
            }

            # If the backend doesn't match the one we have here, skip it
            if ($resource->{BOOKING_BACKEND} ne $self->{BACKEND_TYPE}) {
                $self->Logmsg("$msg: Skipping resource due to different backend used ($resource->{BOOKING_BACKEND} vs $self->{BACKEND_TYPE})") if ($self->{VERBOSE});
                next;
            }

            # If the backend no longer supports circuits on those links, skip them as well
            if (! $self->{BACKEND}->checkLinkSupport($resource->{NODE_A}, $resource->{NODE_B})) {
                $self->Logmsg("$msg: Skipping resource since the backend no longer supports creation of circuits on $linkName") if ($self->{VERBOSE});
                next;
            }

            my $inMemoryResource;

            # Attempt to retrieve the resource if it's in memory
            switch ($tag) {
                case ["circuits/offline","bod/offline"] {
                    my $offlineResources = $self->{RESOURCE_HISTORY}{$linkName};
                    $inMemoryResource = $offlineResources->{$resource->{ID}} if (defined $offlineResources && defined $offlineResources->{$resource->{ID}});
                }
                else {
                    $inMemoryResource = $self->{RESOURCES}{$linkName};
                }
            };

            # Skip this one if we found an identical circuit in memory
            if (&compareResource($self, $inMemoryResource)) {
                $self->Logmsg("$msg: Skipping identical in-memory resource") if ($self->{VERBOSE});
                next;
            }

            # If, for the same link, the info differs between on disk and in memory,
            # yet the scope of the circuit is the same as the one for the CM
            # remove the one on disk and force a resave for the one in memory
            if (defined $inMemoryResource) {
                 $self->Logmsg("$msg: Removing similar circuit on disk and forcing resave of the one in memory");
                 unlink $path;
                 $inMemoryResource->saveState();
                 next;
            }

            # If we get to here it means that we didn't find anything in memory pertaining to a given link
            
            switch ($tag) {
                case 'circuits/requested' {
                    # This is a bit tricky to handle.
                    #   1) The circuit could still be 'in request'. If the booking agent died as well
                    #      then the circuit could be created and not know about it :|
                    #   2) The circuit might be online by now
                    # What we do now is flag the circuit as offline, then have it in the offline thing for historical purposes
                    # TODO : Another solution would be to wait a bit of time then attempt to 'teardown' the circuit
                    # This would ensure that everything is 'clean' after this method
                    unlink $path;
                    $resource->registerRequestFailure('Failure to restore request from disk');
                    $resource->saveState();
                }
                case 'circuits/online' {
                    # Skip circuit if the link is currently blacklisted
                    if (defined $self->{LINKS_BLACKLISTED}{$linkName}) {
                        $self->Logmsg("$msg: Skipping circuit since $linkName is currently blacklisted");
                        # We're not going to remove the file. It might be useful once the blacklist timer expires
                        next;
                    }

                    # Now there are two cases:
                    if (! defined $resource->{LIFETIME} ||                                                                           # If the loaded circuit has a defined Lifetime parameter
                        (defined $resource->{LIFETIME} && ! $resource->isExpired())) {                                                # and it's not expired

                        # Use the circuit
                        $self->Logmsg("$msg: Found established circuit $linkName. Using it");
                        $self->{RESOURCES}{$linkName} = $resource;

                        if (defined $resource->{LIFETIME}) {
                            my $delay = $resource->getExpirationTime() - &mytimeofday();
                            next if $delay < 0;
                            $self->Logmsg("$msg: Established circuit has lifetime defined. Starting timer for $delay");
                            $self->delayAdd($kernel, $ownHandles->{HANDLE_TIMER}, $delay, TIMER_TEARDOWN, $resource);
                        }

                    } else {                                                                                                        # Else we attempt to tear it down
                        $self->Logmsg("$msg: Attempting to teardown expired circuit $linkName");
                        $self->handleCircuitTeardown($kernel, $session, $resource);
                    }
                }
                case ['circuits/offline', 'bod/offline'] {
                    # Don't add the circuit if the history is full and circuit is older than the oldest that we currently have on record
                    my $oldestCircuit = $self->{RESOURCE_HISTORY_QUEUE}->[0];
                    if (scalar @{$self->{RESOURCE_HISTORY_QUEUE}} < $self->{MAX_HISTORY_SIZE} ||
                        !defined $oldestCircuit || $resource->{LAST_STATUS_CHANGE} > $oldestCircuit->{LAST_STATUS_CHANGE}) {
                        $self->Logmsg("$msg: Found offline circuit. Adding it to history");
                        $self->addResourceToHistory($resource);
                    }
                }
            }
        }
    }
}

# Adds a resource to RESOURCE_HISTORY
sub addResourceToHistory {
    my ($self, $resource) = @_;

    my $msg = "ResourceManager->addResourceToHistory";

    if (! defined $resource) {
        $self->Logmsg("$msg: Invalid resource provided");
        return;
    }

    if (scalar @{$self->{RESOURCE_HISTORY_QUEUE}} >= $self->{MAX_HISTORY_SIZE}) {
        eval {
            # Remove oldest circuit from history
            my $oldestResource = shift @{$self->{RESOURCE_HISTORY_QUEUE}};
            $self->Logmsg("$msg: Removing oldest resource from history ($oldestResource->{ID})") if $self->{VERBOSE};
            delete $self->{RESOURCE_HISTORY}{$oldestResource->getLinkName()}{$oldestResource->{ID}};
            $oldestResource->removeState() if ($self->{SYNC_HISTORY_FOLDER});
        }
    }

    $self->Logmsg("$msg: Adding resource ($resource->{ID}) to history");

    # Add to history
    eval {
        push @{$self->{RESOURCE_HISTORY_QUEUE}}, $resource;
        $self->{RESOURCE_HISTORY}{$resource->{NAME}}{$resource->{ID}} = $resource;
    }
}

# Blacklists a link and starts a timer to unblacklist it after BLACKLIST_DURATION
sub addLinkToBlacklist {
    my ($self, $resource, $fault, $delay) = @_;

    my $msg = "ResourceManager->addLinkToBlacklist";

    if (! defined $resource) {
        $self->Logmsg("$msg: Invalid resource provided");
        return;
    }

    my $linkName = $resource->{NAME};
    $delay = $self->{BLACKLIST_DURATION} if ! defined $delay;

    $self->Logmsg("$msg: Adding link ($linkName) to history. It will be removed after $delay seconds");

    $self->{LINKS_BLACKLISTED}{$linkName} = $fault;
    $self->delayAdd($poe_kernel, $ownHandles->{HANDLE_TIMER}, $delay, TIMER_BLACKLIST, $resource);
}

# This routine is called by the CircuitAgent when a transfer fails
# If too many transfer fail, it will teardown and blacklist the circuit
sub transferFailed {
    my ($self, $circuit, $task) = @_;

    my $msg = "ResourceManager->transferFailed";

    if (!defined $circuit || !defined $task) {
        $self->Logmsg("$msg: Circuit or code not defined");
        return;
    }

    if ($circuit->{STATUS} != STATUS_ONLINE) {
        $self->Logmsg("$msg: Can't do anything with this circuit");
        return;
    }

    # Tell the circuit that a transfer failed on it
    $circuit->registerTransferFailure($task);

    my $transferFailures = $circuit->getFailedTransfers();
    my $lastHourFails;
    my $now = &mytimeofday();

    foreach my $fails (@{$transferFailures}) {
        $lastHourFails++ if ($fails->[0] > $now - HOUR);
    }

    my $linkName = $circuit->{NAME};

    if ($lastHourFails > $self->{MAX_HOURLY_FAILURE_RATE}) {
        $self->Logmsg("$msg: Blacklisting $linkName due to too many transfer failures");

        # Blacklist the circuit
        $self->addLinkToBlacklist($circuit, CIRCUIT_TRANSFERS_FAILED);

        # Tear it down
        $self->handleCircuitTeardown($poe_kernel, $poe_kernel->ID_id_to_session($self->{SESSION_ID}), $circuit);
    }
}

sub requestResource {
    my ( $self, $nodeA, $nodeB, $type) = @_;

    my $msg = "ResourceManager->requestResource";

    # Check if link is defined
    if (!defined $nodeA || !defined $nodeB) {
        $self->Logmsg("$msg: Provided link is invalid - will not attempt a request");
        return;
    }

    # Check with circuit booking backend to see if the nodes actually support circuits
    if (! $self->{BACKEND}->checkLinkSupport($nodeA, $nodeB)) {
        $self->Logmsg("$msg: Provided link does not support managed resources");
        return;
    }

    my $linkName = &getPath($nodeA, $nodeB);

    if ($self->{LINKS_BLACKLISTED}{$linkName}) {
        $self->Logmsg("$msg: Skipping request for $linkName since it is currently blacklisted");
        return;
    }

    if (defined $self->{RESOURCES}{$linkName} && 
        $self->{RESOURCES}{$linkName}{RESOURCE_TYPE} ne $type) {
        $self->Logmsg("$msg: There's a resource already provisioned and it's not the type you requested");
        return;
    }

    return $linkName;
}

sub requestBandwidth {
    my ( $self, $kernel, $session, $nodeA, $nodeB, $bandwidth) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1, ARG2 ];

    my $msg = "ResourceManager->$ownHandles->{REQUEST_BW}";

    my $linkName = $self->requestResource($nodeA, $nodeB, BOD);	
    return if !defined $linkName;

    my $resource;

    # Check if a bandwidth is not already provisioned
    if (defined $self->{RESOURCES}{$linkName}) {
        $resource = $self->{RESOURCES}{$linkName};      
    } else {
        $resource = PHEDEX::File::Download::Circuits::ManagedResource::Bandwidth->new(STATE_DIR => $self->{STATE_DIR},
                                                                                      SCOPE => $self->{SCOPE},
                                                                                      VERBOSE => $self->{VERBOSE});
        $resource->initResource($self->{BACKEND_TYPE}, $nodeA, $nodeB, 1);
    }

    # Switch from the 'offline' to 'requesting' state, save to disk and store this in our memory
    eval {
        $resource->registerUpdateRequest($bandwidth, 1);
        $self->{RESOURCES}{$linkName} = $bandwidth;
        $resource->saveState();

        # Start the watchdog in case the request times out
        $self->delayAdd($kernel, $ownHandles->{HANDLE_TIMER}, $resource->{REQUEST_TIMEOUT}, TIMER_REQUEST, $resource);
        $kernel->post($session, $backHandles->{BACKEND_UPDATE_BANDWIDTH}, $resource, $ownHandles->{REQUEST_REPLY});
    };
}

sub requestCircuit {
    my ( $self, $kernel, $session, $nodeA, $nodeB, $lifetime, $bandwidth) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1, ARG2, ARG3 ];

    my $msg = "ResourceManager->$ownHandles->{REQUEST_CIRCUIT}";

    my $linkName = $self->requestResource($nodeA, $nodeB, CIRCUIT);
    return if !defined $linkName;

    # Check if a circuit is not already provisioned
    if ($self->{RESOURCES}{$linkName}) {
        $self->Logmsg("$msg: Skipping request, since a circuit has already been provisiond (requested/established) on $linkName");
        return;
    }

    $self->Logmsg("$msg: Attempting to request a circuit for link $linkName");
    defined $lifetime ? $self->Logmsg("$msg: Lifetime for link $linkName is $lifetime seconds") :
                        $self->Logmsg("$msg: Lifetime for link $linkName is the maximum allowable by IDC");

    # Create the circuit object
    my $circuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new(STATE_DIR => $self->{STATE_DIR},
                                                                                  SCOPE => $self->{SCOPE},
                                                                                  VERBOSE => $self->{VERBOSE});
    $circuit->initResource($self->{BACKEND_TYPE}, $nodeA, $nodeB, 0);
    $circuit->{REQUEST_TIMEOUT} = $self->{REQUEST_TIMEOUT};

    $self->Logmsg("$msg: Created circuit in request state for link $linkName (Circuit ID = $circuit->{ID})");

    # Switch from the 'offline' to 'requesting' state, save to disk and store this in our memory
    eval {
        $circuit->registerRequest($lifetime, $bandwidth);
        $self->{RESOURCES}{$linkName} = $circuit;
        $circuit->saveState();

        # Start the watchdog in case the request times out
        $self->delayAdd($kernel, $ownHandles->{HANDLE_TIMER}, $circuit->{REQUEST_TIMEOUT}, TIMER_REQUEST, $circuit);

        $kernel->post($session, $backHandles->{BACKEND_REQUEST_CIRCUIT}, $circuit, $ownHandles->{REQUEST_REPLY});
    };

}

# This method is called when a circuit request fails.
# This is either because the request itself failed (got a reply and an error code) or
# the request timed out. In either case, this is obviously bad and what needs doing
# is the same in both cases
sub handleRequestFailure {
    my ($self, $resource, $code) = @_;

    my $msg = "ResourceManager->handleRequestFailure";

    if (!defined $resource) {
        $self->Logmsg("$msg: No circuit was provided");
        return;
    }

    my $linkName = $resource->{NAME};

    if ($resource->{STATUS} != STATUS_UPDATING) {
        $self->Logmsg("$msg: Can't do anything with this resource");
        return;
    }

    # We got a response for the request - we need to remove the timer set in case the request timed out
    $self->delayRemove($poe_kernel, TIMER_REQUEST, $resource);

    eval {
        $self->Logmsg("$msg: Updating internal data");
        # Remove the state that was saved to disk
        $resource->removeState();
        
        # Update circuit object internal data as well
        switch($resource->{RESOURCE_TYPE}) {
            case CIRCUIT {
                # Remove from hash of all circuits, then add it to the historical list
                delete $self->{RESOURCES}{$resource->{NAME}};
                $self->addResourceToHistory($resource);
                $resource->registerRequestFailure($code);
            }
            case BOD {
                $resource->registerUpdateFailed();
            }
        }

        # Update circuit object internal data as well
        
        $resource->saveState();

        # Blacklist this link
        # This needs to be done *after* we register the failure with the circuit
        $self->addLinkToBlacklist($resource, CIRCUIT_REQUEST_FAILED);
    }
}

sub handleRequestResponse {
    my ($self, $kernel, $session, $resource, $returnValues, $code) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1, ARG2 ];

    my $msg = "ResourceManager->$ownHandles->{REQUEST_REPLY}";

    if (! defined $resource || ! defined $code) {
        $self->Logmsg("$msg: Resource or code not defined");
        return;
    }

    my $linkName = $resource->{NAME};
    
    if (($resource->{RESOURCE_TYPE} && $resource->{STATUS} != STATUS_UPDATING))	 {
        $self->Logmsg("$msg: Can't do anything with this resource");
        return;
    }
        
    # If the request failed, call the method handling request failures
    if ($code < 0) {
        $self->Logmsg("$msg: Circuit request failed for $linkName");
        $self->handleRequestFailure($resource, $code);
        return;
    }

    $self->Logmsg("$msg: Request succeeded for $linkName");
    
    # We got a response for the request - we need to remove the timer set in case the request timed out
    $self->delayRemove($kernel, TIMER_REQUEST, $resource);
    
    # Erase old state	
    $resource->removeState();
         
    # Update state
    switch($resource->{RESOURCE_TYPE}) {
        case CIRCUIT {
            $resource->registerEstablished($returnValues->{IP_A}, $returnValues->{IP_B}, $returnValues->{BANDWIDTH});
        }
        case BOD {
            $resource->registerUpdateSuccessful();
        }
    }
    
    # Save new state
    $resource->saveState();
    
    if (defined $resource->{LIFETIME}) {
        $self->Logmsg("$msg: Circuit has an expiration date. Starting countdown to teardown");
        $self->delayAdd($poe_kernel, $ownHandles->{HANDLE_TIMER}, $resource->{LIFETIME}, TIMER_TEARDOWN, $resource);
    }
}

sub handleTimer {
    my ($self, $kernel, $session, $timerType, $circuit) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1];

    my $msg = "ResourceManager->$ownHandles->{HANDLE_TIMER}";

    if (!defined $timerType || !defined $circuit) {
        $self->Logmsg("$msg: Don't know how to handle this timer");
        return;
    }

    my $linkName = $circuit->{NAME};

    switch ($timerType) {
        case TIMER_REQUEST {
            $self->Logmsg("$msg: Timer for circuit request on link ($linkName) has expired");
            $self->handleRequestFailure($circuit, CIRCUIT_REQUEST_FAILED_TIMEDOUT);
        }
        case TIMER_BLACKLIST {
            $self->Logmsg("$msg: Timer for blacklisted link ($linkName) has expired");
            $self->handleTrimBlacklist($circuit);
        }
        case TIMER_TEARDOWN {
            $self->Logmsg("$msg: Life for circuit ($circuit->{ID}) has expired");
            $self->handleCircuitTeardown($kernel, $session, $circuit);
        }
    }
}

# Circuits can be blacklisted for two reasons
# 1. A circuit request previously failed
#   - to prevent successive multiple retries to the same IDC, we temporarily blacklist that particular link
# 2. Multiple files in a job failed while being transferred on the circuit
#   - if transfers fail because of a circuit error, by default PhEDEx will retry transfers on the same link
#   we temporarily blacklist that particular link and PhEDEx will retry on a "standard" link instead
sub handleTrimBlacklist {
    my ($self, $circuit) = @_;
    return if ! defined $circuit;
    my $linkName = $circuit->{NAME};
    $self->Logmsg("ResourceManager->handleTrimBlacklist: Removing $linkName from blacklist");
    delete $self->{LINKS_BLACKLISTED}{$linkName} if defined $self->{LINKS_BLACKLISTED}{$linkName};
    $self->delayRemove($poe_kernel, TIMER_BLACKLIST, $circuit);
}

sub handleCircuitTeardown {
    my ($self, $kernel, $session, $circuit) = @_;

    my $msg = "ResourceManager->handleCircuitTeardown";

    if (!defined $circuit) {
        $self->Logmsg("$msg: something went horribly wrong... Didn't receive a circuit back");
        return;
    }

    $self->delayRemove($kernel, TIMER_TEARDOWN, $circuit);

    my $linkName = $circuit->{NAME};
    $self->Logmsg("$msg: Updating states for link $linkName");

    eval {
        $circuit->removeState();

        # Remove from hash of all circuits, then add it to the historical list
        delete $self->{RESOURCES}{$linkName};
        $self->addResourceToHistory($circuit);

        # Update circuit object data
        $circuit->registerTakeDown();

        # Potentiall save the new state for debug purposes
        $circuit->saveState();
    };

    $self->Logmsg("$msg: Calling teardown for $linkName");

    # Call backend to take down this circuit
    $kernel->post($session, $backHandles->{BACKEND_TEARDOWN_CIRCUIT}, $circuit);
}

## HTTP Related controls

sub handleHTTPCircuitCreation {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($circuitManager) = @{$initialArgs};
    my ($resultArguments) = @{$postArgs};
    
    my $fromNode = $resultArguments->{NODE_A};
    my $toNode = $resultArguments->{NODE_B};
    my $lifetime = $resultArguments->{LIFETIME};
    my $bandwidth = $resultArguments->{BANDWIDTH};
    
    $circuitManager->Logmsg("Received circuit creation request for nodes $fromNode and $toNode");
    
    $poe_kernel->post($session, 'requestCircuit', $fromNode, $toNode, $lifetime, $bandwidth);
}

sub handleHTTPCircuitTeardown {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($circuitManager) = @{$initialArgs};
    my ($resultArguments) = @{$postArgs};
    
    my $fromNode = $resultArguments->{NODE_A};
    my $toNode = $resultArguments->{NODE_B};
    
    my $linkID = &getPath($fromNode, $toNode);
    
    my $circuit = $circuitManager->{RESOURCES}{$linkID};
    
    $circuitManager->Logmsg("Received circuit teardown request for circuit on nodes $fromNode and $toNode");
    
    $circuitManager->handleCircuitTeardown($kernel, $session, $circuit);
}


sub handleHTTPinfo {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($circuitManager) = @{$initialArgs};
    my ($resultArguments, $resultCallback) = @{$postArgs};

    my $request = $resultArguments->{REQUEST};

    return if ! defined $request;

    switch($request) {
        case /^(RESOURCES|BACKEND_TYPE|RESOURCE_HISTORY|LINKS_BLACKLISTED)$/ {
            $resultCallback->($circuitManager->{$request});
        }
        case 'ONLINE_CIRCUIT' {
            my $fromNode = $resultArguments->{NODE_A};
            my $toNode = $resultArguments->{NODE_B};
            my $linkID = &getPath($fromNode, $toNode);
            $resultCallback->() if !$linkID;

            my $circuit = $circuitManager->{RESOURCES}{$linkID};
            $resultCallback->($circuit);
        }
        else {
            $resultCallback->();
        }
    }
}

sub stop {
    my $self = shift;

    # Tear down all circuits before shutting down
    $self->teardownAll();

    # Stop the HTTP server
    if (defined $self->{HTTP_SERVER}) {
        $self->{HTTP_SERVER}->stopServer();
        $self->{HTTP_SERVER}->resetHandlers();
    }
}

# Cancels all requests in progress and tears down all the circuits that have been established
sub teardownAll {
    my ($self) = @_;

    my $msg = "ResourceManager->teardownAll";

    $self->Logmsg("$msg: Cleaning out all circuits");

    foreach my $circuit (values %{$self->{RESOURCES}}) {
        my $backend = $self->{BACKEND};
        switch ($circuit->{STATUS}) {
            case STATUS_UPDATING {
                # TODO: Check and see if you can cancel requests
                # $backend->cancel_request($circuit);
            }
            case STATUS_ONLINE {
                $self->Logmsg("$msg: Tearing down circuit for link $circuit->{NAME}");
                $self->handleCircuitTeardown($poe_kernel, $poe_kernel->ID_id_to_session($self->{SESSION_ID}), $circuit);
            }
        }
    }
}


# Adds a delay and keep the alarm ID which is returned in memory
# It has basically the same effect as delay_add, however, by having the
# alarm ID, we can cancel the timer if we know we don't need it anymore
# for ex. cancel the request time out when we get a reply, or
# cancel the lifetime timer, if we need to destroy the circuit prematurely

# Depending on the architecture each tick of a delay adds about 10ms of overhead
sub delayAdd {
    my ($self, $kernel, $handle, $timer, $timerType, $circuit) = @_;

    # Set a delay for a given event, then get the ID of this timer
    my $eventID = $kernel->delay_set($handle, $timer, $timerType, $circuit);

    # Remember this ID in order to clean it immediately after which we recevied an answer
    $self->{DELAYS}{$timerType}{$circuit->{ID}} = $eventID;
}

# Remove an alarm/delay before the trigger time
sub delayRemove {
    my ($self, $kernel, $timerType, $circuit) = @_;

    # Get the ID for the specified timer
    my $eventID = $self->{DELAYS}{$timerType}{$circuit->{ID}};

    # Remove from ResourceManager and remove from POE
    delete $self->{DELAYS}{$timerType}{$circuit->{ID}};
    $kernel->alarm_remove($eventID);
}

# schedule $event to occur AT MOST $maxdelta seconds into the future.
# if the event is already scheduled to arrive before that time,
# nothing is done.  returns the timestamp of the next event
sub delay_max
{
    my ($self, $kernel, $event, $maxdelta) = @_;
    my $now = &mytimeofday();
    my $id = $self->{ALARMS}->{$event}->{ID};
    my $next = $kernel->alarm_adjust($id, 0);
    if (!$next) {
	$next = $now + $maxdelta;
	$id = $kernel->alarm_set($event, $next);
    } elsif ($next - $now > $maxdelta) {
	$next = $kernel->alarm_adjust($id, $now - $next + $maxdelta);
    }
    $self->{ALARMS}->{$event} = { ID => $id, NEXT => $next };
    return $next;
}

1;