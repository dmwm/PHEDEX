package UtilsJobManager; use strict; use warnings; use base 'Exporter';
use POSIX;
use UtilsLogging;
use UtilsCommand;
use IO::Pipe;
use Fcntl;

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
    my $jobs = $$self{JOBS};

    push (@$jobs, $job)
        if ! $$job{DETACHED};
    $self->startJob($job)
	if ($$job{DETACHED}
	    || (scalar @cmd
		&& scalar (grep ($$_{PID} > 0 && ! $$_{DETACHED}, @$jobs))
		   < $$self{NJOBS}));
}

# Actually fork and execute a subcommand.  Updates the job object to
# have the process id of the subprocess.  Internal helper routine.
sub startJob
{
    my ($self, $job) = @_;
    my $pid = undef;

    $$job{PIPE} = new IO::Pipe;
    
    while (1)
    {
        last if defined ($pid = fork ());
        print STDERR "cannot fork: $!; trying again in 5 seconds\n";
        sleep (5);
    }

    if ($pid)
    {
	# Parent, record this child process
	$$job{PIPE}->reader();
	fcntl(\*{$$job{PIPE}}, F_SETFL, O_NONBLOCK);
	$$job{PID} = $pid;
	$$job{STARTED} = time();
	$$job{BEGINLINE} = 1;
	# open log file for that child
	$$job{CMDNAME} = $$job{CMD}[0];
	$$job{CMDNAME} =~ s|.*/||;

	if (exists $$job{LOGFILE})
	{
	    $$job{LOGPREFIX} = 1;
	    open($$job{LOGFH}, '>>', $$job{LOGFILE})
		or die "Couldn't open log file $$job{LOGFILE}: $!";
	    my $logfh = \*{$$job{LOGFH}};
	    my $oldfh = select($logfh); local $| = 1; select($oldfh);
	    print $logfh
		(strftime ("%Y-%m-%d %H:%M:%S", gmtime),
	         " $$job{CMDNAME}($$job{PID}): Executing: @{$$job{CMD}}\n");
	} 
	else
	{
	    open($$job{LOGFH}, '>&', \*STDOUT);
	}
    }
    else
    {
	# Child, execute the requested program
	setpgrp(0,$$);
	$$job{PIPE}->writer();
	# Redirect STDOUT and STDERR of requested program to a pipe
	open(STDOUT, '>>&', $$job{PIPE});
	open(STDERR, '>>&', $$job{PIPE});
	do {
	   print STDERR "Cannot start @{$$job{CMD}}: $!\n";
	   exit(255);
	} if ! exec { $$job{CMD}[0] } @{$$job{CMD}};
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
    my $now = time();

    foreach my $job (@{$$self{JOBS}})
    {
	if (! scalar @{$$job{CMD}})
	{
	    # Delayed action callback, no job associated with this one
	    push (@finished, $job);
	}
	elsif ($$job{PID} > 0 && waitpid ($$job{PID}, WNOHANG) > 0)
	{
	    # Command finished executing, save exit code and mark finished.
	    # Read the piped log info a last time.
	    # Finally close the file handles.
	    $$job{STATUS_CODE} = $?;
	    $$job{STATUS} = &runerror ($?);
	    readPipe($job);
	    $$job{PIPE}->close();

	    if (exists $$job{LOGFILE})
	    {
	        my $logfh = \*{$$job{LOGFH}};
	        print $logfh
		    (strftime ("%Y-%m-%d %H:%M:%S", gmtime),
	             " $$job{CMDNAME}($$job{PID}): Job exited with status code",
		     " $$job{STATUS} ($$job{STATUS_CODE})\n");
	    }
	    close($$job{LOGFH});
	    push (@finished, $job);
	}
	elsif ($$job{PID} > 0
	       && ! $$job{DETACHED}
	       && $$job{TIMEOUT}
	       && ($now - $$job{STARTED}) > $$job{TIMEOUT})
	{
	    # Command has taken too long to execute, so we need to stop it and its
	    # children. Normally it would be polite to SIGINT the parent process first
	    # and let it INT its children. However, this is something of a hack
	    # because some transfer tools are badly behaved (their children ignore 
	    # their elders). So- instead we just address the whole process group.
	    my %signals = ( 0 => [1,-$$job{PID}],
			    1 => [15,-$$job{PID}],
			    15 => [9,-$$job{PID}],
			    9 => [9,-$$job{PID}] );

	    # Now set signal if not set, send the signal, increase the timeout to give
	    # the parent time to react, and move to next signal
	    $$job{SIGNAL} ||= 0;
	    kill(@{$signals{$$job{SIGNAL}}});
	    $$job{TIMEOUT} += ($$job{TIMEOUT_GRACE} || 15);
	    if ($$job{SIGNAL} != 9) 
	    {
		$$job{SIGNAL} = $signals{$$job{SIGNAL}}[0];
	    }
	    else
	    {
		&alert("Job $$job{PID} not responding to requests to quit");
	    }

	    push(@pending, $job);
	}
	elsif ($$job{PID} > 0)
	{
	    readPipe($job);
	    push(@pending, $job);
	}
	else
	{
	    # Still pending
	    push(@pending, $job);
	}
    }

    $$self{JOBS} = \@pending;
    return @finished;
}

# Read log information from pipe and store it in logfile
sub readPipe
{   
    my ($job) = @_;
    
    # Max amount of bytes to read per read attempt
    my $maxbytes = 4096;

    # Helper variables
    my $pipefhtmp = \*{$$job{PIPE}};
    my $logfhtmp = \*{$$job{LOGFH}};
    my $pipestring = undef;
    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
    my $bytesread = 0;
    while (1)
    {
	# Read pipe output and insert our header at each line break
	$bytesread = sysread($pipefhtmp, $pipestring, $maxbytes);
	last if (!defined $bytesread);
	do { print $logfhtmp ("\n") if ! $$job{BEGINLINE}; last }
	    if ! $bytesread;

	my $line = undef;
	my @lines = split(/\n/, $pipestring, -1);
	while (@lines)
	{
	    $line = shift (@lines);
	    if ($$job{BEGINLINE} && ($line ne "" || @lines))
	    {
	        print $logfhtmp ("$date $$job{CMDNAME}($$job{PID}): ")
		    if $$job{LOGPREFIX};
		$$job{BEGINLINE} = 0;
	    }
	    print $logfhtmp ($line);
	    if (@lines)
	    {
		print $logfhtmp ("\n");
		$$job{BEGINLINE} = 1;
	    }
	}
    }
}

# Send a signal to all generated process groups?
sub killAllJobs
{
    my ($self) = @_;
    while (@{$$self{JOBS}})
    {
	# While there are jobs to run, mark them timed out,
	# then wait job processing to terminate all those.
	my $now = time();
	foreach (@{$$self{JOBS}})
	{
	    next if ! $$_{STARTED} || $$_{KILLING} || $$_{DETACHED};
	    $$_{TIMEOUT} = $now - $$_{STARTED} - 1;
	    $$_{TIMEOUT_GRACE} = 30;
	    $$_{KILLING} = 1;
	}
	$self->pumpJobs();
	select (undef, undef, undef, 0.1);
    }
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
	next if $$job{DETACHED};
	&{$$job{ACTION}} ($job);
    }

    # Start new jobs if possible
    my $jobs = $$self{JOBS};
    my $running = grep ($$_{PID} > 0 && ! $$_{DETACHED}, @$jobs);
    foreach my $job (@$jobs)
    {
	next if ! @{$$job{CMD}};
	next if $$job{PID} > 0;
	last if $running >= $$self{NJOBS};
	$self->startJob ($job);
	$running++;
    }
}

1;
