package PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %args = (@_);
    
    if (! defined $args{CURRENT_STATE} ||
        ! defined $args{TRANSITIONS}) {
            die "Parameters have not been correctly initialised. Cannot continue";
    }
    
    my $self = $class->SUPER::new();
    
    $self->{CURRENT_STATE} = $args{CURRENT_STATE};
    $self->{TRANSITIONS} = getTransitions($args{TRANSITIONS});
    
    bless $self, $class;
    return $self;
}

sub getTransitions() {
    my $transitions = shift;

    my $result;

    foreach my $state (keys %{$transitions}) {
        my $transition = $transitions->{$state};
        foreach my $message (keys %{$transition}) {
            my $nextState = $transition->{$message};
            $result->{$state}->{$nextState} = 1;
        }
    }

    return $result;
}

sub setNextState {
    my ($self, $nextState) = @_;
    
    if (! defined $self || !defined $nextState ||
        ! defined $self->{TRANSITIONS}->{$self->{CURRENT_STATE}}->{$nextState}) {
        $self->Logmsg("StateMachine->setNextState: Cannot update state");
        return undef;
    }

    $self->{CURRENT_STATE} = $nextState;
}

sub getNextStates {
    my $self = shift;

    if (! defined $self) {
        $self->Logmsg("StateMachine->getNextStates: Cannot call this method outside object scope");
        return;
    }

    my @possbileStates = keys (%{$self->{TRANSITIONS}->{$self->{CURRENT_STATE}}});

    return \@possbileStates;
}

sub isInFinalState {
    my $self = shift;

    if (! defined $self) {
        $self->Logmsg("StateMachine->isInFinalState: Cannot call this method outside object scope");
        return;
    }

    return $self->{TRANSITIONS}->{$self->{CURRENT_STATE}};
}

1;