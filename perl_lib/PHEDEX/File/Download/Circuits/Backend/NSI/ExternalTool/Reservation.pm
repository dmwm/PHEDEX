package PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;
use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        CIRCUIT             => undef,
        CONNECTION_ID       => undef,
        STATE_MACHINE       => undef,
        
        PARAM => {
            BANDWIDTH   => { ARG   => "--bw", VALUE   => 1000},
            DESCRIPTION => { ARG   => "--d",  VALUE   => ""},
            START_TIME  => { ARG   => "--st", VALUE   => "10 sec" },
            END_TIME    => { ARG   => "--et", VALUE   => "30 min" },
            GRI         => { ARG   => "--g",  VALUE   => "PhEDEx-NSI" },
            SOURCE_NODE => { ARG   => "--ss", VALUE   => "urn:ogf:network:somenetwork:somestp?vlan=333" },
            DEST_NODE   => { ARG   => "--ds", VALUE   => "urn:ogf:network:othernetwork:otherstp?vlan=333" }
        }
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    # Create the state machine that's going to be associated to this reservation
    $self->{STATE_MACHINE} = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine->new(CURRENT_STATE   => STATE_CREATED,
                                                                                                                        TRANSITIONS     => RESERVATION_TRANSITIONS);

    $self->{PARAM}->{DESCRIPTION}->{VALUE} = "Test circuit ".int(rand(100000));
    
    bless $self, $class;
    return $self;
}

# Update the state machine of this particular reservation
sub updateState {
    my ($self, $state) = @_;
    $self->{STATE_MACHINE}->setNextState($state);
}

# Updates the parameters of the reservation based on the circuit requested
sub updateParameters {
    my ($self, $translation, $circuit) = @_;
    
    $circuit->{LIFETIME} = $circuit->{CIRCUIT_DEFAULT_LIFETIME} if (!defined $circuit->{LIFETIME});
    $self->{CIRCUIT} = $circuit;
    
    $self->{PARAM}->{GRI}->{VALUE} = $circuit->{ID};
    $self->{PARAM}->{SOURCE_NODE}->{VALUE} = $translation->{$circuit->{NODE_A}};
    $self->{PARAM}->{DEST_NODE}->{VALUE} = $translation->{$circuit->{NODE_B}};

    # For now ResourceManager cannot provide a start time - it can only provide an end time (based on the lifetime param)
    $self->{PARAM}->{END_TIME}->{VALUE} = $circuit->{LIFETIME}." sec";
}

# Provides the NSI CLI script which updates the current CLI reservation parameters
sub getReservationSetterScript {
    my $self = shift;

    my $script = [];

    # Setup the reservation
    foreach my $key (keys %{$self->{PARAM}}) {
        my $arg = $self->{PARAM}->{$key}->{ARG};
        my $value = $self->{PARAM}->{$key}->{VALUE};
        push (@{$script}, "resv set $arg \"$value\"\n");
    }

    return $script;
}

sub getOverrideScript {
    my $self = shift;

    if (!defined $self->{CONNECTION_ID}) {
        $self->Alert("ConnectionID was not provided");
        return undef;
    }

    my $script = [];
    push (@{$script}, "nsi override\n");
    push (@{$script}, "nsi set --c \"$self->{CONNECTION_ID}\"\n");
    
    return $script;
}

# Provides the NSI CLI script which terminates the current reservation
sub getTerminationScript {
    my $self = shift;

    if (! defined $self->{CONNECTION_ID}) {
        $self->Alert("ConnectionID was not provided");
        return undef;
    }

    my $script = $self->getOverrideScript();
    push (@{$script}, "nsi terminate\n");

    return $script;
}

1;
