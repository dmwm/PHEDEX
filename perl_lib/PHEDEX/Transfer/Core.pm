package PHEDEX::Transfer::Core;
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use PHEDEX::Core::Command;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Timing;
use POE;
use Getopt::Long;
use File::Path qw(mkpath rmtree);
use Data::Dumper;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}           ||= undef;  # Transfer protocols
    $params->{NJOBS}               ||= 0;      # Max number of parallel jobs.  0 for infinite.
    $params->{BATCH_FILES}         ||= 1;      # Max number of files per batch
    $params->{MAX_ACTIVE}          ||= 0;      # Max number of parallel files.  0 for infinite
    $params->{DEFAULT_LINK_ACTIVE} ||= 0;      # Default max per-link files. 0 for infinite.
    $params->{LINK_ACTIVE}         ||= {};     # Max per-link files.  undef links are infinite.
    $params->{LINK_PEND}           ||= 0;      # Max per-link pending files. 0 for infinite.

    # Set argument parsing at this level.
    $options->{'protocols=s'}          = sub { $$params{PROTOCOLS} = [ split(/,/, $_[1]) ]};
    $options->{'jobs=i'}               = \$$params{NJOBS};
    $options->{'batch-files=i'}        = \$params->{BATCH_FILES};
    $options->{'max-active-files=i'}   = \$params->{MAX_ACTIVE};
    $options->{'default-link-active-files=i'} = \$params->{DEFAULT_LINK_ACTIVE};
    $options->{'link-active-files=i'}  =  $params->{LINK_ACTIVE};
    $options->{'link-pending-files=i'} = \$params->{LINK_PEND};

    # Parse additional options
    local @ARGV = @{$master->{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default);
    &GetOptions (%$options);

    # Initialise myself
    my $self = $class->SUPER::new();
    $self->{$_} = $params->{$_} for keys %$params;
    bless $self, $class;

    $self->{JOBS} = {};  # Transfer jobs

    # Remember various useful details.
    $self->{MASTER} = $master;  # My owner
    $self->{VERBOSE} = $master->{VERBOSE} || 0;
    $self->{DEBUG} = $master->{DEBUG} || 0;
    $self->{BOOTTIME} = time(); # "Boot" time for this agent
    $self->{BATCHID} = 0;       # Running batch counter
    $self->{WORKDIR} = $master->{WORKDIR}; # Where job state/logs are saved
    $self->{ARCHIVEDIR} = $master->{ARCHIVEDIR}; # Where job state/logs are archived when finished

    return $self;
}

# Initialize POE events.  We share the session with the frontend.
sub _poe_init
{
    my ($self, $kernel, $session) = @_;

    my @poe_subs = qw( start_batch check_transfer_job
		       start_transfer_job finish_transfer_job manage_archives);
    $kernel->state($_, $self) foreach @poe_subs;

    if ( $self->can('setup_callbacks') ) { 
	$self->setup_callbacks($kernel,$session);
    }

    # Get periodic events going
    $kernel->yield('manage_archives');
}

# Stop the backend.  We abandon all jobs always.
sub stop
{
    # my ($self) = @_;
}

# Check if the backend is busy.  Without $from, $to arguments, checks
# whether the backend is busy in general.  With $from, $to arguments,
# checks whether the backend is busy for the link $from -> $to
sub isBusy
{
    my ($self, $from, $to) = @_;

    # return busy if we are beyond the maximum number of concurrent jobs
    if ($self->{NJOBS} && scalar keys %{$self->{JOBS}} >= $self->{NJOBS}) {
	$self->Logmsg("backend busy: maximum active jobs ($self->{NJOBS}) reached") if $self->{VERBOSE};
	return 1;
    }

    # compute per link task statistics
    my %linkstats; my %pendstats; my $total = 0;
    foreach my $job (values %{$self->{JOBS}}) {
	foreach my $task (values %{$job->{TASKS}}) {
	    next if !defined $task;
	    my $linkkey = "$task->{FROM_NODE} -> $task->{TO_NODE}";
	    if (!$task->{FINISHED}) {
		($linkstats{$linkkey} ||= 0)++;
		($pendstats{$linkkey} ||= 0)++ if !$job->{STARTED};
		$total++;
	    }
	}
    }

    # return busy if we are beyond the maximum number of concurrent files
    if ( $self->{MAX_ACTIVE} && $total >= $self->{MAX_ACTIVE} ) { 
	$self->Logmsg("backend busy: maximum active files ($self->{MAX_ACTIVE}) reached") if $self->{VERBOSE};
	return 1;
    }

    # per link busy status
    if (defined $from && defined $to) {
	my $linkkey = "$from -> $to";
	if ($self->{LINK_ACTIVE}->{$from} || $self->{DEFAULT_LINK_ACTIVE}) {
	    my $n_link = $linkstats{$linkkey} || 0;
	    my $limit;
	    $limit = $self->{DEFAULT_LINK_ACTIVE} if $self->{DEFAULT_LINK_ACTIVE};
	    $limit = $self->{LINK_ACTIVE}->{$from} if $self->{LINK_ACTIVE}->{$from};
	    
	    if ( $n_link >= $limit ) { 
		$self->Logmsg("backend busy: maximum link active files for $linkkey ($limit) reached\n") 
		    if $self->{VERBOSE};
		return 1;
	    }
	}
	
	if ($self->{LINK_PEND}) {
	    my $n_pend = $pendstats{$linkkey} || 0;
	    my $limit = $self->{LINK_PEND};
	    if ( $n_pend >= $limit ) { 
		$self->Logmsg("backend busy: maximum link pending files for $linkkey ($limit) reached\n") 
		    if $self->{VERBOSE};
		return 1;
	    }
	}
    }

    # I guess we're not busy
    return 0;
}

