package PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %args = (@_);
    
    my $self = $class->SUPER::new(%args);
    
    if (! defined $self->{START_STATE} ||
        ! defined $self->{CURRENT_STATE} ||
        ! defined $self->{TRANSITIONS} || 
        ! defined $self->{FINAL_STATES}) {
            die "Parameters have not been correctly initialised. Cannot continue"
    }
        
    bless $self, $class;
    return $self;
}

sub setNextState {
    my ($self, $message) = @_;
    
    if (! defined $self || !defined $message) {
        $self->Logmsg("StateMachine->setNextState: Invalid parameters supplied");
        return;
    }
    
    my $allowedTransitions = $self->{TRANSITIONS}->{$self->{CURRENT_STATE}};
    
    if (!defined $allowedTransitions->{$message}) {
        $self->Logmsg("StateMachine->setNextState: Cannot change to new state");
        return;
    }
    
    $self->{CURRENT_STATE} = $self->{TRANSITIONS}->{$self->{CURRENT_STATE}}->{$message};
    
    return $self->{CURRENT_STATE};
}

sub getNextStates {
    my $self = shift;
    
    if (! defined $self) {
        $self->Logmsg("StateMachine->getNextStates: Cannot call this method outside object scope");
        return;
    }
    
    my @possbileStates = values (%{$self->{TRANSITIONS}->{$self->{CURRENT_STATE}}});
    
    return \@possbileStates;
}

1;