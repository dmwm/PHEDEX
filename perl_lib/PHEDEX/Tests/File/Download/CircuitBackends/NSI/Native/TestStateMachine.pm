package PHEDEX::Tests::File::Download::CircuitBackends::NSI::Native::TestStateMachine;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsLSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsPSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConstantsRSM;
use PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine;

use Test::More;

sub testStateMachineErrorHandling {
    my $logIntro = "TestStateMachine->testStateMachineErrorHandling";
    
    my $rsm = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_RESERVE_START,
                                                                                        CURRENT_STATE   => STATE_RESERVE_START, 
                                                                                        TRANSITIONS     => RSM_TRANSITIONS);
    
    $rsm->Logmsg("Test reserve start->checking->held->commiting->start");
    is($rsm->{CURRENT_STATE},               STATE_RESERVE_START, "$logIntro: Correct start state for RSM");
    is($rsm->setNextState(MSG_PROVISION),   undef,     "$logIntro: Cannot switch to incorrect state");
    is($rsm->{CURRENT_STATE},               STATE_RESERVE_START, "$logIntro: Correct start state for RSM");
}

sub testReservationStateMachine {
    
    my $logIntro = "TestStateMachine->testReservationStateMachine";
    
    my $rsm = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_RESERVE_START,
                                                                                        CURRENT_STATE   => STATE_RESERVE_START, 
                                                                                        TRANSITIONS     => RSM_TRANSITIONS);
                                                                                
    $rsm->Logmsg("Test reserve start->checking->held->commiting->reserved->start");
    is($rsm->{CURRENT_STATE}, STATE_RESERVE_START, "$logIntro: Correct start state for RSM");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_CONFIRMED),           STATE_RESERVE_HELD,         "$logIntro: Correctly switched to STATE_RESERVE_HELD");
    is($rsm->setNextState(MSG_RESERVE_COMMIT),              STATE_RESERVE_COMMITING,    "$logIntro: Correctly switched to STATE_RESERVE_COMMITING");
    is($rsm->setNextState(MSG_RESERVE_COMMIT_CONFIRMED),    STATE_RESERVED,             "$logIntro: Correctly switched to STATE_RESERVED");
    is($rsm->setNextState(MSG_TERMINATE_CONFIRMED),         STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");
    
    $rsm->Logmsg("Test reserve start->checking->held->commiting->start");
    is($rsm->{CURRENT_STATE}, STATE_RESERVE_START, "$logIntro: Correct start state for RSM");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_CONFIRMED),           STATE_RESERVE_HELD,         "$logIntro: Correctly switched to STATE_RESERVE_HELD");
    is($rsm->setNextState(MSG_RESERVE_COMMIT),              STATE_RESERVE_COMMITING,    "$logIntro: Correctly switched to STATE_RESERVE_COMMITING");
    is($rsm->setNextState(MSG_RESERVE_COMMIT_FAILED),       STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");
    
    $rsm->Logmsg("Test reserve start->checking->failed->aborting->start");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_FAILED),              STATE_RESERVE_FAILED,       "$logIntro: Correctly switched to STATE_RESERVE_FAILED");
    is($rsm->setNextState(MSG_RESERVE_ABORT),               STATE_RESERVE_ABORTING,     "$logIntro: Correctly switched to STATE_RESERVE_ABORTING");
    is($rsm->setNextState(MSG_RESERVE_ABORT_CONFIRMED),     STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");
    
    $rsm->Logmsg("Test reserve start->checking->held->aborting->start");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_CONFIRMED),           STATE_RESERVE_HELD,         "$logIntro: Correctly switched to STATE_RESERVE_HELD");
    is($rsm->setNextState(MSG_RESERVE_ABORT),               STATE_RESERVE_ABORTING,     "$logIntro: Correctly switched to STATE_RESERVE_ABORTING");
    is($rsm->setNextState(MSG_RESERVE_ABORT_CONFIRMED),     STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");
    
    $rsm->Logmsg("Test reserve start->checking->held->timeout->aborting->start");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_CONFIRMED),           STATE_RESERVE_HELD,         "$logIntro: Correctly switched to STATE_RESERVE_HELD");
    is($rsm->setNextState(MSG_RESERVE_TIMEOUT),             STATE_RESERVE_TIMEOUT,      "$logIntro: Correctly switched to STATE_RESERVE_TIMEOUT");
    is($rsm->setNextState(MSG_RESERVE_ABORT),               STATE_RESERVE_ABORTING,     "$logIntro: Correctly switched to STATE_RESERVE_ABORTING");
    is($rsm->setNextState(MSG_RESERVE_ABORT_CONFIRMED),     STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");
    
    $rsm->Logmsg("Test reserve start->checking->held->timeout->start");
    is($rsm->setNextState(MSG_RESERVE),                     STATE_RESERVE_CHECKING,     "$logIntro: Correctly switched to STATE_RESERVE_CHECKING");
    is($rsm->setNextState(MSG_RESERVE_CONFIRMED),           STATE_RESERVE_HELD,         "$logIntro: Correctly switched to STATE_RESERVE_HELD");
    is($rsm->setNextState(MSG_RESERVE_TIMEOUT),             STATE_RESERVE_TIMEOUT,      "$logIntro: Correctly switched to STATE_RESERVE_TIMEOUT");
    is($rsm->setNextState(MSG_RESERVE_COMMIT),              STATE_RESERVE_START,        "$logIntro: Correctly switched to STATE_RESERVE_START");      
}

