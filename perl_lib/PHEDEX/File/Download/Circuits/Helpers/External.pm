package PHEDEX::File::Download::Circuits::Helpers::External;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use POE;
use POE::Component::Child;

use PHEDEX::File::Download::Circuits::Constants;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        RUNNING_TASKS       =>      undef,
        VERBOSE             =>      0,
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    bless $self, $class;
    return $self;
}

# Launches an external command
# If an action is specified (callback/postback), it will be called for each event (STDOUT, STDERR, SIGCHLD)
# with the following arguments: PID, source event name, output
# If a timeout is specified (in seconds), the task will be terminated (via SIGINT) if no output is received
# from STDOUT/STDERR withing the allotted time frame
sub startCommand {
    my ($self, $command, $action, $timeout) = @_;

    my $pid;

    my $msg = "External->startCommand";
    # TODO: Extra checks potentially needed on the type of command that needs to run
    if (!defined $command) {
        $self->Logmsg('$msg: Cannot start external tool without correct parameters');
        return 0;
    }

#    $self->Logmsg('$msg: No action has been specified for this task (really?)') if (! defined $action);

    # Create a separate session for each of the tools that we want to run
    # Alternatively, we could also use the POE::Component:Child wrapper, which does a similar thing
    POE::Session->create(
        inline_states => {
            _start =>  sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];

                # Start a new wheel running the specified command
                my $task = POE::Wheel::Run->new(
                    Program         => $command,
                    Conduit         => "pty-pipe",

                    StdoutEvent     => "handleTaskStdOut",
                    StderrEvent     => "handleTaskStdError",
                    ErrorEvent      => "handleTaskFailed",
                    CloseEvent      => "handleTaskClose",

                    StdioDriver     => POE::Driver::SysRW->new(),
                    StdinFilter     => POE::Filter::Line->new(Literal => "\n"),
                );

                $pid = $task->PID;

                # Set which event will handle the SIGCHLD signal
                $kernel->sig_child($pid, "handleTaskSignal");

                # Add the task to the heap (or else it will go out of scope)
                $heap->{tasks_by_id}{$task->ID} = $task;
                $heap->{tasks_by_pid}{$pid} = $task;

                # We also need to remember the currently running tasks and the actions that need to be taken for each
                my $taskWrapper = {
                    TASK        =>  $task,
                    ACTION      =>  $action,
                };

                # If a timeout is defined, set an delay and remember the ALARM_ID
                if (defined $timeout) {
                    $self->Logmsg("$msg: Setting timeout for task");
                    $taskWrapper->{ALARM_ID} = $kernel->delay_set('handleTaskTimeout', $timeout, $heap, $pid);
                    $taskWrapper->{ALARM_TIMEOUT} = $timeout;
                }

                $self->{RUNNING_TASKS}{$pid} = $taskWrapper;
            }
        },
        object_states => [
            $self => {
                handleTaskStdOut    =>  'handleTaskStdOut',
                handleTaskStdError  =>  'handleTaskStdOut',
                handleTaskClose     =>  'handleTaskClose',
                handleTaskSignal    =>  'handleTaskSignal',
                handleTaskTimeout   =>  'handleTaskTimeout',
            }
        ]
    );

    return $pid;
}

sub getTaskByPID {
    my ($self, $pid) = @_;
    
    if (! defined $self->{RUNNING_TASKS}->{$pid}) {
        $self->Logmsg("Cannot find the requested PID");
        return;
    }
    
    return $self->{RUNNING_TASKS}->{$pid}->{TASK};
}
# Wheel event for both the StdOut and StdErr output
# The action specified for this task will be called with
# with the following parameters (PID, event name, output)
# Output will be handled to the specified action and parsed there (not by this class)
sub handleTaskStdOut {
    my ($self, $sendingEvent, $heap, $output, $wheelId) = @_[OBJECT, STATE, HEAP, ARG0, ARG1];

    my $msg = "External->handleTaskStdOut";

    my $task = $heap->{tasks_by_id}{$wheelId};
    my $pid = $task->PID;
    my $action =  $self->{RUNNING_TASKS}{$task->PID}{ACTION};

    # Tick, so we know that the task is still alive
    $self->timerTick($pid);
    $self->Logmsg("$msg: $pid - $output")
    if $self->{VERBOSE};

    # If an action was specified, call it
    if (defined $action) {
        my @arguments;
        $arguments[EXTERNAL_TASK] = $task;
        $arguments[EXTERNAL_PID] = $pid;
        $arguments[EXTERNAL_EVENTNAME] = $sendingEvent;
        $arguments[EXTERNAL_OUTPUT] = $output;
        $action->(@arguments);
    }
}

