package PHEDEX::File::Download::Circuits::Backend::NSI::Native::Connection;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsRSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsPSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsLSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        ID      => undef,
        RSM     => undef,       # Reservation state machine Instantiated as soon as the first connection request is received.
        PSM     => undef,       # Provision state machine. Instantiated as soon as the first reservation is committed
        LSM     => undef,       # Lifecycle state machine. Instantiated as soon as the first connection request is received.
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);
                                                                   
        
    bless $self, $class;
    return $self;
}

sub reserveCircuit {
    my ($self, $nodeA, $nodeB, $startTime, $stopTime, $bandwidth) = @_;
    
    my $msg = "(NSI) Circuit->requestCircuit";
    
    if (defined $self->{RSM} || defined $self->{PSM} || defined $self->{LSM}) {
        $self->Logmsg("$msg: Cannot request circuit. A previous request has already been made");            
    }
        
    # Create the reservation state machine
    $self->{RSM} = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_RESERVE_START,
                                                                                            CURRENT_STATE   => STATE_RESERVE_CHECKING, 
                                                                                            TRANSITIONS     => RSM_TRANSITIONS);

    # Create the lifecycle state machine                                                                                     
    $self->{LSM} = PHEDEX::File::Download::Circuits::Backend::NSI::StateMachine->new(START_STATE     => STATE_CREATED,
                                                                                     CURRENT_STATE   => STATE_CREATED, 
                                                                                     TRANSITIONS     => LSM_TRANSITIONS);
    
    
    # Call reserve(rsv.rq)
}

sub handleReserveRequestResponse {
    my ($self, $response) = @_;
        
    if ($response) {
        $self->{RSM}->setNextState(MSG_RESERVE_CONFIRMED);
        # Call reserveCommit(rsvcommit.rq)      
    } else {
        $self->{RSM}->setNextState(MSG_RESERVE_FAILED);
        # Call reserveAbort(rsvabort.rq)
    }
}

sub handleReserveCommitResponse {
    my ($self, $response) = @_;
        
    if ($response) {
        $self->{RSM}->setNextState(MSG_RESERVE_COMMIT_CONFIRMED);
        
        # Create the provision state machine
        $self->{PSM} = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_RELEASED,
                                                                                                CURRENT_STATE    => STATE_PROVISIONING, 
                                                                                                TRANSITIONS      => PSM_TRANSITIONS);
        
        # Call provision(provision.rq)
    } else {
        $self->{RSM}->setNextState(MSG_RESERVE_COMMIT_FAILED);
        # Call reserveAbort(rsvabort.rq)
    }
}

sub handleReserveAbortResponse {
    
}

sub handleProvisionResponse {
    
}

sub handleReleaseReponse {
    
}

1;