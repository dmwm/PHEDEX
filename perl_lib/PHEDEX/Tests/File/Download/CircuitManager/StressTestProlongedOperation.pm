package PHEDEX::Tests::File::Download::StressTestProlongedOperation;

use strict;
use warnings;

use List::Util qw[max];
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::Tests::File::Download::Helpers::ObjectCreation;
use PHEDEX::Tests::File::Download::Helpers::SessionCreation;
use POE;
use Test::More;
use Switch;

our $linkIndex = 0;
our $links = [['T2_ANSE_CERN_1', 'T2_ANSE_CERN_2'],
              ['T2_ANSE_CERN_1', 'T2_ANSE_CERN_Dev'],
              ['T2_ANSE_CERN_2', 'T2_ANSE_CERN_1'],
              ['T2_ANSE_CERN_2', 'T2_ANSE_CERN_Dev'],
              ['T2_ANSE_CERN_Dev', 'T2_ANSE_CERN_1'],
              ['T2_ANSE_CERN_Dev', 'T2_ANSE_CERN_2']];

# Timings (in seconds)
our $tBackendDelay = 0.03;              # Delay induced by Dummy backend between when a request was made and when it 'establishes' a circuit
our $tCircuitLifetime = 0.03;           # Lifetime of a circuit
our $tRequestTimeout = 0.04;            # Delay before the request times out
our $tUnblacklist = 0.03;               # Delay before removing a circuit from a blacklist

our $tHistoryTrimming = 1;
our $tMainLoopRestart = 0.01;

our ($scenarioName, $scenarioStep);

# Order and timings of the events in each scenario
our $scenarios = {
    'normal'            => [[\&iCheckRequest, 0.01],
                            [\&iCheckEstablished, $tBackendDelay],
                            [\&iCheckTeardown, $tCircuitLifetime]],

    'request_failure'   => [[\&iCheckRequest, 0.01],
                            [\&iCheckRequestFailure, $tBackendDelay],
                            [\&iCheckUnblacklist, $tUnblacklist]],

    'request_timeout'   => [[\&iCheckRequest, 0.01],
                            [\&iCheckRequestFailure, $tRequestTimeout],
                            [\&iCheckUnblacklist, $tUnblacklist]],

    'transfer_failure'  => [[\&iCheckRequest, 0.01],
                            [\&iCheckEstablished, $tBackendDelay],
                            [\&iFailTransfers, 0.01],
                            [\&iCheckTeardown, $tCircuitLifetime],
                            [\&iCheckUnblacklist, $tUnblacklist]],
};

sub getLink {
    # Get one of the links sequentially
    my $fromNode = $links->[$linkIndex][0];
    my $toNode =  $links->[$linkIndex][1];
    my $linkName = $fromNode."-to-".$toNode;

    $linkIndex = ++$linkIndex % @{$links};

    return ($fromNode, $toNode, $linkName);
}

# Chooses a random scenario to test
# Initializes default values in circuit manager needed for a given scenario and resets the scenario step
sub chooseScenario {
    my $circuitManager = shift;
    my @scenarioNames = keys %{$scenarios};
    my $scenario = int(rand(scalar @scenarioNames));

    $scenarioStep = 0;
    $scenarioName = $scenarioNames[$scenario];

    switch ($scenarioName) {
        case 'request_timeout' {
            $circuitManager->{BACKEND}{TIME_SIMULATION} = undef;
        }
        case 'request_failure' {
            $circuitManager->{BACKEND}{TIME_SIMULATION} = -$tBackendDelay;
        }
        else {
            # normal or transfer_failure
            $circuitManager->{BACKEND}{TIME_SIMULATION} = $tBackendDelay;
        }
    }
}

sub yieldToNextStep {
    my ($circuitManager, $circuit, $linkName) = @_;

    my $scenarioDetails = $scenarios->{$scenarioName};
    my $scenarioSteps = @{$scenarioDetails};

    if ($scenarioStep == $scenarioSteps) {
        POE::Kernel->delay(\&iMainLoop => $tMainLoopRestart, $circuitManager, POE::Kernel->ID_id_to_session($circuitManager->{SESSION_ID}));
        return;
    }

    my $eventDetails = $scenarioDetails->[$scenarioStep++];
    print "Step is $scenarioStep of $scenarioSteps\n";
    POE::Kernel->delay($eventDetails->[0] => $eventDetails->[1], $circuitManager, $circuit, $linkName);

}

