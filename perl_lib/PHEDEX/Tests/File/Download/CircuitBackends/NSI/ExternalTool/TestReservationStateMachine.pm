package PHEDEX::Tests::File::Download::CircuitBackends::NSI::ExternalTool::TestReservationStateMachine;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;
use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine;

use Test::More;

sub testInitialisation {
    my $logIntro = "TestStateMachine->testInitialisation";
    
    my $rsm = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine->new(CURRENT_STATE   => STATE_CREATED, 
                                                                                                         TRANSITIONS     => RESERVATION_TRANSITIONS);

    is($rsm->{CURRENT_STATE}, STATE_CREATED, "$logIntro: Correct start state for RSM");
    ok($rsm->{TRANSITIONS}->{STATE_CREATED()}->{STATE_ASSIGNED_ID()}, "$logIntro: Allowed transition from STATE_CREATED to STATE_ASSIGNED_ID");
    ok($rsm->{TRANSITIONS}->{STATE_CREATED()}->{STATE_ERROR()}, "$logIntro: Allowed transition from STATE_CREATED to STATE_ERROR");

    ok($rsm->{TRANSITIONS}->{STATE_ASSIGNED_ID()}->{STATE_CONFIRMED()}, "$logIntro: Allowed transition from STATE_ASSIGNED_ID to STATE_CONFIRMED");
    ok($rsm->{TRANSITIONS}->{STATE_ASSIGNED_ID()}->{STATE_ERROR_CONFIRM_FAIL()}, "$logIntro: Allowed transition from STATE_ASSIGNED_ID to STATE_ERROR_CONFIRM_FAIL");
    ok($rsm->{TRANSITIONS}->{STATE_ASSIGNED_ID()}->{STATE_ERROR()}, "$logIntro: Allowed transition from STATE_ASSIGNED_ID to STATE_ERROR");

    ok($rsm->{TRANSITIONS}->{STATE_CONFIRMED()}->{STATE_COMMITTED()}, "$logIntro: Allowed transition from STATE_CONFIRMED to STATE_COMMITTED");
    ok($rsm->{TRANSITIONS}->{STATE_CONFIRMED()}->{STATE_ERROR_COMMIT_FAIL()}, "$logIntro: Allowed transition from STATE_CONFIRMED to STATE_ERROR_COMMIT_FAIL");
    ok($rsm->{TRANSITIONS}->{STATE_CONFIRMED()}->{STATE_ERROR()}, "$logIntro: Allowed transition from STATE_CONFIRMED to STATE_ERROR");

    ok($rsm->{TRANSITIONS}->{STATE_COMMITTED()}->{STATE_PROVISIONED()}, "$logIntro: Allowed transition from STATE_COMMITTED to STATE_PROVISIONED");
    ok($rsm->{TRANSITIONS}->{STATE_COMMITTED()}->{STATE_ERROR()}, "$logIntro: Allowed transition from STATE_COMMITTED to STATE_ERROR");

    ok($rsm->{TRANSITIONS}->{STATE_PROVISIONED()}->{STATE_ACTIVE()}, "$logIntro: Allowed transition from STATE_PROVISIONED to STATE_ACTIVE");    
    ok($rsm->{TRANSITIONS}->{STATE_PROVISIONED()}->{STATE_ERROR_PROVISION_FAIL()}, "$logIntro: Allowed transition from STATE_PROVISIONED to STATE_ERROR_PROVISION_FAIL");
    ok($rsm->{TRANSITIONS}->{STATE_PROVISIONED()}->{STATE_ERROR()}, "$logIntro: Allowed transition from STATE_PROVISIONED to STATE_ERROR");

    ok($rsm->{TRANSITIONS}->{STATE_ACTIVE()}->{STATE_TERMINATED()}, "$logIntro: Allowed transition from STATE_ACTIVE to STATE_TERMINATED");
}

sub testNextSteps {
    my $logIntro = "TestStateMachine->testInitialisation";
    
    my $rsm;
    
    $rsm = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine->new(CURRENT_STATE   => STATE_CREATED, 
                                                                                                      TRANSITIONS     => RESERVATION_TRANSITIONS);

    # Test some of the trasitions
    $rsm->setNextState(STATE_ASSIGNED_ID);
    is($rsm->{CURRENT_STATE}, STATE_ASSIGNED_ID, "$logIntro: Transitioned from STATE_CREATED to STATE_ASSIGNED_ID");
    $rsm->setNextState(STATE_CONFIRMED);
    is($rsm->{CURRENT_STATE}, STATE_CONFIRMED, "$logIntro: Transitioned from STATE_ASSIGNED_ID to STATE_CONFIRMED");
    $rsm->setNextState(STATE_COMMITTED);
    is($rsm->{CURRENT_STATE}, STATE_COMMITTED, "$logIntro: Transitioned from STATE_CONFIRMED to STATE_COMMITTED");
    $rsm->setNextState(STATE_PROVISIONED);
    is($rsm->{CURRENT_STATE}, STATE_PROVISIONED, "$logIntro: Transitioned from STATE_COMMITTED to STATE_PROVISIONED");
    $rsm->setNextState(STATE_ACTIVE);
    is($rsm->{CURRENT_STATE}, STATE_ACTIVE, "$logIntro: Transitioned from STATE_PROVISIONED to STATE_ACTIVE");
    $rsm->setNextState(STATE_TERMINATED);
    is($rsm->{CURRENT_STATE}, STATE_TERMINATED, "$logIntro: Transitioned from STATE_ACTIVE to STATE_TERMINATED");

    $rsm = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationStateMachine->new(CURRENT_STATE   => STATE_CREATED, 
                                                                                                      TRANSITIONS     => RESERVATION_TRANSITIONS);

    $rsm->setNextState(STATE_CONFIRMED);
    is($rsm->{CURRENT_STATE}, STATE_CREATED, "$logIntro: Cannot transition to STATE_CONFIRMED without going through STATE_ASSIGNED_ID");

    $rsm->setNextState(STATE_ERROR);
    is($rsm->{CURRENT_STATE}, STATE_ERROR, "$logIntro: Transitioned to error state");
}

testInitialisation();
testNextSteps();

done_testing();

1;