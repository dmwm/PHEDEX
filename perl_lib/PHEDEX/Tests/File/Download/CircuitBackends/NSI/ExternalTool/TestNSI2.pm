package PHEDEX::Tests::File::Download::CircuitBackends::NSI::ExternalTool::TestNSI2;

use strict;
use warnings;

use PHEDEX::File::Download::Circuits::Helpers::External;
use PHEDEX::File::Download::Circuits::Constants;

use POE;
use Switch;
use Test::More;


POE::Session->create(
    inline_states => {
        _start => \&_start,
         handleAction=> \&handleAction,
         putSomethingThere => \&putSomethingThere,
    }
);

our ($allStates, $pid1);

sub _start {
    my ($kernel, $session) = @_[KERNEL, SESSION];
    
    my $params = {
        NSI_TOOL_LOCATION   => '/data/NSI/CLI',
        NSI_TOOL            => 'nsi-cli-1.2.1-one-jar.jar',
        NSI_JAVA_FLAGS      =>  '-Xmx256m -Djava.net.preferIPv4Stack=true '.
                                '-Dlog4j.configuration=file:./config/log4j.properties ',
                                '-Dcom.sun.xml.bind.v2.runtime.JAXBContextImpl.fastBoot=true ',
                                '-Dorg.apache.cxf.JDKBugHacks.defaultUsesCaches=true ',
    };    
    
    chdir $params->{NSI_TOOL_LOCATION};
    
    # Create the object which will launch all the tasks
    my $tasker = PHEDEX::File::Download::Circuits::Helpers::External->new();
    # Create the action which is going to be called on STDOUT by External
    my $postback = $session->postback('handleAction');

    
    # Start commands and assign a DynesState object tol each task
    $pid1 = $tasker->startCommand("java $params->{NSI_JAVA_FLAGS} -jar $params->{NSI_TOOL}", $postback);
    $tasker->getTaskByPID($pid1)->put('nsi override');
    
#    $pid1 = $tasker->startCommand("telnet", $postback);
    
    POE::Kernel->delay(putSomethingThere => 7, $tasker->getTaskByPID($pid1));
}

sub putSomethingThere {
    my ($kernel, $session, $task) = @_[KERNEL, SESSION, ARG0];
    
    print "Issuing commands now: \n";

    $task->put("quit");
}

sub handleAction {
    my ($kernel, $session, $arguments) = @_[KERNEL, SESSION, ARG1];
    my $task = $arguments->[EXTERNAL_TASK];
    my $output = $arguments->[EXTERNAL_OUTPUT];

    if ($output) {
        print "$output\n";
    }
    
}

POE::Kernel->run();

done_testing;


1;