# Wheel event when the task closes its output handle
# This might or might not be used in the future...
sub handleTaskClose {
    my ($self, $sendingEvent, $heap, $wheelId) = @_[OBJECT, STATE, HEAP, ARG0];

    my $msg = "External->handleTaskClose";

    $self->Logmsg("$msg: Task closed its last output handle");
}

# Signal event when the child exists
# If there's an action to be done, it will be called
# Cleanup is done when everything is finished
sub handleTaskSignal {
    my ($self, $sendingEvent, $heap, $pid) = @_[OBJECT, STATE, HEAP, ARG1];

    my $msg = "External->handleTaskSignal";

    my $task = $heap->{tasks_by_pid}{$pid};
    my $action = $self->{RUNNING_TASKS}{$task->PID}{ACTION};

    $self->cleanupTask($heap, $task);

    $self->Logmsg("$msg: Task ($pid) has been terminated");
        # If an action was specified, call it
    if (defined $action) {
        my @arguments;
        $arguments[EXTERNAL_PID] = $pid;
        $arguments[EXTERNAL_EVENTNAME] = $sendingEvent;
        $action->(@arguments);
    }
}

# Event called in case the tool does not reply within a given time
# This only applied if a timeout has been specified when 'startCommand' was issued
sub handleTaskTimeout {
    my ($self, $kernel, $session, $sendingEvent, $heap, $pid) = @_[OBJECT, KERNEL, SESSION, STATE, ARG0, ARG1];

    my @results = @_;
    my $msg = "External->handleTaskTimeout";
    $self->Logmsg("$msg: Didn't receive any output from task in a long time. Killing task");

    $self->kill_task($pid);
}

# Re-adjusts the alarm since the task  is still alive
sub timerTick {
    my ($self, $pid) = @_;
    my $taskWrapper = $self->{RUNNING_TASKS}{$pid};
    if (defined $taskWrapper->{ALARM_ID}) {
        POE::Kernel->alarm_adjust($taskWrapper->{ALARM_ID}, $taskWrapper->{ALARM_TIMEOUT});
    }
}

# Cleans up the heap
# Removes defunct references from $self
# Removes the timeout timer that might have been set
sub cleanupTask {
    my ($self, $heap, $task) = @_;

    my $msg = "External->cleanupTask";

    if (!defined $heap || !defined $task) {
        $self->Logmsg("$msg: Cannot clean up with invalid parameters");
        return;
    }

    my $pid = $task->PID;

    $self->Logmsg("$msg: Cleaning up task ($pid)");
    delete $heap->{tasks_by_id}{$task->ID};
    delete $heap->{tasks_by_pid}{$pid};

    my $taskWrapper = $self->{RUNNING_TASKS}{$pid};
    if (defined $taskWrapper->{ALARM_ID}) {
        $self->Logmsg("$msg: Removing timer for PID ($pid)");
        POE::Kernel->alarm_remove($taskWrapper->{ALARM_ID}) ;
    }

    delete $self->{RUNNING_TASKS}{$pid};
}

# Sends a SIGINT signal to the task
# TODO: Use a new timer in case this won't respond to it
sub kill_task {
    my ($self, $pid) = @_;

    my $msg = "External->kill_task";

    if (!defined $self->{RUNNING_TASKS}{$pid}) {
        $self->Logmsg("$msg: Cannot find any process with the specified PID $pid");
        return;
    }

    $self->Logmsg("$msg: Killing PID $pid (SIGINT)");
    $self->{RUNNING_TASKS}{$pid}{TASK}->kill("INT");
}

1;