package PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::NSI;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Circuits::Backend::Core::Core','PHEDEX::Core::Logging';

# PhEDEx imports
use PHEDEX::File::Download::Circuits::Backend::Core::IDC;
use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation;
use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::Helpers::External;


# Other imports
use Data::UUID;
use LWP::Simple;
use POE;
use Switch;

use constant {
    REQUEST     => "Request",
    TEARDOWN    => "Teardown",
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        TASKER              => undef,
        ACTION_HANDLER      => undef,
        TIMEOUT             => 120,
        
        QUEUED_ACTIONS      => undef,       # Queue of pending actions
        CURRENT_ACTION      => undef,       # Current action which is being processed
        RESERVATIONS        => undef,       # Hash of ConnectionID -> Reservation

        # NSI Tool defaults
        NSI_TOOL_LOCATION   => '/data/NSI/CLI',
        NSI_TOOL            => 'nsi-cli-1.2.1-one-jar.jar',
        NSI_JAVA_FLAGS      =>  '-Xmx256m -Djava.net.preferIPv4Stack=true '.
                                '-Dlog4j.configuration=file:./config/log4j.properties ',
                                '-Dcom.sun.xml.bind.v2.runtime.JAXBContextImpl.fastBoot=true ',
                                '-Dorg.apache.cxf.JDKBugHacks.defaultUsesCaches=true ',
        NSI_TOOL_PID        => undef,
        
        # Provider should also have the truststore containing the aggregator server certificats 
        # Store password is in: provider-client-https-cc.xml
        DEFAULT_PROVIDER    => 'provider.script',   # Default provider script name
        # Requester should also provide the truststore with his certificate and key
        # Store and key password are in: requester-server-http.xml
        DEFAULT_REQUESTER   => 'requester.script',  # Default requester script name

        SESSION             => undef,
        VERBOSE             => 1,
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    $self->{UUID} = new Data::UUID;
    
    $self->{AGENT_TRANSLATION} = {
        NODE_A  =>  "URL 1",
        NODE_B  =>  "urn:ogf:network:es.net:2013::star-cr5:10_1_8:+?vlan=1779",
    };
   
    bless $self, $class;
    return $self;
}

# Init POE events
# - declare event 'processToolOutput' which is passed as a postback to External
# - call super
sub _poe_init
{
    my ($self, $kernel, $session) = @_;

    # Create the action which is going to be called on STDOUT by External
    $kernel->state('processToolOutput', $self);
    $self->{SESSION} = $session;
    $self->{ACTION_HANDLER} = $session->postback('processToolOutput');

    # Parent does the main initialization of POE events
    $self->SUPER::_poe_init($kernel, $session);
    
    # Create instance running capable of running external tools
    $self->{TASKER} = PHEDEX::File::Download::Circuits::Helpers::External->new();
    
    # Launch an instance of the NSI CLI
    chdir $self->{NSI_TOOL_LOCATION};
    $self->{NSI_TOOL_PID} = $self->{TASKER}->startCommand("java $self->{NSI_JAVA_FLAGS} -jar $self->{NSI_TOOL}", $self->{ACTION_HANDLER}, $self->{TIMEOUT});
    $self->{TASKER}->getTaskByPID($self->{NSI_TOOL_PID})->put('nsi override');
}

sub getRequestScript {
    my ($self, $providerName, $requesterName, $scriptName) = @_;
    
    $providerName = $self->{DEFAULT_PROVIDER} if ! defined $providerName;
    $requesterName = $self->{DEFAULT_REQUESTER} if ! defined $requesterName;
    
    if (! defined $scriptName) {
        $self->Alert("The script to load has not been provided")
    }
    
    my $script = "";
    $script .= "script --file $self->{NSI_TOOL_LOCATION}/scripts/provider/$providerName\n";
    $script .= "script --file $self->{NSI_TOOL_LOCATION}/scripts/requester/$requesterName\n";

    return $script;
}

sub backendRequestCircuit {
    my ($self, $circuit, $requestCallback) = @_[ OBJECT, ARG0, ARG1];
    $self->queueAction(REQUEST, $circuit, $requestCallback);
}

sub backendTeardownCircuit {
    my ($self, $circuit) = @_[ OBJECT, ARG0];
    $self->queueAction(TEARDOWN, $circuit);
}

# Creates a new action baased on the action type provided (Request, Teardown)
# This action is queued and will be executed after the rest of the pending actions have been completed
# This restriction is due to us using the NSI CLI tool instead of having a native implementation
sub queueAction {
    my ($self, $actionType, $circuit, $requestCallback) = @_;

    my $newAction = {
        ID                  => $self->{UUID}->create(),
        TYPE                => $actionType,
        CIRCUIT             => $circuit,
        REQUEST_CALLBACK    => $requestCallback,
    };

    push(@{$self->{QUEUED_ACTIONS}}, $newAction);
    $self->executeNextAction();
}

