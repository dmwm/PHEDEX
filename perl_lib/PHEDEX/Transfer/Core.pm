package PHEDEX::Transfer::Core;
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Command;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Timing;
use POE;
use Getopt::Long;
use File::Path qw(mkpath);
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
    $params->{PROTOCOLS}   ||= undef;        # Transfer command
    $params->{NJOBS}       ||= 0;            # Max number of parallel transfers.  0 for infinite.
    $params->{BATCH_FILES} ||= 1;            # Max number of files per batch
    $params->{CATALOGUES} = {};

    # Set argument parsing at this level.
    $$options{'protocols=s'} = sub { $$params{PROTOCOLS} = [ split(/,/, $_[1]) ]};
    $$options{'jobs=i'} = \$$params{NJOBS};

    # Parse additional options
    local @ARGV = @{$master->{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default);
    &GetOptions (%$options);

    # Initialise myself
    my $self = $class->SUPER::new();
    $self->{$_} = $params->{$_} for keys %$params;
    bless $self, $class;

    # Create a JobManager
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
						NJOBS	=> $self->{NJOBS},
						VERBOSE	=> $self->{VERBOSE},
						DEBUG	=> $self->{DEBUG},
							);
    $self->{JOBS} = {};  # Transfer jobs

    # Remember various useful details.
    $self->{MASTER} = $master;  # My owner
    $self->{VERBOSE} = $master->{VERBOSE} || 0;
    $self->{DEBUG} = $master->{DEBUG} || 0;
    $self->{BOOTTIME} = time(); # "Boot" time for this agent
    $self->{BATCHID} = 0;       # Running batch counter
    $self->{WORKDIR} = $master->{WORKDIR}; # Where job state/logs are saved
    $self->{ARCHIVEDIR} = $master->{ARCHIVEDIR}; # Where job state/logs are archived when finished

    # Locate the transfer wrapper script.
    $self->{WRAPPER} = $INC{"PHEDEX/Transfer/Core.pm"};
    $self->{WRAPPER} =~ s|/PHEDEX/Transfer/Core\.pm$|/../Toolkit/Transfer/TransferWrapper|;
    -x "$self->{WRAPPER}"
        || die "Failed to locate transfer wrapper, tried $$self{WRAPPER}\n";

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

# Check if the backend is busy.  By default, true if the number of
# currently set up copy jobs is equal or exceeds the number of jobs
# the back end can run concurrently.
sub isBusy
{
    my ($self, $to_node, $from_node) = @_;
    return 0 if $self->{NJOBS} == 0;
    return scalar keys %{$self->{JOBS}} >= $self->{NJOBS};
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

    my @batch = splice(@$tasklist, 0, $self->{BATCH_FILES});
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

    my ($n_pend, $n_ready, $n_done, $n_lost) = (0,0,0,0);
    foreach my $taskid (keys %{$job->{TASKS}}) {
	my $task = $job->{TASKS}->{$taskid};
	if    (!$task)            { $n_lost++; delete $job->{TASKS}->{$taskid}   }
	elsif ($task->{FINISHED}) { $n_done++; delete $job->{TASKS}->{$taskid};  }
	elsif ($task->{READY})    { $n_ready++ }
	else                      { $n_pend++  }
    }

    $self->Logmsg("copy job $jobid status:  pend=$n_pend ready=$n_ready done=$n_done lost=$n_lost ") 
	if $self->{DEBUG};

    if ($n_pend == 0 && $n_ready == 0) {
	$kernel->yield('finish_transfer_job', $jobid);
	return; # do not check this job anymore
    } elsif ($n_pend == 0 && !$job->{STARTED}) {
	$job->{STARTED} = &mytimeofday();
	$self->saveJob($job);
	$kernel->yield('start_transfer_job', $jobid);
    }

    $kernel->delay_set('check_transfer_job', 15, $jobid);
}

# Start a transfer job.  This needs to be implemented by a sub-class
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
