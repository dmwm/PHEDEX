package PHEDEX::Transfer::SRM;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Command';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use POE;
use Getopt::Long;

# Command back end defaulting to srmcp and supporting batch transfers.
# SRM spec:  
#  http://sdm.lbl.gov/srm-wg/doc/SRM.v2.2.html
# srmcp command syntax(es):
# dcache:
#  https://twiki.grid.iu.edu/bin/view/Documentation/StorageSrmcpUsing
# bestman:
#  http://datagrid.lbl.gov/bestman/srmclient/srm-copy.html

sub new
{
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $master = shift;
    
    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params  = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'srmv2', 'srm' ];  # Accepted protocols
    $params->{COMMAND}     ||= [ 'srmcp' ];  # Transfer command
    $params->{BATCH_FILES} ||= 10;           # Max number of files per batch
    $params->{NJOBS}       ||= 30;           # Max number of parallel commands
    $params->{SYNTAX}      ||= "dcache";     # SRM command flavor

    # Set argument parsing at this level.
    $options->{'syntax=s'} = \$params->{SYNTAX};
	
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
    my @tasks = values %{$job->{TASKS}};
    my $syntax = $self->{SYNTAX};

    # Prepare copyjob and report names.
    my $spec = "$job->{DIR}/copyjob";
    my $report = "$job->{DIR}/srm-report";

    # Now generate copyjob
    $self->writeSpec($spec, @tasks);

    # Prepare the command
    my @command = (@{$self->{COMMAND}}, $self->makeArgs($spec, $report));

    # Queue the command
    $self->{JOBMANAGER}->addJob( $session->postback('srm_job_done'),
				 { TIMEOUT => $self->{TIMEOUT},
				   LOGFILE => "$job->{DIR}/log",
				   START => &mytimeofday(), JOBID => $jobid },
                                 @command );


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

# The following functions prepare files and command line arguments for
# an SRM command depending on the syntax.

sub writeSpec
{
    my ($self, $spec, @tasks) = @_;
    my $syntax = $self->{SYNTAX};

    my $rv = 0;
    if ($syntax eq 'dcache') {
	$rv = &output ($spec, join ("\n", map { "$_->{FROM_PFN} $_->{TO_PFN}" } @tasks));
    } elsif ($syntax eq 'bestman') {
	$rv = &output ($spec, 
		 join ("\n", 
		       "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		       "<request>",
		       (map { "  <file>".
			      "    <sourceurl>$_->{FROM_PFN}</sourceurl>".
			      "    <targeturl>$_->{TO_PFN}</targeturl>".
			      "  </file>" } @tasks),
		       "</request>\n"));
    } else {
	$self->Fatal("writeSpec: unknown syntax '$syntax'");
    }
    return $rv;
}

sub makeArgs
{
    my ($self, $spec, $report) = @_;
    my $syntax = $self->{SYNTAX};
    
    if ($syntax eq 'dcache') {
	return ("-copyjobfile=$spec", "-report=$report");
    } elsif ($syntax eq 'bestman')  {
	return ("-f $spec", "-report $report", "-xmlreport $report.xml");
    } else {
	$self->Fatal("makeArgs:  unknown syntax '$syntax'");
    }
}

1;
