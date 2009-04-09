package PHEDEX::Transfer::Command;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Core';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use POE;
use Getopt::Long;

# General transfer back end for making file copies with a simple
# command taking one pair of source and destination file names.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{COMMAND}     ||= undef;        # Transfer command
    $params->{NJOBS}       ||= 1;            # Max number of parallel transfers
    $params->{BATCH_FILES} ||= 1;            # Max number of files per batch
    $params->{TIMEOUT}     ||= 3600;         # Maximum execution time
	
    # Set argument parsing at this level.
    $options->{'command=s'} = sub { $params->{COMMAND} = [ split(/,/, $_[1]) ] };
    $options->{'timeout=i'} = \$params->{TIMEOUT};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);

    # Create a JobManager
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
						NJOBS	=> $self->{NJOBS},
						VERBOSE	=> $self->{VERBOSE},
						DEBUG	=> $self->{DEBUG},
							);

    # Handle signals
    $SIG{INT} = $SIG{TERM} = sub { $self->{SIGNALLED} = shift;
				   $self->{JOBMANAGER}->killAllJobs() };

    bless $self, $class;
    return $self;
}

sub setup_callbacks
{
    my ($self, $kernel, $session) = @_;
    $kernel->state('cmd_job_done', $self);
}

sub start_transfer_job
{
    my ( $self, $kernel, $session, $jobid ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};
    my $now = &mytimeofday();

    foreach my $task (values %{$job->{TASKS}})
    {
	my $taskid = $task->{TASKID};
	$self->{JOBMANAGER}->addJob( $session->postback('cmd_job_done'),
				     { TIMEOUT => $self->{TIMEOUT},
				       LOGFILE => "$job->{DIR}/T${taskid}-xfer-log",
				       START => $now, TASKID => $taskid },
				     @{$self->{COMMAND}}, $task->{FROM_PFN}, $task->{TO_PFN} );
    }
    $job->{STARTED} = $now;
}

sub cmd_job_done
{
    my ($self, $kernel, $context, $args) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my ($jobinfo) = @$args;

    my $log = &input($jobinfo->{LOGFILE});

    my $taskid = $jobinfo->{TASKID};

    my $xferinfo = { START => $jobinfo->{START}, 
		     END => &mytimeofday(),
		     STATUS => $jobinfo->{STATUS},
		     DETAIL => "",
		     LOG => $log };

    $self->report_detail($jobinfo, $xferinfo);
    $kernel->yield('transfer_done', $taskid, $xferinfo);
}

sub report_detail
{
    my ($self, $jobinfo, $xferinfo) = @_;

    # FIXME:  put special STATUS codes in PHEDEX::Error::Constants
    if (defined $self->{SIGNALLED})
    {
	# We got a signal.
	$xferinfo->{STATUS} = -6;
	$xferinfo->{DETAIL} = "agent was terminated with signal $self->{SIGNALLED}";
    }
    elsif ($jobinfo->{SIGNAL} && !$jobinfo->{TIMED_OUT})
    {
	# We got a signal.
	$xferinfo->{STATUS} = -4;
	$xferinfo->{DETAIL} = "transfer was terminated with signal $jobinfo->{SIGNAL}";
    }
    elsif ($jobinfo->{TIMED_OUT})
    {
	# The transfer timed out.
	$xferinfo->{STATUS} = -5;
	$xferinfo->{DETAIL} = "transfer timed out after $jobinfo->{TIMEOUT}"
	    . " seconds with signal $jobinfo->{SIGNAL}";
    }
}


1;
