package PHEDEX::Tests::File::Download::CircuitBackends::TestDynesStates;

use strict;
use warnings;

use PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::Helpers::External;

use POE;
use Switch;
use Test::More;

POE::Session->create(
    inline_states => {
        _start => \&_start,
         handleAction=> \&handleAction,
    }
);

our ($allStates, $pid1, $pid2, $pid3, $pid4, $pid5);

sub _start {
    my ($kernel, $session) = @_[KERNEL, SESSION];

    # Create the object which will launch all the tasks
    my $tasker = PHEDEX::File::Download::Circuits::Helpers::External->new();
    # Create the action which is going to be called on STDOUT by External
    my $postback = $session->postback('handleAction');

    # Start commands and assign a DynesState object to each task
    $pid1 = $tasker->startCommand('cat ../TestData/AgentError.log', $postback, 2);
    $allStates->{$pid1} = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();

    $pid2 = $tasker->startCommand('cat ../TestData/CircuitFailedDeadlineTimeout.log', $postback, 2);
    $allStates->{$pid2} = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();

    $pid3 = $tasker->startCommand('cat ../TestData/CircuitOK_PingErrorFirstTime.log', $postback, 2);
    $allStates->{$pid3} = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();

    $pid4 = $tasker->startCommand('cat ../TestData/CircuitOK_PingOK.log', $postback, 2);
    $allStates->{$pid4} = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();

    $pid5 = $tasker->startCommand('cat ../TestData/CircuitTimeout.log', $postback, 2);
    $allStates->{$pid5} = PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates->new();
}

sub handleAction {
    my ($kernel, $session, $arguments) = @_[KERNEL, SESSION, ARG1];

    my $pid = $arguments->[EXTERNAL_PID];
    my $eventName = $arguments->[EXTERNAL_EVENTNAME];
    my $output = $arguments->[EXTERNAL_OUTPUT];

    my $stateOubject = $allStates->{$pid};
    my $returns = $stateOubject->updateState($output);

    if ($returns) {
        print "$returns->[0] - $returns->[1]\n";
    }
}

POE::Kernel->run();

# Check that all the state objects got where they should have given the current logs
is($allStates->{$pid1}->{CURRENT_STEP}, 0, "TestDynesStates - state object remains down in case of Agent error");
is($allStates->{$pid2}->{CURRENT_STEP}, 3, "TestDynesStates - state object gets to active, but there's an error at the other end");
is($allStates->{$pid3}->{CURRENT_STEP}, 5, "TestDynesStates - state object eventually gets to PING (ping doesn't start straight away)");
is($allStates->{$pid4}->{CURRENT_STEP}, 5, "TestDynesStates - state object gets to PING");
is($allStates->{$pid5}->{CURRENT_STEP}, 1, "TestDynesStates - state object remains in IN_PATH_CALCULATION, after which it times out");

done_testing;


1;