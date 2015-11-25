package PHEDEX::Tests::File::Download::NetworkResource::TestCircuit;

use strict;
use warnings;

use File::Path;
use IO::File;
use Test::More;

use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;

use PHEDEX::Tests::File::Download::Helpers::ObjectCreation;
use PHEDEX::Core::Timing;


# Trivial test consists of creating a circuit and making sure parameters are initialized correctly
sub testInitialisation {
    my $msg = "TestCircuit->testInitialisation";
    
    # Create circuit and initialise it
    my $testCircuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();
    my $success = $testCircuit->initResource("Dummy", "Node_A", "Node_B", 1);
    
    is($success, OK, "$msg: Object initialised successfully");
    ok($testCircuit->{ID}, "$msg: ID set");
    is($testCircuit->{NODE_A}, 'Node_A', "$msg: Object initialisation - Node_A set");
    is($testCircuit->{NODE_B}, 'Node_B', "$msg: Object initialisation - Node_B set");
    is($testCircuit->{BOOKING_BACKEND}, 'Dummy', "$msg: Object initialisation - Backend set");
    is($testCircuit->{STATUS}, STATUS_OFFLINE, "$msg: Object initialisation - Status set to offline");
    is($testCircuit->{STATE_DIR}, '/tmp/managed/circuits', "$msg: Object initialisation - Correct state folder set");
    is($testCircuit->{SCOPE}, 'GENERIC', "$msg: Object initialisation - Scope set");
    is($testCircuit->{REQUEST_TIMEOUT}, 5*MINUTE, "$msg: Object initialisation - Default request timeout set");
    is($testCircuit->{CIRCUIT_DEFAULT_LIFETIME}, 5*HOUR, "$msg: Object initialisation - Default lifetime set");
}

