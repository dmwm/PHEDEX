package PHEDEX::File::Download::Circuits::Dynes::Dynes;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Circuits::Backend::Core::Core','PHEDEX::Core::Logging';

# PhEDEx imports
use PHEDEX::File::Download::Circuits::Backend::Core::IDC;
use PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::Helpers::External;
use PHEDEX::File::Download::Circuits::TFCUtils;

# Other imports
use LWP::Simple;
use POE;
use Switch;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        TOOL                => 'dynesfdt',
        TASKER              => undef,
        ACTION_HANDLER      => undef,
        TIMEOUT             => 10,          # No reply after 10 seconds gets you killed
        ACTIVE_TASKS_BY_PID => undef,
        ACTIVE_TASKS_BY_CID => undef,

        # Dynes options
        DEFAULT_LISTEN_PORT => undef,
        DEFAULT_BANDWIDTH   => undef,

        #
        WEB_LOOKUP          => 'http://testphedexnode1.cern.ch/agentsLookup',
        WEB_MAPPING         => 'http://testphedexnode1.cern.ch/agentsMapping',

        LOOKUP_REFRESH      => 60,

        # Matchers
        MATCH_HEADER        => '\[([\w-]*)\]',
        MATCH_OPTIONS       => '([\w-]*)=([\w.]*)',

        #
        SESSION             => undef,
        VERBOSE             => 1,
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    $self->_buildAgentTranslationHash();

    die "Could not build the agent translation hash" unless defined $self->{AGENT_TRANSLATION};

    $self->{TASKER} = PHEDEX::File::Download::Circuits::Helpers::External->new();

    bless $self, $class;
    return $self;
}

# Simple method which gets the contents from a provided URL
# Returns an array of lines
sub _readFromWeb {
    my ($self, $url) = @_;
    return if ! defined $url;
    my $content = get $url;
    return if ! defined $content;
    return split /\n/, $content;
}

sub _getLookupViaWeb {
    my $self = shift;
    my @lines = $self->_readFromWeb($self->{WEB_LOOKUP});
    return $self->_parseLookupList(\@lines);
}

# Parses the lookup list (which is retrieved by default from the WEB)
sub _parseLookupList {
    my ($self, $content) = @_;

    my $lookup = {};
    my $currentTag;

    foreach my $line (@{$content}) {
        my ($matchName) = $line =~ /$self->{MATCH_HEADER}/;
        if ($matchName) {
            $currentTag = $matchName ;
            next;
        }

        my ($matchOption, $matchValue) = $line =~ /$self->{MATCH_OPTIONS}/;
        $lookup->{$currentTag}{$matchOption} = $matchValue if ($matchOption && $matchValue);
    }

    return $lookup;
}

sub _getAgentMapping{
    my $self = shift;
    my @lines = $self->_readFromWeb($self->{WEB_MAPPING});

    my $translation = {};
    foreach my $line (@lines) {
        my ($dynesName, $phedexName) = $line =~ /([\w-]*)=([\w-]*)/;
        $translation->{$dynesName} = $phedexName if (defined $dynesName && defined $phedexName);
    }
    return $translation;
}

# Build the AGENT_TRANSLATION hash which maps the PHEDEX names to IDC references
# Data is taken from two sources
#   - lookup file : available on the web (or by using the command 'dynesfdt list')
#   - mapping file: this is kept up to date manually, mapping the PhEDEx names to Dynes names
sub _buildAgentTranslationHash {
    my $self = shift;

    my $lookup = defined $self->{WEB_LOOKUP} ? $self->_getLookupViaWeb() : undef;
    my $phedexMapping = defined $self->{WEB_MAPPING}? $self->_getAgentMapping() : undef;

    my $msg = "Dynes->_buildAgentTranslationHash";

    if (! defined $lookup || ! defined $phedexMapping) {
        $self->Logmsg("$msg: Not all the required data has been provided");
        return;
    }

    # Set the default options
    $self->{DEFAULT_LISTEN_PORT} = $lookup->{'defaults'}{FDT_AGENT_LISTEN_PORT} if ! defined $self->{DEFAULT_LISTEN_PORT};
    $self->{DEFAULT_BANDWIDTH} = $lookup->{'defaults'}{bandwidth} if ! defined $self->{DEFAULT_BANDWIDTH};

    delete $lookup->{'defaults'};

    # Build IDC objects and set any eventual options (superseding default options)
    foreach my $dynesName (keys %{$lookup}) {
        next if ! defined $phedexMapping->{$dynesName};

        my $agentOptions = $lookup->{$dynesName};
        my ($phedexName, $ip, $port, $bandwidth);

        $ip = $agentOptions->{FDT_IP}
            if (determineAddressType($agentOptions->{FDT_IP}) == ADDRESS_IPv4 ||
                determineAddressType($agentOptions->{FDT_IP}) == ADDRESS_IPv6);
        $phedexName = $phedexMapping->{$dynesName};
        $port = defined $agentOptions->{FDT_AGENT_LISTEN_PORT} ? $agentOptions->{FDT_AGENT_LISTEN_PORT} :  $self->{DEFAULT_LISTEN_PORT};
        $bandwidth = defined $agentOptions->{FDT_AGENT_LISTEN_PORT} ? $agentOptions->{bandwidth} :  $self->{DEFAULT_BANDWIDTH};

        if (defined $ip && defined $phedexName && defined $port && defined $bandwidth) {
            my $idc = PHEDEX::File::Download::Circuits::Backend::IDC->new(DYNES_NAME    => $dynesName,
                                                                          PHEDEX_NAME   => $phedexName,
                                                                          IP            => $ip,
                                                                          PORT          => $port,
                                                                          BANDWIDTH     => $bandwidth);
            $self->{AGENT_TRANSLATION}{$phedexName} = $idc;
        }
    }
}

