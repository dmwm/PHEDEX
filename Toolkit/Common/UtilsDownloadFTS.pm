package UtilsDownloadFTS; use strict; use warnings; use base 'UtilsDownload';
use UtilsCommand;
use Getopt::Long;
# DO NOT USE - UNFINISHED!!
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
	$$params{PROTOCOLS}   ||= [ 'srm' ];    # Accepted protocols
	#$$params{COMMAND}     ||= [ 'srmcp' ]; # Transfer command
	$$params{BATCH_FILES} ||= 25;           # Max number of files per batch
	$$params{LINK_FILES}  ||= 250;          # Queue this number of files in FTS for a link 
	
	# Set argument parsing at this level.
	$$options{'batch-files=i'} = \$$params{BATCH_FILES};
	$$options{'link-files=i'} = \$$params{LINK_FILES};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $job, $tasks) = @_;

    # Prepare copyjob and report names.
    my $spec = "$$job{DIR}/copyjob";
    my $report = "$$job{DIR}/fts-report";

    # Now generate copyjob
    &output ($spec, join ("", map { "$$tasks{$_}{FROM_PFN} ".
		                    "$$tasks{$_}{TO_PFN}\n" }
		          keys %{$$job{TASKS}}));

    # Fork off the transfer wrapper
    $self->addJob(undef, { DETACHED => 1 },
		  $$self{WRAPPER}, $$job{DIR}, $$self{TIMEOUT},
		  @{$$self{COMMAND}}, "-copyjobfile=$spec", "-report=$report");
}

# Check whether a job is alive.
#
# This periodically checks every FTS copy job for current transfer
# status, and "reaps" the tasks that have reached FTS "end state".
#
# We avoid checking on jobs excessively frequently as the front-end
# agent calls this routine up to every 15 seconds.  Each copy job
# maintains a marker file that marks the time we should next poll 
# the job status.
#
# Once an individual file has reached an end state, we create the
# T<TASKID>X file for the task with all the information about the
# transfer for that task.  The front-end agent will automatically
# reap those transfers, and once all transfers for the job have
# completed, it will automatically clean up the whole copy job.
#
# If the check reveals that transfer state has transitioned from 
# Pending to Active the timeout should be reset to 0, so as to avoid
# cutting off active transfers while they are onging. This means a 
# transfer will have an hour to become active, and an hour to complete.
sub check
{
    my ($self, $jobname, $job, $tasks) = @_;
    my $now = time();

    # If we shouldn't yet be checking on this job, bypass it.
    # The next-check flag is set below once we've checked the
    # FTS job status and decided the next time we should be
    # checking on this copy job.
    return if ((stat("$$job{DIR}/next-check"))[9] >= time();
    
    # Check the status of this job.
    $$self{MASTER}->addJob (... qq{
      something to call "RunWithTimeout" glite-transfer-status on the job,
      and to generate a srm-report similar to ftscp generates at the end.
      you'll basically want to find out which jobs have reached "end"
      state.}
      
      qq{Remember to use LOG_FILE for logging output from this, each
      time appeneding the output to the existing log file, so transfer
      log for each task of this job includes the full output of what we
      did.});
    
    # Scan files that have reached end state, and modify the
    # task status accordingly.  Create "$jobdir/T${task}X"
    # files as in TransferWrapper, including the transfer
    # log (logs of all glite-transfer-status calls etc.
    # for this job so far).
    
    &touch("$$job{DIR}/next-check", $now + qq{add time like ftscp does,
    the tricky thing is to remember how much to add each time around,
    probably need to keep a small file in $jobdir to indicate how much
    delay to add so agent stop/start doesn't reset the check interval.});
}

# Check if the backend is busy.  FIXME: it's not entirely obvious
# when the FTS backend is "busy" -- we could always take more work
# for currently unused FTS channels.  One possibility is to make
# "startBatch()" detect the channel is full, then actually not take
# any new files off the queue, and mark $$self{IS_BUSY}=1, and return
# that here.  Then in "check()" we can set that back to not busy once
# we've reaped a job.  The dangerous aspects here are 1) getting this
# to work correctly across agent start/stop, 2) not getting the agent
# "stuck" under any circumstances (i.e., busy but doing nothing, and
# thus no way for it to ever become "unstuck").

# num_files_in_fts < LINK_FILES - BATCH_FILES
sub isBusy
{
    my ($self, $jobs, $tasks) = @_;
    return 0 if ! %$jobs || ! %$tasks;
    return $$self{IS_BUSY};
}

# Start off a copy job.  Nips off "BATCH_FILES" tasks to go ahead.
sub startBatch
{
    # FIXME: If channel would get filled up, stop taking
    # transfer tasks from the queue.  Make sure the front-end
    # agent deals with this situation correctly.
    my ($self, $jobs, $tasks, $dir, $jobname, $list) = @_;
    my @batch = splice(@$list, 0, $$self{BATCH_FILES});
    my $info = { ID => $jobname, DIR => $dir,
	         TASKS => { map { $$_{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($info));
    &touch("$dir/live");
    $$jobs{$jobname} = $info;
    $self->clean($info, $tasks);
}

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $job, $tasks) = @_;

    # Prepare copyjob and report names.
    my $spec = "$$job{DIR}/copyjob";
    my $report = "$$job{DIR}/srm-report";

    # Now generate copyjob for glite-transfer-submit
    &output ($spec, join ("", map { "$$tasks{$_}{FROM_PFN} ".
		                    "$$tasks{$_}{TO_PFN}\n" }
		          keys %{$$job{TASKS}}));

    # Parse source and destination host names from the SURLs.
    # The upstream guarantees every transfer pair in this
    # batch is for the same source/destination host pair.
    my $srchost = ...; #FIXME
    my $desthost = ...; #FIXME

    # Use FTSSelectChannel / static text file to select channels
    # applicable to this host pair.  If the latter, simply generate
    # a static text file per allowed source host, and complain
    # loudly if there is no such file for the source host.  I.e.,
    # make the agent take an option with a directory name, and
    # look for the channel selections in there by source host
    # name?
    my $ftsserver = ...; # FIXME: from channel select output
    # FIXME: Print into logging information in verbose mode:
    #  "Using channel X from server Y for transfer pair A, B;
    #   channel parameters were..., previously seen quality ..."
    
    # Call glite-transfer-submit, save the output GUID into
    # a file in copyjob directory and (error) output into a log file.
    # FIXME
    
    # Mark the next time we should be checking on this job.
    &touch("$$job{DIR}/next-check", time() + 60);  # FIXME: save some indication how to increase this in check()?
    
    # FIXME: copy some meta-state state information initialisation
    # (transfer start, end time, etc.) from TransferWrapper.
}


1;
