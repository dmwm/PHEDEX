package PHEDEX::Transfer::SRM;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Command';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use POE;
use Getopt::Long;

# Command back end defaulting to srmcp and supporting batch transfers.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;
    
    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'srmv2', 'srm' ];  # Accepted protocols
    $params->{COMMAND}     ||= [ 'srmcp' ];  # Transfer command
    $params->{BATCH_FILES} ||= 10;           # Max number of files per batch
    $params->{NJOBS}       ||= 30;           # Max number of parallel commands
	
    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

sub setup_callbacks
{
    my ($self, $kernel, $session) = @_;
    $kernel->state('srm_job_done', $self);
}

# Transfer a batch of files.
sub start_transfer_job
{
    my ( $self, $kernel, $session, $jobid ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};

    # Prepare copyjob and report names.
    my $spec = "$job->{DIR}/copyjob";
    my $report = "$job->{DIR}/srm-report";

    # Now generate copyjob
    &output ($spec, join ("", map { "$_->{FROM_PFN} ".
		                    "$_->{TO_PFN}\n" }
		          values %{$job->{TASKS}}));

    $self->{JOBMANAGER}->addJob( $session->postback('srm_job_done'),
				 { TIMEOUT => $self->{TIMEOUT},
				   LOGFILE => "$job->{DIR}/log",
				   START => &mytimeofday(), JOBID => $jobid },
				 @{$self->{COMMAND}}, "-copyjobfile=$spec", "-report=$report");

    $job->{STARTED} = &mytimeofday();
}

sub srm_job_done
{
    my ($self, $kernel, $context, $args) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my ($jobinfo) = @$args;
    my $jobid = $jobinfo->{JOBID};
    my $job = $self->{JOBS}->{$jobid};
    my $log = &input($jobinfo->{LOGFILE});
    my $now = &mytimeofday();

    # If we have a SRM transfer report, read that in now.
    my %taskstatus = ();
    if (-s "$job->{DIR}/srm-report")
    {
	# Read in the report.
	my %reported;
	foreach (split (/\n/, &input("$job->{DIR}/srm-report") || ''))
	{
	    my ($from, $to, $status, @rest) = split(/\s+/);
	    $reported{$from}{$to} = [ $status, "@rest" ];
	}

	# Read in tasks and correlate with report.
	foreach my $task (values %{$job->{TASKS}})
	{
	    next if ! $task;
	    
	    my ($from, $to) = @$task{"FROM_PFN", "TO_PFN"};
	    $taskstatus{$task->{TASKID}} = $reported{$from}{$to};
	}
    }

    # Report completion for each task
    foreach my $task (values %{$job->{TASKS}}) {
	next if ! $task;
	my $taskid = $task->{TASKID};

	my $xferinfo = { START => $jobinfo->{START}, 
			 END => $now,
			 STATUS => $jobinfo->{STATUS},
			 DETAIL => "",
			 LOG => $log };
	
	if ($taskstatus{$taskid}) {
	    # We have an SRM report entry, use that.
	    ($xferinfo->{STATUS}, $xferinfo->{DETAIL}) = @{$taskstatus{$taskid}};
	} else {
	    # Use the default Command results
	    $self->report_detail($jobinfo, $xferinfo);
	}
	$kernel->yield('transfer_done', $taskid, $xferinfo);
    }
}

1;
