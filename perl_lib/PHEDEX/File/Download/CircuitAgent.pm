# This object extends the File::Download::Agent by adding circuit awareness
package PHEDEX::File::Download::CircuitAgent;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use PHEDEX::Error::Constants;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::ResourceManager;
use PHEDEX::File::Download::Circuits::TFCUtils;

use feature qw(switch);
use List::Util qw(min max sum);
use Data::Dumper;
use LWP::Simple;
use POSIX;
use POE;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
            # Backend
            CIRCUIT_BACKEND                 =>      'Dummy',                    # For now, only one circuit booking backend is supported

            # Various timings
            DELAY_WORKLOAD_CHECK            =>      MINUTE,                     # Period of 'check_workload' event
            MAX_TASK_AGE                    =>      3*HOUR,                     # Finished tasks older than this will not contribute to average rate calculations

            # Circuit booking decisions
            CIRCUIT_THRESHOLD               =>      3*HOUR,                     # Amount of work in needed before deeming a circuit necessary
            ENFORCE_BANDWIDTH_CHECK         =>      0,                          # If the flag is set, it will also require that the bandwidth given by the circuit should be > avg rate on normal link
		);
		
    my %args = (@_);
    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    # Create circuit manager
    $self->{CIRCUIT_MANAGER} = PHEDEX::File::Download::Circuits::ResourceManager->new(CIRCUITDIR   => "$self->{DROPDIR}"."/circuits",
                                                                                      BACKEND_TYPE => $self->{CIRCUIT_BACKEND},
                                                                                      BACKEND_ARGS => {AGENT_TRANSLATION_FILE => '/data/agent_ips.txt'},
                                                                                      VERBOSE      => $self->{VERBOSE});

    # Redefine how to handle signals
    $SIG{INT} = $SIG{TERM} = sub {
        $self->{SIGNALLED} = shift;
		$self->{JOBMANAGER}->killAllJobs();
		
		# Cancels requests in progress and tears_down existing circuits
		$self->{CIRCUIT_MANAGER}->stop();
    };

    bless $self, $class;
    return $self;
}

# Initialize all POE events specifically related to circuits
sub _poe_init
{
    my ($self, $kernel, $session) = @_[ OBJECT, KERNEL, SESSION ];

    # Needed since we're calling this subroutine directly instead of passing through POE
    my @superArgs; @superArgs[KERNEL, SESSION] = ($kernel, $session); shift @superArgs;

    # Parent does the main initialization of POE events
    $self->SUPER::_poe_init(@superArgs);

    # Hand the session over to the circuit manager as well
    $self->{CIRCUIT_MANAGER}->_poe_init($kernel, $session);

    # And we handle the ones related to circuits
    my @poe_subs = qw(check_workload);

    $kernel->state($_, $self) foreach @poe_subs;

    # Get periodic events going
    $kernel->yield('check_workload');
}

