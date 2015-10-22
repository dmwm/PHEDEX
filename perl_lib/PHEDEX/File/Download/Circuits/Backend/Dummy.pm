package PHEDEX::File::Download::Circuits::Backend::Dummy;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Circuits::Backend::Core::Core','PHEDEX::Core::Logging';

use POE;
use List::Util qw[min max];

use PHEDEX::Core::Command;
use PHEDEX::File::Download::Circuits::Backend::Core::IDC;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;


sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params =
	(
        AGENT_TRANSLATION_FILE      =>      'agent_ips.txt',
        TIME_SIMULATION             =>      5,                              # Simulates the time delay to get a reply from the IDC
        DEFAULT_BANDWIDTH           =>      1000,
	);
	
    my %args = (@_);
    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    # Load the translation file
    die "Cannot find translation file" unless (-e $self->{AGENT_TRANSLATION_FILE});
    my $agents = &evalinfo($self->{AGENT_TRANSLATION_FILE});
    die "Cannot load translation file" unless $agents;
    foreach my $node (keys %{$agents}) {
        my $idc = PHEDEX::File::Download::Circuits::Backend::Core::IDC->new(IP => $agents->{$node});
        $self->{AGENT_TRANSLATION}{$node} = $idc;
    }
    
    $self->{SUPPORTED_RESOURCE} = CIRCUIT;

    bless $self, $class;
    return $self;
}

sub backendRequestCircuit {
    my ($self, $kernel, $session, $circuit, $callback) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1];

    if (!defined $circuit) {
        $self->Logmsg("Circuit provided is invalid :|");
        $kernel->call($session, $callback, $circuit, undef, CIRCUIT_REQUEST_FAILED_PARAMS);
    }

    my $fromNode = $circuit->{NODE_A};
    my $toNode = $circuit->{NODE_B};

    my $returnValues = {
        IP_A            =>      $self->{AGENT_TRANSLATION}{$fromNode}{IP},
        IP_B            =>      $self->{AGENT_TRANSLATION}{$toNode}{IP},
        BANDWIDTH       =>      min($self->{AGENT_TRANSLATION}{$fromNode}{BANDWIDTH}, $self->{AGENT_TRANSLATION}{$toNode}{BANDWIDTH}),
    };

    $self->Logmsg("Dummy backend call for circuit creation between $fromNode and $toNode with a BW of $self->{DEFAULT_BANDWIDTH}");
    # In this particular case the IPs of the agents are also the IPs of the circuit endpoints

    # Simulate a non response from backend if the time simulation is undef
    return if (!defined $self->{TIME_SIMULATION});

    if ($self->{TIME_SIMULATION} >= 0) {
        $kernel->delay_add($callback, $self->{TIME_SIMULATION}, $circuit, $returnValues, CIRCUIT_REQUEST_SUCCEEDED);
    } else {
        $kernel->delay_add($callback, -$self->{TIME_SIMULATION}, $circuit, $returnValues, CIRCUIT_REQUEST_FAILED);
    }

}

sub backendTeardownCircuit {
    my ( $self, $kernel, $session, $circuit ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
    $self->Logmsg('Backend - Tearing down circuit');
    return 'torndown';
}

sub backendUpdateBandwidth {
	my ($self, $kernel, $session, $resource, $callback) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1];
    
    if (!defined $resource) {
        $self->Logmsg("Provided object is invalid :|");
        $kernel->call($session, $callback, $resource, undef, CIRCUIT_REQUEST_FAILED_PARAMS);
    }
    
    # Simulate a non response from backend if the time simulation is undef
    return if (!defined $self->{TIME_SIMULATION});

    if ($self->{TIME_SIMULATION} >= 0) {
        $kernel->delay_add($callback, $self->{TIME_SIMULATION}, $resource, CIRCUIT_REQUEST_SUCCEEDED);
    } else {
        $kernel->delay_add($callback, -$self->{TIME_SIMULATION}, $resource, CIRCUIT_REQUEST_FAILED);
    }
    
    return 'torndown';
}

1;