sub iMainLoop {
    my ($circuitManager, $session) =  @_[ARG0, ARG1];

    my ($fromNode, $toNode, $linkName) = getLink();
    chooseScenario($circuitManager);

    print "---------------------------------------------------------------------\n";

    $circuitManager->Logmsg("Testing link '$linkName' on scenario '$scenarioName'");

    POE::Kernel->post($session, 'requestCircuit', $fromNode, $toNode, $tCircuitLifetime);

    yieldToNextStep($circuitManager, undef, $linkName);
}

# Checks that a circuit has been requested, then sets up a timer to iCheckEstablished
sub iCheckRequest {
    my ($circuitManager, $linkName) = @_[ARG0, ARG2];

    my $circuit = $circuitManager->{RESOURCES}{$linkName};

    ok(defined $circuit, "stress test / iCheckRequest - Circuit exists in circuit manager");
    is($circuit->{STATUS}, STATUS_UPDATING, "stress test / iCheckRequest - Circuit is in requesting state in circuit manager");

    my $path = $circuit->getSavePaths();
    ok($path  =~ m/requested/ && -e $path, "stress test / iCheckRequest - Circuit (in requesting state) exists on disk as well");

    # POE alarms test
    ok(defined $circuitManager->{DELAYS}{&TIMER_REQUEST}{$circuit->{ID}}, "stress test / iCheckRequest - Timer for request timeout set");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

# Checks that a circuit has been established, then sets up a timer to iCheckTeardown
sub iCheckEstablished {
    my ($circuitManager, $circuit, $linkName) = @_[ARG0, ARG1, ARG2];

    ok(defined $circuit, "stress test / iCheckEstablished - Circuit exists in circuit manager");
    is($circuit->{STATUS}, STATUS_ONLINE,"stress test / iCheckEstablished - Circuit is in established state in circuit manager");

    my $path = $circuit->getSavePaths();
    ok($path  =~ m/online/ && -e $path, "stress test / iCheckEstablished - Circuit (in established state) exists on disk as well");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

# Checks that a circuit has been put in history
sub iCheckTeardown {
    my ($circuitManager, $circuit, $linkName) = @_[ARG0, ARG1, ARG2];

    ok(!defined $circuitManager->{RESOURCES}{$linkName}, "stress test / iCheckTeardown - Circuit doesn't exist in circuit manager anymore");
    ok(defined $circuitManager->{RESOURCE_HISTORY}{$linkName}{$circuit->{ID}}, "stress test / iCheckTeardown - Circuit exists in circuit manager history");

    is($circuit->{STATUS}, STATUS_OFFLINE,"stress test / iCheckTeardown - Circuit is in offline state in circuit manager");

    my $path = $circuit->getSavePaths();
    ok($path  =~ m/offline/ && -e $path, "stress test / iCheckTeardown - Circuit (in offline state) exists on disk as well");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

sub iCheckRequestFailure {
    my ($circuitManager, $circuit, $linkName) = @_[ARG0, ARG1, ARG2];

    my $path = $circuit->getSavePaths();

    # Circuit related tests
    is($circuit->{STATUS}, STATUS_OFFLINE, "stress test / iCheckRequestFailure - Circuit is in offline state");
    ok(!defined $circuitManager->{RESOURCES}{$linkName},"stress test / iCheckRequestFailure - Circuit is no longer in RESOURCES");
    ok($circuitManager->{RESOURCE_HISTORY}{$linkName}{$circuit->{ID}},"stress test / iCheckRequestFailure - Circuit is now in RESOURCE_HISTORY");
    ok($path  =~ m/offline/ && -e $path, "stress test / iCheckRequestFailure - Circuit (in offline state) exists on disk as well");

    my $failedReq = $circuit->getFailedRequest();
    ok(defined $failedReq, "stress test / iCheckRequestFailure - Circuit request failed");

    switch ($scenarioName) {
        case 'request_timeout' {
            is($failedReq->[1], CIRCUIT_REQUEST_FAILED_TIMEDOUT, "stress test / iCheckRequestFailure - Circuit request failed on timeout");
        }
        case 'request_failure' {
            is($failedReq->[1], CIRCUIT_REQUEST_FAILED, "stress test / iCheckRequestFailure - Circuit request failed with code received from backend");
        }
    }

    ok($circuitManager->{LINKS_BLACKLISTED}{$linkName}, "stress test / iCheckRequestFailure - Link is now blacklisted");

    # POE alarms test
    ok(!defined $circuitManager->{DELAYS}{&TIMER_REQUEST}{$circuit->{ID}}, "stress test / iCheckRequestFailure - Timer for request timeout removed");
    ok(!defined $circuitManager->{DELAYS}{&TIMER_TEARDOWN}{$circuit->{ID}}, "stress test / iCheckRequestFailure - Timer for teardown removed");
    ok(defined $circuitManager->{DELAYS}{&TIMER_BLACKLIST}{$circuit->{ID}}, "stress test / iCheckRequestFailure - Timer for unblacklist set");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

sub iFailTransfers {
    my ($circuitManager, $circuit, $linkName) = @_[ARG0, ARG1, ARG2];

    my $time = &mytimeofday();
    for (my $i = 0; $i <= 100; $i++) {
        my $task = createTask($time, 1024**3, 30, 30);
        $circuitManager->transferFailed($circuit, $task)
    }

    ok($circuitManager->{LINKS_BLACKLISTED}{$linkName}, "stress test / iFailTransfers - Link is now blacklisted");
    ok(defined $circuitManager->{DELAYS}{&TIMER_BLACKLIST}{$circuit->{ID}}, "stress test / iFailTransfers - Timer for unblacklist set");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

sub iCheckUnblacklist {
    my ($circuitManager, $circuit, $linkName) = @_[ARG0, ARG1, ARG2];

    ok(!$circuitManager->{LINKS_BLACKLISTED}{$linkName}, "stress test / iCheckUnblacklist - Link is now removed from blacklist");
    ok(!defined $circuitManager->{DELAYS}{&TIMER_BLACKLIST}{$circuit->{ID}}, "stress test / iCheckUnblacklist - Timer for unblacklist removed");

    yieldToNextStep($circuitManager, $circuit, $linkName);
}

sub iCheckHistoryTrimming {
    my ($circuitManager) = $_[ARG0];

    my ($olderThanNeeded, @circuitsOffline);

    &getdir($circuitManager->{STATE_DIR}."/offline", \@circuitsOffline);

    ok(scalar @{$circuitManager->{RESOURCE_HISTORY_QUEUE}} <=  $circuitManager->{MAX_HISTORY_SIZE}, "There are no more than $circuitManager->{MAX_HISTORY_SIZE} circuits in HISTORY");
    ok(scalar @circuitsOffline <=  $circuitManager->{MAX_HISTORY_SIZE}, "There are no more than $circuitManager->{MAX_HISTORY_SIZE} circuits in HISTORY folder");

    POE::Kernel->delay(\&iCheckHistoryTrimming => $tHistoryTrimming, $circuitManager);
}

my ($circuitManager, $session) = setupResourceManager(10, 'creating-circuit-requests.log', undef,
                                                        [[\&iMainLoop, 0.001],
                                                         [\&iCheckRequest, undef],
                                                         [\&iCheckEstablished, undef],
                                                         [\&iCheckTeardown, undef],
                                                         [\&iCheckRequestFailure, undef],
                                                         [\&iFailTransfers, undef],
                                                         [\&iCheckUnblacklist, undef],
                                                         [\&iCheckHistoryTrimming, 1]]);
# We don't need all of the log messages
$circuitManager->{VERBOSE} = 0;
$circuitManager->Logmsg('Stress-testing the circuit manager according to predefined scenarios');
$circuitManager->{SYNC_HISTORY_FOLDER} = 1;
$circuitManager->{REQUEST_TIMEOUT} = $tRequestTimeout;
$circuitManager->{BLACKLIST_DURATION} = $tUnblacklist;

### Run POE
POE::Kernel->run();

print "The end\n";

done_testing();

1;