sub testProvisionStateMachine {
    my $logIntro = "TestStateMachine->testProvisionStateMachine";
    
    my $psm = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_RELEASED,
                                                                                        CURRENT_STATE   => STATE_RELEASED, 
                                                                                        TRANSITIONS     => PSM_TRANSITIONS);
    
    $psm->Logmsg("Test provision released->provisioning->provisioned->releasing->released");    
    is($psm->{CURRENT_STATE}, STATE_RELEASED, "$logIntro: Correct start state for PSM");
    is($psm->setNextState(MSG_PROVISION),            STATE_PROVISIONING,    "$logIntro: Correctly switched to STATE_PROVISIONING");
    is($psm->setNextState(MSG_PROVISION_CONFIRMED),  STATE_PROVISIONED,     "$logIntro: Correctly switched to STATE_PROVISIONED");
    is($psm->setNextState(MSG_RELEASE),              STATE_RELEASING,       "$logIntro: Correctly switched to STATE_RELEASING");
    is($psm->setNextState(MSG_RELEASE_CONFIRMED),    STATE_RELEASED,        "$logIntro: Correctly switched to STATE_RELEASED");
}

sub testLifecycleStateMachine {
    my $logIntro = "TestStateMachine->testLifecycleStateMachine";
    
    my $lsm = PHEDEX::File::Download::Circuits::Backend::NSI::Native::StateMachine->new(START_STATE     => STATE_CREATED,
                                                                                        CURRENT_STATE   => STATE_CREATED, 
                                                                                        TRANSITIONS     => LSM_TRANSITIONS);
    
    $lsm->Logmsg("Test lifecycle created->terminating->terminated");    
    is($lsm->{CURRENT_STATE}, STATE_CREATED, "$logIntro: Correct start state for LSM");
    is($lsm->setNextState(MSG_TERMINATE_REQUEST),   STATE_TERMINATING,     "$logIntro: Correctly switched to STATE_TERMINATING");
    is($lsm->setNextState(MSG_TERMINATE_CONFIRMED), STATE_TERMINATED,      "$logIntro: Correctly switched to STATE_TERMINATED");
    
    $lsm->{CURRENT_STATE} = STATE_CREATED;
    is($lsm->setNextState(MSG_FORCE_END),           STATE_FAILED,          "$logIntro: Correctly switched to STATE_FAILED");
    is($lsm->setNextState(MSG_TERMINATE_REQUEST),   STATE_TERMINATING,     "$logIntro: Correctly switched to STATE_TERMINATING");
    is($lsm->setNextState(MSG_TERMINATE_CONFIRMED), STATE_TERMINATED,      "$logIntro: Correctly switched to STATE_TERMINATED");
    
    $lsm->{CURRENT_STATE} = STATE_CREATED;
    is($lsm->setNextState(MSG_EXPIRED),             STATE_EXPIRED,          "$logIntro: Correctly switched to STATE_EXPIRED");
    is($lsm->setNextState(MSG_TERMINATE_REQUEST),   STATE_TERMINATING,     "$logIntro: Correctly switched to STATE_TERMINATING");
    is($lsm->setNextState(MSG_TERMINATE_CONFIRMED), STATE_TERMINATED,      "$logIntro: Correctly switched to STATE_TERMINATED");
    
    
}

testStateMachineErrorHandling();
testReservationStateMachine();
testProvisionStateMachine();

done_testing();

1;