# Return the list of protocols supported by this backend.
sub protocols
{
    my ($self) = @_;
    return @{$self->{PROTOCOLS}};
}

# Define a transfer batch by removing BATCH_FILES tasks from
# $tasklist.  Then prepares the job work area and saves state.
# Finally, calls 'check_jobs' to begin looking for when it is OK to
# begin the job.
sub start_batch
{
    my ($self, $kernel, $tasklist) = @_[ OBJECT, KERNEL, ARG0 ];

    # Peek at the first task to determine the link we are filling
    # WARNING: This makes an assumption about how FileDownload will
    #          give tasks to the backend!
    my ($from, $to) = ($tasklist->[0]->{FROM_NODE}, $tasklist->[0]->{TO_NODE});

    # Determine the size of a job. The order of preference is:
    #  1. -link-active-files limit, 2. -default-link-active-files 3. -batch-files
    my $job_size;
    if ( $self->{LINK_ACTIVE}->{$from} ) {
	$job_size = $self->{LINK_ACTIVE}->{$from};
    } elsif ( $self->{DEFAULT_LINK_ACTIVE} ) {
	$job_size = $self->{DEFAULT_LINK_ACTIVE};
    } else {
	$job_size = $self->{BATCH_FILES};
    }

    # Set the job size to MAX_ACTIVE files if it is more limiting
    if ($self->{MAX_ACTIVE} && $self->{MAX_ACTIVE} < $job_size) {
	$job_size = $self->{FTS_MAX_ACTIVE};
    }

    my @batch = splice(@$tasklist, 0, $job_size);
    return undef if !@batch;

    my $id = $$self{BATCH_ID}++;
    my $jobid = "job.$$self{BOOTTIME}.$id";
    my $jobdir = "$$self{WORKDIR}/$jobid";
    &mkpath($jobdir);
    my $job = { ID => $jobid, DIR => $jobdir,
		TASKS => { map { $_->{TASKID} => $_ } @batch } };
    $self->saveJob($job);
    $self->{JOBS}->{$jobid} = $job;
    $kernel->yield('check_transfer_job', $jobid);
    return ($jobid, $jobdir, $job->{TASKS});
}

# Check to see if a job is ready to start.  Tasks in a job can
# disappear or be finished as a result of frontend actions, this looks
# to see if all of the existing unfinished tasks in the job have been
# marked ready for transfer by the frontend.  If they have, the job
# can be started.
sub check_transfer_job
{
    my ($self, $kernel, $jobid) = @_[ OBJECT, KERNEL, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};

    # FIXME: this algorithm leaves the state file empty at the end of
    # the job.  We should keep a log of which tasks a job
    # started with/finished
    my ($n_pend, $n_ready, $n_done, $n_lost) = (0,0,0,0);
    foreach my $taskid (keys %{$job->{TASKS}}) {
	my $task = $job->{TASKS}->{$taskid};
	if    (!$task)            { $n_lost++; delete $job->{TASKS}->{$taskid}   }
	elsif ($task->{FINISHED}) { $n_done++; delete $job->{TASKS}->{$taskid};  }
	elsif ($task->{READY})    { $n_ready++ }
	else                      { $n_pend++  }
    }

    $self->Dbgmsg("copy job $jobid status:  pend=$n_pend ready=$n_ready done=$n_done lost=$n_lost ") 
	if $self->{DEBUG};

    if ($n_pend == 0 && $n_ready == 0) {
	$self->Dbgmsg("finish copy job $jobid") if $self->{DEBUG};
	$kernel->yield('finish_transfer_job', $jobid);
	return; # do not check this job anymore
    } elsif ($n_pend == 0 && !$job->{ASKSTART}) {
	$job->{ASKSTART} = &mytimeofday();
	$self->saveJob($job);
	$self->Dbgmsg("start copy job $jobid") if $self->{DEBUG};
	$kernel->yield('start_transfer_job', $jobid);
    }

    $kernel->delay_set('check_transfer_job', 15, $jobid);
}

# Start a transfer job.  This needs to be implemented by a sub-class.
# The required behavior is to set $job->{STARTED} timestamp when the
# job has actually started, and to trigger the 'transfer_done' event
# for each file when the transfer is finished
sub start_transfer_job
{
    my ($self, $kernel, $jobid) = @_[ OBJECT, KERNEL, ARG0 ];
    $self->Fatal("start_transfer_job not implemented by transfer backend ", __PACKAGE__);
}

# Called to finish a transfer job.  Marks the time the job was
# finished, then cleans the job from memory and moves the state
# information to the archive area
sub finish_transfer_job
{
   my ($self, $kernel, $jobid) = @_[ OBJECT, KERNEL, ARG0 ];

   my $job = $self->{JOBS}->{$jobid};
   
   $job->{ASKSTART} ||= -1;
   $job->{STARTED}  ||= -1;
   $job->{FINISHED} = &mytimeofday();
   $self->saveJob($job);
   delete $self->{JOBS}->{$jobid};
   &mv($job->{DIR}, "$$self{ARCHIVEDIR}/$jobid");

   $self->Logmsg("copy job $jobid completed") if $$self{VERBOSE};
}

# Save a job to disk
sub saveJob
{
    my ($self, $job) = @_;
    &output("$job->{DIR}/info", Dumper($job));    
}

# Remove archived jobs which are over a day old, or if there are more
# than 500 of them
sub manage_archives
{
   my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
   $kernel->delay('manage_archives', 3600);

   my $archivedir = $$self{ARCHIVEDIR};
   my @old = <$archivedir/*>;
   my $now = &mytimeofday();
   &rmtree($_) for (scalar @old > 500 ? @old 
		    : grep((stat($_))[9] < $now - 86400, @old));
}


1;
