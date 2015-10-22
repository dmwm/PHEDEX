package PHEDEX::Tests::File::Download::CircuitBackends::NSI::ExternalTool::TestReservationConstants;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;

use Test::More;

sub testIdentificationNextStates {
    my ($id, $result, $expectedState);

    # Identify state STATE_ASSIGNED_ID
    $id = "d005b619-16be-4312-82bf-4960ebdc6320";
    $expectedState = STATE_ASSIGNED_ID;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Submitted reserve, new connectionId = $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");

    # Identify state STATE_CONFIRMED
    $id = "d005b619-16be-4312-82bf-4960ebdc6321";
    $expectedState = STATE_CONFIRMED;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received reserveConfirmed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");

    # Identify state STATE_ERROR_CONFIRM_FAIL
    $id = "d005b619-16be-4312-82bf-4960ebdc6322";
    $expectedState = STATE_ERROR_CONFIRM_FAIL;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received reserveFailed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");

    # Identify state STATE_COMMITTED
    $id = "d005b619-16be-4312-82bf-4960ebdc6323";
    $expectedState = STATE_COMMITTED;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received reserveCommitConfirmed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");

    # Identify state STATE_ERROR_COMMIT_FAIL
    $id = "d005b619-16be-4312-82bf-4960ebdc6324";
    $expectedState = STATE_ERROR_COMMIT_FAIL;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received reserveCommitFailed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");

    # Identify state STATE_PROVISIONED
    $id = "d005b619-16be-4312-82bf-4960ebdc6325";
    $expectedState = STATE_PROVISIONED;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received provisionConfirmed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");
    
    # Identify state STATE_ERROR_PROVISION_FAIL
    $id = "d005b619-16be-4312-82bf-4960ebdc6326";
    $expectedState = STATE_ERROR_PROVISION_FAIL;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received provisionFailed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");
    
    # Identify state STATE_ACTIVE
    $id = "d005b619-16be-4312-82bf-4960ebdc6327";
    $expectedState = STATE_ACTIVE;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received dataPlaneStateChange for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");
    
    # Identify state STATE_TERMINATED
    $id = "d005b619-16be-4312-82bf-4960ebdc6328";
    $expectedState = STATE_TERMINATED;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received terminationConfirmed for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");
    
    # Identify state STATE_ERROR
    $id = "d005b619-16be-4312-82bf-4960ebdc6329";
    $expectedState = STATE_ERROR;
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received an errorEvent for connectionId: $id");
    ok($result, "Was able to identify a state based on this message");
    is($result->[0], $id, "Identified correct ID: $id");
    is($result->[1], $expectedState, "Identified state $expectedState");
    
    # Cannot identify state because of incorrect ID format
    $id = "d005b619-16be-4312-82bf-6329";
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("Received an errorEvent for connectionId: $id");
    is($result, undef, "Cannot identify state");
    
    # Cannot identify state because of unknown expression
    $id = "d005b619-16be-4312-82bf-4960ebdc6329";
    $result = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->identifyNextState("This is not the expression you are looking for connectionId: $id");
    is($result, undef, "Cannot identify state");
}

sub testValidStates {
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_CREATED), "State STATE_CREATED identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ASSIGNED_ID), "State STATE_ASSIGNED_ID identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_CONFIRMED), "State STATE_CONFIRMED identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ERROR_CONFIRM_FAIL), "State STATE_ERROR_CONFIRM_FAIL identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_COMMITTED), "State STATE_COMMITTED identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ERROR_COMMIT_FAIL), "State STATE_ERROR_COMMIT_FAIL identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_PROVISIONED), "State STATE_PROVISIONED identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ERROR_PROVISION_FAIL), "State STATE_ERROR_PROVISION_FAIL identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ACTIVE), "State STATE_ACTIVE identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_TERMINATED), "State STATE_ACTIVE identified");
    ok(PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState(STATE_ERROR), "State STATE_ERROR identified");
    ok(!PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants->isValidState("BLA BLA"), "Cannot identify state");
}

testIdentificationNextStates();
testValidStates();

done_testing();

1;