# Peridic event that checks the current workload for each link
# This is done by estimating the amount of time that would be
# spent on pending tasks, given the current average rate for that link
# The current average rate is calculated either from
#   - successfully finished tasks on normal links
#   - DB
sub check_workload
{
    my ($self, $kernel, $session) = @_[ OBJECT, KERNEL, SESSION ];
    my ($tasks, $circuitManager) = ($self->{TASKS}, $self->{CIRCUIT_MANAGER});

    my $mess = "CircuitAgent->check_workload";

    $self->Logmsg("$mess: Enter event") if ($self->{VERBOSE});

    $self->delay_max($kernel, 'check_workload', $self->{DELAY_WORKLOAD_CHECK});

    if (! defined $tasks || ! keys %{$tasks}) {
        $self->Logmsg("$mess: There are no tasks to look at") if ($self->{VERBOSE});
        return;
    }

    # links -> {
    #   linkID -> {
    #       DONE_TASKS -> {
    #           JOBID       ->  [ TASK1, TASK2, ... ]
    #       }
    #       PENDING         ->  [ TASK21, TASK22, ... ]
    #       PENDING_BYTES   ->  Total bytes pending
    #   }
    # }
    my ($now, $links, $pendingTasks, $nodeMapping) = (&mytimeofday(), {}, 0, {});

    # Go through all the tasks available and group them based on finished or pending
    foreach my $task (values %$tasks) {

        # Get the link name via Circuits (for consistency)
        my $linkID = &getLink($task->{FROM_NODE}, $task->{TO_NODE});

        # Skip doing anything if a circuit was already requested or established for this link
        if (defined $circuitManager->{CIRCUITS}{$linkID}) {
            $self->Logmsg("$mess: A circuit request has already been established for $linkID. Skipping calculations") if ($self->{VERBOSE});
            next;
        }

        # If the task has successfully finished and isn't older than MAX_TASK_AGE
        if ($task->{FINISHED} &&
            $task->{FINISHED} > &mytimeofday() - $self->{MAX_TASK_AGE} &&
            $task->{REPORT_CODE} == 0 && $task->{XFER_CODE} == 0) {

            # Store all the finished tasks by JOBID
            # All tasks in one job share the same start time and finish time
            # We'll use this info to get the average transfer rate for a particular job
            push(@{$links->{$linkID}{DONE_TASKS}{$task->{JOBID}}}, $task);
        }

        # From here on, only consider jobs that are pending
        if ($task->{STARTED} || $task->{FINISHED}) {
            next;
        }

        # This is needed for the estimation of the work that remains to be done
        $links->{$linkID}{PENDING_BYTES} += $task->{FILESIZE};
        $links->{$linkID}{FROM_NODE} = $task->{FROM_NODE};
        $links->{$linkID}{TO_NODE} = $task->{TO_NODE};

        $pendingTasks++;

        $nodeMapping->{$task->{FROM_NODE_ID}} = $task->{FROM_NODE};
        $nodeMapping->{$task->{TO_NODE_ID}} = $task->{TO_NODE};
    }

    # If there are no pending links it makes no sense to continue
    if (!$pendingTasks) {
        $self->Logmsg("$mess: There are no pending tasks - nothing remains to be done");
        return;
    }

    # Loop through all the link data and calculate the average rate for each link
    foreach my $linkID (keys %$links) {
        my ($averageRate, $doneBytes, $transferDuration);
        my $doneTasks = $links->{$linkID}{DONE_TASKS};

        next if (!defined $doneTasks || scalar $doneTasks == 0);

        # Loop through all the jobs in DONE_TASKS
        foreach my $jobID (keys %$doneTasks) {
            my ($job, $timeDiff) = ($doneTasks->{$jobID});

            # Loop through all the tasks in a that job
            foreach my $task (@{$job}) {
                $doneBytes += $task->{FILESIZE};
                $timeDiff += $task->{FINISHED} - $task->{STARTED};
            }

            # Average job duraction
            $transferDuration += $timeDiff / scalar @{$job};
        }

        # TODO: It would also be interesting to calculate the variance of average rates
        # bewtween different jobs on the same link. It might be that even if the circuit would not
        # provide significant extra BW, it might be nice to have transfer rates with lower variance
        $averageRate = $doneBytes / $transferDuration; # in Bytes/second

        if ($averageRate > 0) {
            $links->{$linkID}{AVERAGE_RATE} = $averageRate;
            $self->Logmsg("$mess: Calculated an average rate of $averageRate (bytes/second) for link: $linkID based on done tasks");
        }
    }

    # Also check for statistics from T_ADM_LINK_PARAM
    # TODO: We should restrict the query to only the pair of nodes for which we don't have fresh statistics
    # There's also the problem of statistics added to the DB which pertain to circuits
    $self->Logmsg("$mess: Getting stats from DB for all nodes") if ($self->{VERBOSE});
    my @nodes = join(',', values %{$self->{NODES_ID}});
    my $rateQuery = &dbexec($$self{DBH},
                qq{
                    select from_node, to_node,
                           xfer_rate, xfer_latency
                    from t_adm_link_param
                    where to_node in (@nodes)
                });

    while (my $row = $rateQuery->fetchrow_hashref()) {
        if (defined $row->{XFER_RATE} && $row->{XFER_RATE} > 0) {
            my $from_node = $nodeMapping->{$row->{FROM_NODE}};
            my $to_node = $nodeMapping->{$row->{TO_NODE}};

            #TODO: DO we need to check to/from nodes?
            my $linkID = &getLink($from_node, $to_node);
            if (!defined $links->{$linkID}{AVERAGE_RATE}) {
                $links->{$linkID}{AVERAGE_RATE} = $row->{XFER_RATE};
            }
        }
    }

    my @circuitsToRequest;

    # Check to see if there are any links for which it's worth requesting a circuit
    foreach my $linkID (keys %$links) {
        my $linkData = $links->{$linkID};

        # Check to see if we should request a circuit for the link, then if we can request it
        if ($self->_should_request_circuit($linkID, $linkData)) {
                push(@circuitsToRequest, $linkID);
        }
    }

    if  (scalar @circuitsToRequest > 0) {
        foreach my $link (@circuitsToRequest) {
            $kernel->post($session, 'requestCircuit', $links->{$link}{FROM_NODE}, $links->{$link}{TO_NODE}, $self->{CIRCUIT_DEFAULT_LIFETIME}) ;
        }
    }
}

# Tells us if we should request a circuit or not
sub _should_request_circuit {
    my ($self, $linkID, $linkData) = @_;
    my $circuitManager = $self->{CIRCUIT_MANAGER};

    my $mess = "CircuitAgent->_should_request_circuit";

    if (!defined $linkData->{AVERAGE_RATE} ||
        !defined $linkData->{PENDING_BYTES}) {
            $self->Logmsg("$mess: Cannot decide if we should request a circuit for $linkID when there are no performance measurements") if ($self->{VERBOSE});
            return 0;
    }

    if ($circuitManager->canRequestCircuit($linkData->{FROM_NODE}, $linkData->{TO_NODE}) < 0) {
        $self->Logmsg("$mess: Cannot request a circuit on the current link ");
        return 0;
    }

    my $circuitBW = $circuitManager->{BACKEND}->getCircuitBandwidth($linkData->{FROM_NODE}, $linkData->{TO_NODE});
    if ($self->{ENFORCE_BANDWIDTH_CHECK} && $linkData->{AVERAGE_RATE} > $circuitBW) {
        $self->Logmsg("$mess: Enforce bandwidth check flag is set and average rate on normal link is higher than on circuit");
        return 0;
    }

    my $pendingWork = $linkData->{PENDING_BYTES} / $linkData->{AVERAGE_RATE};
    $self->Logmsg("$mess: Link $linkID has $pendingWork seconds of pending work") if ($self->{VERBOSE});

    return ($pendingWork > $self->{CIRCUIT_THRESHOLD});
}