# Init POE events
# declare event 'processToolOutput' which is passed as a postback to External
# call super
sub _poe_init
{
    my ($self, $kernel, $session) = @_;

    $kernel->state('processToolOutput', $self);
    $self->{SESSION} = $session;
    $self->{ACTION_HANDLER} = $session->postback('processToolOutput');

    # Needed since we're calling this subroutine directly instead of passing through POE
    my @superArgs; @superArgs[KERNEL, SESSION] = ($kernel, $session); shift @superArgs;

    # Parent does the main initialization of POE events
    $self->SUPER::_poe_init(@superArgs);
}

sub processToolOutput {
    my ($self, $kernel, $session, $arguments) = @_[OBJECT, KERNEL, SESSION, ARG1];

    my $pid = $arguments->[EXTERNAL_PID];
    my $eventName = $arguments->[EXTERNAL_EVENTNAME];
    my $output = $arguments->[EXTERNAL_OUTPUT];

    my $wrapper = $self->{ACTIVE_TASKS_BY_PID}{$pid};

    return if ! defined $wrapper;

    switch ($eventName) {
        case 'handleTaskStdOut' {
            $self->Logmsg("STDOUT from PID ($pid):$output") if $self->{VERBOSE};
            my $result = $wrapper->{STATE}->updateState($output);
            if ($result->[0] eq 'OK' && $result->[1] eq 'PING') {
                $self->Logmsg("Circuit creation succeeded");

                my $returnValues = {
                    FROM_IP         =>      $wrapper->{STATE}->{SRC_IP},
                    TO_IP           =>      $wrapper->{STATE}->{DEST_IP},
                    BANDWIDTH       =>      $self->{DEFAULT_BANDWIDTH}, # TODO: Get the min bw between nodes
                };

                POE::Kernel->post($self->{SESSION}, $wrapper->{REQUEST_REPLY}, $wrapper->{CIRCUIT}, $returnValues, CIRCUIT_REQUEST_SUCCEEDED);
            }

            if ($result->[0] eq 'ERROR') {
                POE::Kernel->post($self->{SESSION}, $wrapper->{REQUEST_REPLY}, $wrapper->{CIRCUIT}, undef, CIRCUIT_REQUEST_FAILED);
            }
        }
        case 'handleTaskStdError' {


        }
        case 'handleTaskSignal' {

            # Clean-up
            my $wrapper = $self->{ACTIVE_TASKS_BY_PID}{$pid};
            delete $self->{ACTIVE_TASKS_BY_CID}{$wrapper->{CID}};
            delete $self->{ACTIVE_TASKS_BY_PID}{$pid};
        }
    }


}

sub backendRequestCircuit {
    my ($self, $kernel, $session, $circuit, $requestCallback, $infoCallback, $errorCallback) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1, ARG2, ARG3];

    my $pid = $self->{TASKER}->startCommand('cat ../TestData/CircuitOK_PingOK.log', $self->{ACTION_HANDLER}, $self->{TIMEOUT});
    my $state = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();

    my $wrapper = {
        CID             =>  $circuit->{ID},         # Circuit ID
        PID             =>  $pid,                   # PID of the tool that was used to request the circuit
        CIRCUIT         =>  $circuit,
        STATE           =>  $state,                 # This object holds the current state of the circuit, as "told" by the STDOUT output of dynesfdt
        REQUEST_REPLY   =>  $requestCallback,       # Event to be triggered when we want to reply to a request made by the CM
        INFO_REPLY      =>  $infoCallback,          # Event to be triggered when we want to inform the CM of state changes related to an established circuit
        ERROR_REPLY     =>  $errorCallback,         # Event to be triggered when we want to inform the CM of an error (circuit died, or something)
    };

    $self->{ACTIVE_TASKS_BY_CID}{$circuit->{ID}} = $wrapper;
    $self->{ACTIVE_TASKS_BY_PID}{$pid} = $wrapper;
}

sub backendTeardownCircuit {
    my ( $self, $kernel, $session, $circuit ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

    my $msg = "Dynes->backendTeardownCircuit";

    if (! defined $circuit) {
        $self->Logmsg("$msg: Invalid circuit provided");
        return;
    }

    if (! defined $self->{ACTIVE_TASKS_BY_CID}{$circuit->{ID}}) {
        $self->Logmsg("$msg: Cannot find and references to the circuit object provided");
        return;
    }

    my $wrapper = $self->{ACTIVE_TASKS_BY_CID}{$circuit->{ID}};
    my $pid = $wrapper->{PID};

    # Delete reference from this object as well
    delete $self->{ACTIVE_TASKS_BY_CID}{$circuit->{ID}};
    delete $self->{ACTIVE_TASKS_BY_PID}{$pid};

    # Kill external task
    $self->{TASKER}->kill_task($pid);
}

1;