# Testing the getExpirationTime, isExpired and getLinkName subroutines
sub testHelperMethods {
    my $msg = "TestCircuit->testHelperMethods";
    
    # Test getExpiration time and isExpired
    my ($time, $timeNow) = (479317500, &mytimeofday() - 1800);

    my $testCircuit1 = createRequestingCircuit($time, 'Dummy', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2');
    my $testCircuit2 = createEstablishedCircuit($time, '192.168.0.1', '192.168.0.2', undef, $time, 'Dummy', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2');
    my $testCircuit3 = createEstablishedCircuit($time, '192.168.0.1', '192.168.0.2', undef, $time, 'Dummy', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2', 1800);
    my $testCircuit4 = createEstablishedCircuit($timeNow, '192.168.0.1', '192.168.0.2', undef, $timeNow, 'Dummy', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2', 1700);
    my $testCircuit5 = createEstablishedCircuit($timeNow, '192.168.0.1', '192.168.0.2', undef, $timeNow, 'Dummy', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2', 1900);
    my $testCircuit6 = createOfflineCircuit();

    # Test getExpirationTime
    is($testCircuit1->getExpirationTime(), undef, "$msg: Cannot get expiration time on a requesting circuit");
    is($testCircuit2->getExpirationTime(), undef, "$msg: Cannot get expiration time on a circuit without a lifetime set");
    is($testCircuit3->getExpirationTime(), 479317500+1800, "$msg: Expiration time correctly estimated");

    # Test isExpired
    is($testCircuit1->isExpired(), 0, "$msg: isExpired on a requesting circuit returns 0");
    is($testCircuit2->isExpired(), 0, "$msg: isExpired on an established circuit without lifetime returns 0");
    is($testCircuit3->isExpired(), 1, "$msg: Established circuit expired");
    is($testCircuit4->isExpired(), 1, "$msg: Established circuit expired");
    is($testCircuit5->isExpired(), 0, "$msg: Established circuit still valid");

    is($testCircuit1->{NAME}, 'T2_ANSE_CERN_1-to-T2_ANSE_CERN_2', "$msg: Name was set correctly");

    # Test getSavePaths
    ok($testCircuit1->getSavePaths() =~ /requested/, "$msg: getSavePaths works as it should on a requested circuit");
    ok($testCircuit2->getSavePaths() =~ /online/, "$msg: getSavePaths works as it should on a established circuit");
    ok($testCircuit6->getSavePaths() =~ /offline/, "$msg: getSavePaths works as it should on a offline circuit");
}

# Test consists of creating a circuit then attempting to save it
# while it is in different states. saveState should detect inconsistencies or errors
# and not attempt any save
# TODO: Move this to NetworkResource test and only test additional features
sub testSaveErrorHandling {
    my $msg = "TestCircuit->testSaveErrorHandling";
    
    # Clean tmp dir before everything else
    File::Path::rmtree('/tmp/managed/circuits', 1, 1) if (-d '/tmp/managed/circuits');
    
    my $testCircuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();    
    is($testCircuit->saveState(), ERROR_SAVING, "$msg: Unable to save an object which is not initialised");
    $testCircuit->initResource("Dummy", "Node_A", "Node_B", 0);
    is($testCircuit->saveState(), OK, "$msg: Saved circuit after initialisation");

    # Clean again
    File::Path::rmtree('/tmp/managed/circuits', 1, 1) if (-d '/tmp/managed/circuits');
    
    my $testCircuit2 = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();
    $testCircuit2->initResource("Dummy", "Node_A", "Node_B", 0);
    $testCircuit2->{STATE_DIR} = '';
    is($testCircuit2->saveState(), ERROR_SAVING, "$msg: Unable to save circuit since we cannot create state folder");

    File::Path::make_path('/tmp/managed/circuits');
    File::Path::make_path('/tmp/managed/circuits/offline', { mode => 555 });
    $testCircuit2->{STATE_DIR} = '/tmp/managed/circuits';
    is($testCircuit2->saveState(), ERROR_SAVING, "$msg: Unable to save since circuit cannot write to state folder");

    # Because rmtree doesn't seem to work when w permissions are missing
    system "rm -rf /tmp/managed/circuits";
}

# Test consists of creating circuits, saving them, reopening then verifying that the two match
# TODO: Move this to NetworkResource test and only test additional features
sub testSaveOpenObject{
    my $msg = "TestCircuit->testSaveOpenObject";
    
    File::Path::rmtree('/tmp/managed/circuits/', 1, 1) if (-d '/tmp/managed/circuits/');

    # save a circuit which is 'in request'
    my $testCircuit1 = createRequestingCircuit();
    my $saveName1 = $testCircuit1->getSavePaths();

    is($testCircuit1->saveState(), OK, "$msg: Successfully saved circuit in request state");
    ok(-e $saveName1, "$msg: Tested that save file exists");

    my $openedCircuit = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource::openState($saveName1);
    ok($openedCircuit, "$msg: Opened previously saved circuit in request state");
    is_deeply($testCircuit1, $openedCircuit, "$msg: Opened circuit is identical to the one which was saved");

    # save a circuit which is 'established'
    my $testCircuit2 = createEstablishedCircuit();
    my $saveName2 = $testCircuit2->getSavePaths();

    is($testCircuit2->saveState(), OK, "$msg: Successfully saved circuit in established state");
    ok(-e $saveName2, "$msg: Tested that save file exists");

    my $openedCircuit2 = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource::openState($saveName2);
    ok($openedCircuit2, "$msg: Opened previously saved circuit in established state");
    is_deeply($testCircuit2, $openedCircuit2, "$msg: Opened circuit is identical to the one which was saved");

    my $testCircuit3 = createEstablishedCircuit();
    $testCircuit3->registerTakeDown();

    my $time = formattedTime($testCircuit3->{LAST_STATUS_CHANGE});
    is($testCircuit3->saveState(), OK, "$msg: Successfully saved circuit in offline state");

    ok(-e $testCircuit3->getSavePaths(), "$msg: Tested that save file exists");
}

# Test consists of creating circuits, saving them then calling removeState on them (which should remove them from disk)
# TODO: Move this to NetworkResource test and only test additional features
sub testRemoveStateFiles {
    my $msg = "TestCircuit->testRemoveStateFiles";
    
     File::Path::rmtree('/tmp/managed/circuits/', 1, 1) if (-d '/tmp/managed/circuits/');

    # remove a state from a circuit which is 'in request'
    my $testCircuit = createRequestingCircuit();
    $testCircuit->saveState();
    ok(-e $testCircuit->getSavePaths(), "$msg: State file exists in /requested");
    is($testCircuit->removeState(), OK, "$msg: State file removed from /requested");
    is(-e $testCircuit->getSavePaths(), undef, "$msg: State file no longer exists in /requested");

    # remove a state from a circuit which is 'established'
    my $testCircuit2 = createEstablishedCircuit();
    $testCircuit2->saveState();
    ok(-e $testCircuit2->getSavePaths(), "$msg: State file exists in /established");
    is($testCircuit2->removeState(), OK, "$msg: State file removed from /established");
    is(-e $testCircuit2->getSavePaths(), undef, "$msg: State file no longer exists in /established");

    # remove a state from a circuit which is "offline"
    my $testCircuit3 = createEstablishedCircuit();
    $testCircuit3->registerTakeDown();
    $testCircuit3->saveState();
    ok(-e $testCircuit3->getSavePaths(), "$msg: State file exists in /offline");
    is($testCircuit3->removeState(), OK, "$msg: State file removed from /offline");
    is(-e $testCircuit3->getSavePaths(), undef, "$msg: State file no longer exists in /offline");

    # attempt (and fail) to remove a state for which there's no file
    my $testCircuit4 = createEstablishedCircuit();
    $testCircuit4->saveState();
    unlink $testCircuit4->getSavePaths();
    is($testCircuit4->removeState(), ERROR_GENERIC, "$msg: cannot find saved state");
}


# Test consists of creating circuits, then attempting to change their statuses
# by calling one of the subroutines registerRequest, registerEstablished, registerRequestFailure
# Circuit should only allow switching when certain parameters are met; for ex. cannot call registerEstablished on
# a circuit which isn't in request mode
sub testStatusChange{
    my $msg = "TestCircuit->testStatusChange";
    
    # Test methods on an uninitialised circuit
    my $emptyCircuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();
    is($emptyCircuit->registerRequest(), ERROR_GENERIC, "$msg: Cannot change state to requested (not initialised)");
    is($emptyCircuit->registerEstablished(), ERROR_GENERIC, "$msg: Cannot change state to established (not initialised)");

    my $testCircuit1 = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new(NODE_A => 'T2_ANSE_GENEVA', NODE_B => 'T2_ANSE_AMSTERDAM');
    $testCircuit1->initResource("Dummy", "T2_ANSE_GENEVA", "T2_ANSE_GENEVA", 0);
    is($testCircuit1->registerRequest(), OK, "$msg: Changed state to requested");
    is($testCircuit1->{STATUS}, STATUS_UPDATING, "$msg: Changed state verified");
    is($testCircuit1->registerEstablished(), ERROR_GENERIC, "$msg: Cannot change state to established (IPs not specified)");

    # Test methods on a circuit which is "in request"
    my $testCircuit2 = createRequestingCircuit();
    is($testCircuit2->registerRequest(), ERROR_GENERIC, "$msg: Cannot change state to requested");
    is($testCircuit2->registerEstablished('192.168.0.1'), ERROR_GENERIC, "$msg: Cannot change stat to established");
    is($testCircuit2->registerEstablished('192.168.0.1', '256.168.0.1'), ERROR_GENERIC, "$msg: Cannot change stat to established");
    is($testCircuit2->registerEstablished('192.168.0.1','192.168.0.2'), OK, "$msg: Changed state to established");
    is($testCircuit2->{STATUS}, STATUS_ONLINE, "$msg: Changed state verified - STATUS set");
    is($testCircuit2->{IP_A}, '192.168.0.1', "$msg: Changed state verified - fromIP set");
    is($testCircuit2->{IP_B}, '192.168.0.2', "$msg: Changed state verified - toIP set");

    # Test methods on a circuit which is "in request"
    my $testCircuit3 = createRequestingCircuit();
    is($testCircuit3->registerRequestFailure('my reason'), OK, "$msg: Changed state to request failed");
    is($testCircuit3->{STATUS}, STATUS_OFFLINE, "$msg: Changed state verified - STATUS set");
}

# Test consists of checking that registerRequestFailure and registerTransferFailure correctly save error details in circuit
sub testErrorLogging {
    my $msg = "TestCircuit->testErrorLogging";
    
    #Request error
    my $testCircuit1 = createRequestingCircuit();
    is($testCircuit1->registerRequestFailure('my reason'), OK, "$msg: Changed state to request failed");
    is($testCircuit1->getFailedRequest()->[0], $testCircuit1->{LAST_STATUS_CHANGE}, "$msg: Failed request successfully logged");
    is($testCircuit1->getFailedRequest()->[1], 'my reason', "$msg: Failed request successfully logged");

    my $startTime = &mytimeofday();

    # Transfer errors
    my $testCircuit2 = createRequestingCircuit();
    my $task1 = createTask($startTime, 1024**3, 30, 30);
    my $task2 = createTask($startTime, 1024**3, 30, 30);

    is($testCircuit2->registerEstablished('192.168.0.1','192.168.0.2', 'Dummy'), OK, "$msg: Changed state to established");
    is($testCircuit2->registerTransferFailure($task1, 'failure 1'), OK, "$msg: Task failure registered");
    is($testCircuit2->registerTransferFailure($task2, 'failure 2'), OK, "$msg: Task failure registered");

    my $failedTransfers = $testCircuit2->getFailedTransfers();

    is(scalar @$failedTransfers, 2, '$msg: Two transfers failed');

    is_deeply($task1, $failedTransfers->[0][1], "$msg: Initial circuit and opened circuit do not differ");
    is_deeply($task2, $failedTransfers->[1][1], "$msg: Initial circuit and opened circuit do not differ");
}

testInitialisation();
testHelperMethods();
testSaveErrorHandling();
testSaveOpenObject();
testRemoveStateFiles();
testStatusChange();
testErrorLogging();

done_testing();

1;