# Executes the next action in the queue if there's no other pending action
sub executeNextAction {
    my $self = shift;

    if (defined $self->{CURRENT_ACTION}) {
        $self->Logmsg("Other actions are still pending... Will execute new action when appropiate");
        return;
    }

    if (scalar @{$self->{QUEUED_ACTIONS}} == 0) {
        $self->Logmsg("The action queue is empty...");
        return;
    }
    
    # Pick the next action from the queue
    $self->{CURRENT_ACTION} = shift @{$self->{QUEUED_ACTIONS}};
    my $action = $self->{CURRENT_ACTION};
    my $circuit = $action->{CIRCUIT};
    
    switch ($action->{TYPE}) {
        case REQUEST {
            my $reservation = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation->new();
            $reservation->{REQUEST_CALLBACK} = $action->{REQUEST_CALLBACK};
            $reservation->updateParameters($self->{AGENT_TRANSLATION}, $circuit);
            $self->{CURRENT_ACTION}->{RESERVATION} = $reservation;

            # Set the reservation parameters into the CLI
            my $reserveCommands = $reservation->getReservationSetterScript();

            # And request the circuit
            push (@{$reserveCommands}, "nsi reserve\n");
            
            $self->sendToCLI($reserveCommands);
        }

        # TODO: Implement the MODIFY function
        # For now just teardown and request new one...
        
        case TEARDOWN {
            if (! defined $circuit->{NSI_ID}) {
                $self->Logmsg("The circuit provided has not Connection ID assigned. Cannot find reservation");
                return;
            }

            # Get the reservation which was assigned to this circuit and send the CLI commands to terminate reservation
            my $reservation = $self->{RESERVATIONS}->{$circuit->{NSI_ID}};
            my $terminationCommands = $reservation->getTerminationScript();
            $self->sendToCLI($terminationCommands);
        }
    }

    delete $self->{CURRENT_ACTION};
    $self->executeNextAction();
}

# Send commands to the NSI CLI
sub sendToCLI {
    my ($self, $script) = @_;
    
    if (! defined $script || $script eq "") {
        $self->Logmsg("Cannot execute an empty script");
        return;
    }
    
    # Get the task info
    my $nsiTool = $self->{TASKER}->getTaskByPID($self->{NSI_TOOL_PID});
    
    foreach my $line (@{$script}) {
        $nsiTool->put($line);
    }
}

sub processToolOutput {
    my ($self, $kernel, $session, $arguments) = @_[OBJECT, KERNEL, SESSION, ARG1];

    my $pid = $arguments->[EXTERNAL_PID];
    my $task = $arguments->[EXTERNAL_TASK];
    my $eventName = $arguments->[EXTERNAL_EVENTNAME];
    my $output = $arguments->[EXTERNAL_OUTPUT];

    switch ($eventName) {
        case 'handleTaskStdOut' {
            $self->Logmsg("NSI CLI($pid): $output") if $self->{VERBOSE};

            # Try to identify the new state communicated by the NSI CLI tool and most importantly the reservation ID for which it's destined
            my $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState($output);
            return if ! defined $result;

            my ($id, $newState) = ($result->[0], $result->[1]);

            # Reservation was created and received a connection ID
            if ($newState eq STATE_ASSIGNED_ID) {
                $self->Logmsg("Reservation created (ID: $id");
                my $reservation = $self->{CURRENT_ACTION}->{RESERVATION};
                $reservation->{CONNECTION_ID} = $id;
                $self->{RESERVATIONS}->{$id} = $reservation;
            }

            # Look for the reservation which has the ID 
            my $reservation = $self->{RESERVATIONS}->{$id};
            $reservation->setNextState($newState);
            
            switch ($reservation->{CURRENT_STATE}) {
                # If the reservation was held, then commit it
                case STATE_CONFIRMED {
                    my $script = $reservation->getOverrideScript();
                    push (@{$script}, "nsi commit\n");
                    $self->sendToCLI($script);
                }
                
                # If the reservation was committed, then provision it
                case STATE_COMMITTED {
                    my $script = $reservation->getOverrideScript();
                    push (@{$script}, "nsi provision\n");
                    $self->sendToCLI($script);
                }
                
                # Reservation is now active (dataplane should now work)
                case STATE_ACTIVE {
                    $self->Logmsg("Circuit creation succeeded");
                    
                    my $circuit = $reservation->{CIRCUIT};
                    $circuit->{NSI_ID} = $reservation->{ID};
                    
                    POE::Kernel->post($self->{SESSION}, $reservation->{REQUEST_CALLBACK}, $circuit, undef, CIRCUIT_REQUEST_SUCCEEDED);
                }

                # Reservation has been terminated
                case STATE_TERMINATED {
                     $self->Logmsg("Circuit terminated");
                     # TODO: Maybe warn the Reservation Manager as well?
                }

                # The reservation failed for whatever reason
                case [STATE_ERROR, STATE_ERROR_CONFIRM_FAIL, STATE_ERROR_COMMIT_FAIL, STATE_ERROR_PROVISION_FAIL] {
                    $self->Logmsg("Circuit creation failed");
                    # The circuit failed, we need to make sure we clean up everything
                    my $terminationCommands = $reservation->getTerminationScript();
                    $self->sendToCLI($terminationCommands);
                    
                    my $circuit = $reservation->{CIRCUIT};
                    POE::Kernel->post($self->{SESSION}, $reservation->{REQUEST_CALLBACK}, $circuit, undef, CIRCUIT_REQUEST_FAILED);
                }

            };
        }

        case 'handleTaskStdError' {
            $self->Logmsg("An error has occured with NSI CLI ($pid): $output");
        }
        
        case 'handleTaskSignal' {
            $self->Logmsg("NSI CLI tool is being terminated ");
        }
    }
}

1;