# Marks a task as ready to transfer.  The transfer will begin when the
# backend detects that all tasks in a job are ready.
sub transfer_task
{
    my ($self, $kernel, $taskid) = @_[ OBJECT, KERNEL, ARG0 ];

    my $mess = "CircuitAgent->transfer_task";

    my $task = $self->getTask($taskid) || $self->forgetTask($taskid) && return;

    my ($fromProtocol, $toProtocol) = ($task->{FROM_PROTOS}[0], $task->{TO_PROTOS}[0]);

    # Check to see if a circuit is online for this pair of nodes
    my $circuit = $self->{CIRCUIT_MANAGER}->checkCircuit($task->{FROM_NODE}, $task->{TO_NODE}, STATUS_ONLINE);

    # A circuit is established, better as well use it
    # TODO: We probably should do a bulk change of PFNs per job, instead of per task in job
    # It mighat happen that a circuit becomes active, while tasks in a job are marked ready
    # for transfer. Because of this, we could end up with a job list that has several
    # files using a circuit and several files in a job that still use the original link
    # FDTCP is smart enough that when it receives a copyjob file like this, it will
    # sequentially launch two separate jobs (one for the files on the circuit and
    # one for the files on the normal link) so no files in a job are lost, when the swich occurs
    if (defined $circuit) {
        my ($fromIP, $toIP) = ($circuit->{IP_A}, $circuit->{IP_B});

        my $fromPFN = replaceHostname($task->{FROM_PFN}, $fromProtocol, $fromIP, );
        my $toPFN = replaceHostname($task->{TO_PFN}, $toProtocol, $toIP);

        if (defined $toPFN && defined $fromPFN) {
            $self->Logmsg("$mess: Circuit detected! Replaced TO/FROM PFN. New PFNs: $toPFN, $fromPFN");

            $task->{FROM_PFN} = $fromPFN;
            $task->{TO_PFN} = $toPFN;

            $task->{CIRCUIT} = $circuit->{ID};
            $task->{CIRCUIT_LINK} = $circuit->getLinkName();
            $task->{IP_A} = $fromIP;
            $task->{IP_B} = $toIP;
        } else {
            $self->Logmsg("$mess: Cannot replace hostname in one or more PFNs");
        }
    }

    $task->{READY} = &mytimeofday();
    $self->saveTask($taskid) || return;
}


# Mark a task completed.  Brings the next synchronisation into next
# fifteen minutes, and updates statistics for the current period.
sub finish_task
{
    my ($self, $kernel, $taskid ) = @_[ OBJECT, KERNEL, ARG0 ];

    my $mess = "CircuitAgent->transfer_task";

    # Needed since we're calling this subroutine directly instead of passing through POE
    my @superArgs; @superArgs[KERNEL, ARG0] = ($kernel, $taskid); shift @superArgs;

    $self->SUPER::finish_task(@superArgs);

    my $task = $self->getTask($taskid);

    return unless defined $task && defined $task->{CIRCUIT};

    $self->Logmsg("xstats circuit details:"
             ." circuit-link=$task->{CIRCUIT_LINK}"
             ." circuit-from-IP=$task->{IP_A}"
             ." circuit-to-IP=$task->{IP_B}");

    if ($task->{REPORT_CODE} != 0 || $task->{XFER_CODE} != 0) {

        # Make sure that the circuit has not expired yet
        my $circuit = $self->{CIRCUIT_MANAGER}->checkCircuit($task->{FROM_NODE},  $task->{TO_NODE}, STATUS_ONLINE);
        return 1 unless defined $circuit;

        my $linkName = $circuit->getLinkName();

        $self->Logmsg("$mess: Transfer failed on $linkName");

        $self->{CIRCUIT_MANAGER}->transferFailed($circuit, $task);
    }

    # Indicate success.
    return 1;
}

# Same as the method that's overriding, but also stops the circuit manager
sub stop
{
    my ($self) = @_;

    $self->Logmsg("CircuitAgent->stop: Letting parent stop its own stuff") if ($self->{VERBOSE});
    # Let the parent stop everything that it's in charge of
    $self->SUPER::stop();

    $self->Logmsg("CircuitAgent->stop: Propagating stop message to CircuitManager as well") if ($self->{VERBOSE});
    # Then attempt to clean all circuits
    $self->{CIRCUIT_MANAGER}->teardownAll();
}

1;