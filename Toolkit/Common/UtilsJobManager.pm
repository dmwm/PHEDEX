package UtilsJobManager; use strict; use warnings; use base 'Exporter';
use POSIX;
use UtilsLogging;

######################################################################
# JOB MANAGEMENT TOOLS

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);
    my $self = { NJOBS => $args{NJOBS} || 1, JOBS => [] };
    bless $self, $class;
    return $self;
}

# Add a new command to the job list.  The command will only be started
# if the current limit of available job slots is not exceeded; otherwise
# the job simply gets added to the list of processes to start later on.
# If the command list is empty, the job represents a delayed action to
# be invoked on the next "pumpJobs".
sub addJob
{
    my ($self, $action, $jobargs, @cmd) = @_;
    my $job = { PID => 0, ACTION => $action, CMD => [ @cmd ], %{$jobargs || {}} };
    my $jobs = $self->{JOBS};
    push (@$jobs, $job);

    $self->startJob($job)
        if (scalar @cmd && scalar (grep ($_->{PID} > 0, @$jobs)) < $self->{NJOBS});
}

# Actually fork and execute a subcommand.  Updates the job object to
# have the process id of the subprocess.  Internal helper routine.
sub startJob
{
    my ($self, $job) = @_;
    my $pid = undef;
    while (1)
    {
        last if defined ($pid = fork ());
        print STDERR "cannot fork: $!; trying again in 5 seconds\n";
        sleep (5);
    }

    if ($pid)
    {
	# Parent, record this child process
	$job->{PID} = $pid;
	$job->{STARTED} = time();
	&logmsg( "P:START [$job->{PID}:] @{$job->{CMD}}" ) if ( $ENV{'PHEDEX_PROCESS_LOG'} == 1 );
    }
    else
    {
	# Child, execute the requested program
        exec { $job->{CMD}[0] } @{$job->{CMD}};
        die "Cannot start @{$job->{CMD}}: $!\n";
    }
}

# Find out which subprocesses have finished and collect them to a list
# returned to the caller.  Finished jobs are removed from JOBS list.
# Internal helper routine.
sub checkJobs
{
    my ($self) = @_;
    my @pending = ();
    my @finished = ();
    my $now = 0;
    foreach my $job (@{$self->{JOBS}})
    {
	my $status;
	if (! scalar @{$job->{CMD}})
	{
	    # Delayed action callback, no job associated with this one
	    push (@finished, $job);
	}
	elsif ($job->{PID} > 0
	       && $job->{TIMEOUT}
	       && ($now - $job->{STARTED}) > $job->{TIMEOUT})
	{
	    # Command has taken too long to execute.  Nuke it.  First time
	    # around use SIGINT.  Next time around use SIGKILL.
	    kill ($job->{PID}, $job->{FORCE_TERMINATE} ||= 1);
	    $job->{FORCE_TERMINATE} = 9;
	    &logmsg( "P:TIMEOUT [$job->{PID}:] @{$job->{CMD}}" ) if ( $ENV{'PHEDEX_PROCESS_LOG'} == 1 );
	}
	elsif ($job->{PID} > 0 && waitpid ($job->{PID}, WNOHANG) > 0)
	{
	    # Command finished executing, save exit code and mark finished
	    if ( WIFSIGNALED($?) ) {
		&logmsg( "P:SIGNAL [$job->{PID}:$?] @{$job->{CMD}}" ) if ( $ENV{'PHEDEX_PROCESS_LOG'} == 1 );
	    } elsif ( WIFEXITED($?) )
	    {
		&logmsg( "P:EXIT [$job->{PID}:$?] @{$job->{CMD}}" ) if ( $ENV{'PHEDEX_PROCESS_LOG'} == 1 );
	    }
	    $job->{STATUS} = $? / 256;
	    push (@finished, $job);
	}
	else
	{
	    # Still pending
	    push(@pending, $job);
	}
    }

    $self->{JOBS} = \@pending;
    return @finished;
}

# Invoke actions on completed subprocesses and start new jobs if there
# are free slots.  Invoke this every once in a while to keep processes
# going.
sub pumpJobs
{
    my ($self) = @_;
    
    # Invoke actions on completed jobs
    foreach my $job ($self->checkJobs())
    {
	&{$job->{ACTION}} ($job);
    }

    # Start new jobs if possible
    my $jobs = $self->{JOBS};
    my $running = grep ($_->{PID} > 0, @$jobs);
    foreach my $job (@$jobs)
    {
	next if ! @{$job->{CMD}};
	next if $job->{PID} > 0;
	last if $running >= $self->{NJOBS};
	$self->startJob ($job);
	$running++;
    }
}

1;
