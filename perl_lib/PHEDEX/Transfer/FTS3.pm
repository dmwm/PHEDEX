package PHEDEX::Transfer::FTS3; use base 'PHEDEX::Transfer::Core';

use strict;
use warnings;

use Getopt::Long;
use POSIX;
use Data::Dumper;
use JSON::XS;

use PHEDEX::Transfer::Backend::Job;
use PHEDEX::Transfer::Backend::File;
use PHEDEX::Transfer::Backend::Monitor;
use PHEDEX::Transfer::Backend::Interface::FTS3CLIAsync;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Formats;
use PHEDEX::Monalisa;
use POE;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;
    
    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift  || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}           ||= [ 'srmv2', 'davs' ];  # Accepted protocols
    $params->{BATCH_FILES}         ||= 30;         # Max number of files per job
    $params->{NJOBS}               ||= 0;          # Max number of jobs.  0 for infinite.
    $params->{LINK_PEND}           ||= 50;         # Submit to FTS until this number of files per link are "pending"
    $params->{FTS_POLL_QUEUE}      ||= 0;          # Whether to poll all vs. our jobs
    $params->{FTS_Q_INTERVAL}      ||= 30;         # Interval for polling queue for new jobs
    $params->{FTS_J_INTERVAL}      ||= 5;          # Interval for polling individual jobs
    $params->{FTS_OPTIONS}         ||= {};	   # Specific options for fts commands
    $params->{FTS_JOB_AWOL}        ||= 3600;       # Timeout for successful monitoring of a job.  0 for infinite.
    $params->{FTS_CHECKSUM}        ||= 1;          # Enable FTS checksumming (default is yes).
    $params->{FTS_CHECKSUM_TYPE}   ||= 'adler32';  # Type of checksum to use for checksum verification in FTS
    $params->{FTS_USE_JSON}        ||= 1;          # Whether to use json formar or not

    # Set argument parsing at this level.
    $options->{'service=s'}            = \$params->{FTS_SERVICE};
    $options->{'priority=s'}           = \$params->{FTS_PRIORITY};
    $options->{'mapfile=s'}            = \$params->{FTS_MAPFILE};
    $options->{'checksum!'}            = \$params->{FTS_CHECKSUM};
    $options->{'q_interval=i'}         = \$params->{FTS_Q_INTERVAL};
    $options->{'j_interval=i'}         = \$params->{FTS_J_INTERVAL};
    $options->{'poll_queue=i'}         = \$params->{FTS_POLL_QUEUE};
    $options->{'monalisa_host=s'}      = \$params->{FTS_MONALISA_HOST};
    $options->{'monalisa_port=i'}      = \$params->{FTS_MONALISA_PORT};
    $options->{'monalisa_cluster=s'}   = \$params->{FTS_MONALISA_CLUSTER};
    $options->{'monalisa_node=s'}      = \$params->{FTS_MONALISA_NODE};
    $options->{'fts-options=s'}        = $params->{FTS_OPTIONS};
    $options->{'job-awol=i'}           = \$params->{FTS_JOB_AWOL};
    $options->{'use-json!'}            = \$params->{FTS_USE_JSON};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);

    # Create a JobManager
    # Our JobManager is only used to execute the submission and monitoring commands
    # This has nothing to do with $self->{NJOBS}, defined above.  We
    # allow an infinite number of submission and query commands.  They
    # should return quickly, and stalled commands should be killed
    # according to Q_TIMEOUT.
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
						NJOBS	=> 0,
						VERBOSE	=> $self->{VERBOSE},
						DEBUG	=> $self->{DEBUG},
							);

    # Handle signals
    $SIG{INT} = $SIG{TERM} = sub { $self->{SIGNALLED} = shift;
				   $self->{JOBMANAGER}->killAllJobs() };

    bless $self, $class;

    $self->init();
    if ( $self->{DEBUG} >= 2)
    {
      my $dump = Dumper($self);
      my $password = $self->{FTS_Q_MONITOR}{Q_INTERFACE}{PASSWORD};
      $dump =~ s%$password%_censored_%g if $password;
      $self->Dbgmsg('FTS3 $self:  ', $dump) if $self->{DEBUG};
    }
    $self->Dbgmsg('Transfer::FTS3::new creating instance') if $self->{DEBUG};

#   Enhanced debugging!
    PHEDEX::Monitoring::Process::MonitorSize('FTS3',\$self);
    PHEDEX::Monitoring::Process::MonitorSize('QMon',\$self->{FTS_Q_MONITOR});
    PHEDEX::Monitoring::Process::MonitorSize('FTS3CLI',\$self->{FTS_Q_MONITOR}{Q_INTERFACE});
    return $self;
}

sub init
{
    my ($self) = @_;

    my $fts3_client = PHEDEX::Transfer::Backend::Interface::FTS3CLIAsync->new
	(
	 SERVICE => $self->{FTS_SERVICE},
	 OPTIONS => $self->{FTS_OPTIONS},
	 ME      => 'FTS3CLI',
         VERBOSE => $self->{VERBOSE},
         DEBUG   => $self->{DEBUG},
         FTS_USE_JSON => $self->{FTS_USE_JSON},
	 );

    $self->{Q_INTERFACE} = $fts3_client;

    my $monalisa;
    my $use_monalisa = 1;
    foreach (qw(FTS_MONALISA_HOST FTS_MONALISA_PORT FTS_MONALISA_CLUSTER FTS_MONALISA_NODE)) {
	$use_monalisa &&= exists $self->{$_} && defined $self->{$_};
    }

    if ( $use_monalisa )
    {
	$monalisa = PHEDEX::Monalisa->new
	    (
	     Host    => $self->{FTS_MONALISA_HOST}.':'.$self->{FTS_MONALISA_PORT},
	     Cluster => $self->{FTS_MONALISA_CLUSTER},
	     Node    => $self->{FTS_MONALISA_NODE},
	     apmon   => { sys_monitoring => 0,
			  general_info   => 0 }
	     );

	$self->{MONALISA} = $monalisa;
    }

    my $q_mon = PHEDEX::Transfer::Backend::Monitor->new
	(
	 Q_INTERFACE   => $fts3_client,
	 Q_INTERVAL    => $self->{FTS_Q_INTERVAL},
	 J_INTERVAL    => $self->{FTS_J_INTERVAL},
	 POLL_QUEUE    => $self->{FTS_POLL_QUEUE},
	 APMON         => $monalisa,
	 ME            => 'QMon',
	 );

    $self->{FTS_Q_MONITOR} = $q_mon;
    $q_mon->{JOBMANAGER} = $self->{JOBMANAGER};

    $self->parseFTSmap() if ($self->{FTS_MAPFILE});

    # How do we handle task-priorities?
    # If priorities have been specified on the command-line, they should
    # have the syntax 'm1=p1,m2=p2,m3=p3', where p<n> is the task priority
    # from TMDB and m<n> is the priority to map it to. For all p<n> that do
    # not get overridden on the command-line, the priority is taken as given.
    #
    # PhEDEx task priorities are 0-5, high to low. FTS is 1-5, low to high.
    # Map PhEDEx to the mid-range so we have some margin to play with.
    $self->{PRIORITY_MAP} =
	{
	  0 => 4,
	  1 => 4,
	  2 => 3,
	  3 => 3,
	  4 => 2,
	  5 => 2,
	};
    if ( $self->{FTS_PRIORITY} )
    {
      foreach ( split(',',$self->{FTS_PRIORITY}) )
      {
        $self->Fatal("Corrupt Priority specification \"$_\"")
		unless m%^(.*)=(.*)$%;
        $self->{PRIORITY_MAP}{$1} = $2;
      }
    }
}

# FTS map parsing
# The ftsmap file has the following format:
# SRM.Endpoint="srm://cmssrm.fnal.gov:8443/srm/managerv2" FTS.Endpoint="https://cmsstor20.fnal.gov:8443/glite-data-transfer-fts/services/FileTransfer"
# SRM.Endpoint="DEFAULT" FTS.Endpoint="https://cmsstor20.fnal.gov:8443/glite-data-transfer-fts/services/FileTransfer"

sub parseFTSmap {
    my $self = shift;

    my $mapfile = $self->{FTS_MAPFILE};

    # hash srmendpoint=>ftsendpoint;
    my $map = {};

    if (!open MAP, "$mapfile") {	
	$self->Fatal("FTSmap: Could not open ftsmap file $mapfile");
	return 1;
    }

    while (<MAP>) {
	chomp; 
	s|^\s+||; 
	next if /^\#/;
	next if /^\s*$/;
	unless ( /^SRM.Endpoint=\"(.+)\"\s+FTS.Endpoint=\"(.+)\"/ ) {
	    $self->Alert("FTSmap: Can not parse ftsmap line: '$_'");
	    next;
	}

	$map->{$1} = $2;
    }

    unless (defined $map->{DEFAULT}) {
	$self->Alert("FTSmap: Default FTS endpoit is not defined in the ftsmap file $mapfile");
	return 1;
    }

    $self->{FTS_MAP} = $map;
    $self->Dbgmsg('Transfer::FTS3::parseFTSmap '.$map) if $self->{DEBUG};
   
    return 0;
}

sub getFTSService {
    my $self = shift;
    my $to_pfn = shift;

    my $service;

    if ( exists $self->{FTS_MAP} ) {
	my ($endpoint) = ( $to_pfn =~ /(srm.+)\?SFN=/ );
	
	unless ($endpoint) {
	    $self->Alert("FTSmap: Could not get the end point from to_pfn $to_pfn");
	}

	my $map = $self->{FTS_MAP};

	$service = $map->{ (grep { $_ eq $endpoint } keys %$map)[0] || "DEFAULT" };
	$self->Alert("FTSmap: Could not get FTS service endpoint from ftsmap file for $endpoint") unless $service;
    }

    # fall back to command line option
    $service ||= $self->{FTS_SERVICE};
    $self->Dbgmsg('Transfer::FTS3::getFTSService '.$service) if $self->{DEBUG};

    return $service;
}

sub isBusy
{
    my ($self, $from, $to)  = @_;

    # Transfer::Core isBusy will honor all limits to jobs, files, and pending submissions
    my $busy = $self->SUPER::isBusy($from, $to);
    return $busy if $busy;

    # We additionaly define a busy state based on the number of
    # pending jobs in the FTS queue
    if (defined $from && defined $to) {
	# FTS states to consider as "pending"
	my @pending_states = ('READY', 'SUBMITTED', 'undefined');
    	# Check per-link busy status based on a maximum number of
	# "pending" files per link.  Treat undefined as pending until
	# their state is resolved.
	my $stats = $self->{FTS_Q_MONITOR}->LinkStats;

	my %state_counts;
	foreach my $file (keys %$stats) {
	    if (exists $stats->{$file}{$from}{$to}) {
		$state_counts{ $stats->{$file}{$from}{$to} }++;
	    }
	}

	$self->Dbgmsg("Transfer::FTS3::isBusy Link Stats $from -> $to: ",
		      join(' ', map { "$_=$state_counts{$_}" } sort keys %state_counts))
	    if $self->{DEBUG};

	# Count files in the Ready, Pending or undefined state
	my $n_pend = 0;
	foreach ( @pending_states )
	{
	    if ( defined($state_counts{$_}) ) { $n_pend += $state_counts{$_}; }
	}
	
	# Compare to our limit
	my $limit = $self->{LINK_PEND};
	if ( $n_pend >= $limit ) {
	    $self->Logmsg("backend busy: maximum link pending files for $from -> $to ($limit) reached\n") 
		if $self->{VERBOSE};
	    return 1;
	}
    }
    
    return 0;
}

sub pfn2se
{
    my ($pfn) = shift;
    if ($pfn =~ m!^\w+://([^/]+)/!) { return $1; }
    return undef;
}

# Override Core::batch_tasks.  FTS will only allow jobs to a unique
# fromSE, toSE, fromSpaceToken, toSpaceToken
sub batch_tasks
{
    my ($self, $tasklist, $batch_size) = @_;
    # peek at the first task to determine the storage elements
    my $task0 = @{$tasklist}[0];
    my $fromSE = &pfn2se($task0->{FROM_PFN});
    my $toSE   = &pfn2se($task0->{TO_PFN});
    my $fromSpaceToken = $task0->{FROM_TOKEN};
    my $toSpaceToken = $task0->{TO_TOKEN};

    # only take tasks matching these SEs
    if ($fromSE && $toSE) {
	my @batch; my @remaining; my $n = 0;
	foreach my $task (@$tasklist) {
	    no warnings 'uninitialized';
	    if ($n < $batch_size &&
		&pfn2se($task->{FROM_PFN}) eq $fromSE &&
		&pfn2se($task->{TO_PFN})   eq $toSE &&
		$task->{FROM_TOKEN} eq $fromSpaceToken &&
		$task->{TO_TOKEN} eq $toSpaceToken) {
		push @batch, $task;
		$n++;
	    } else {
		push @remaining, $task;
	    }
	}
	@$tasklist = @remaining; # redifine the task list
	return @batch;
    } else {
	# otherwise just do the normal thing and hope for the best
	# send an alert to report this phenomenon, but not if we're testing locally
	if ( !( ($task0->{FROM_PFN} =~ m%^file:%) && ($task0->{TO_PFN} =~ m%^file:%) ) )
	{
	  $self->Alert("Could not create SE-to-SE batch using from=$task0->{FROM_PFN} to=$task0->{TO_PFN}, ".
		     "using to default batch function instead");
	}
	return $self->SUPER::batch_tasks($tasklist, $batch_size);
    }
}

sub start_transfer_job
{
    my ($self, $kernel, $jobid) = @_[ OBJECT, KERNEL, ARG0 ];
    my $job = $self->{JOBS}->{$jobid}; # note: this is a "FileDownload job"
    my $dir = $job->{DIR};

    # create the copyjob file via Job->Prepare method
    my %files = ();

    # Create a FTS job from a group of files.
    # Because the FTS priorities are per job and the PhEDEx priorities
    # are per file (task), we take an average of the priorities of the
    # tasks in order to map that onto an FTS priority.  This should be
    # reasonable most of the time because we ought to get tasks in
    # batches of mostly the same priority.
    my $n_files = 0;
    my $sum_priority = 0;
    my $from_pfn;
    my $spacetoken;
    foreach my $task ( values %{$job->{TASKS}} ) {
	next unless $task;
	$from_pfn = $task->{FROM_PFN} unless $from_pfn;
	$spacetoken = $task->{TO_TOKEN} unless $spacetoken;

	$n_files++;
	$sum_priority += $task->{PRIORITY};

	my %args = (
		    SOURCE=>$task->{FROM_PFN},
		    DESTINATION=>$task->{TO_PFN},
		    FROM_NODE=>$task->{FROM_NODE},
		    TO_NODE=>$task->{TO_NODE},
		    FILESIZE=>$task->{FILESIZE},
		    TASKID=>$task->{TASKID},
		    WORKDIR=>$dir,
		    START=>&mytimeofday(),
		    );
	if ($self->{FTS_CHECKSUM}) {
	    my $checksum_map;
	    eval {$checksum_map=PHEDEX::Core::Formats::parseChecksums($task->{CHECKSUM});};
	    if ($@) { 
		$self->Alert("File $from_pfn: ",$@);
	    }
	    else {
		my $checksum_val=$checksum_map->{$self->{FTS_CHECKSUM_TYPE}};
		if (defined $checksum_val) {
		    $args{CHECKSUM_TYPE}=$self->{FTS_CHECKSUM_TYPE};
		    $args{CHECKSUM_VAL}=$checksum_val;
		}
	    }
	}
	my $f = PHEDEX::Transfer::Backend::File->new(%args);
	$files{$task->{TO_PFN}} = $f;
    }

    # Return if the job didn't contain any tasks (possible if the tasks expired before the submission of the job)
    if ($n_files==0) {
	$self->Alert("No tasks found for JOBID=$jobid");
	return;
    }

    my $avg_priority = int( $sum_priority / $n_files );
    $avg_priority = $self->{PRIORITY_MAP}{$avg_priority} || $avg_priority;
    my %args = (
                COPYJOB      => "$dir/copyjob",
                JSONCOPYJOB  => "$dir/jsoncopyjob",
		WORKDIR	     => $dir,
		FILES	     => \%files,
		VERBOSE	     => $self->{VERBOSE},
		PRIORITY     => $avg_priority,
		TIMEOUT	     => $self->{FTS_JOB_AWOL},
		SPACETOKEN   => $spacetoken,
                FTS_CHECKSUM => $self->{FTS_CHECKSUM},
                FTS_USE_JSON => $self->{FTS_USE_JSON}
		);
    my $ftsjob = PHEDEX::Transfer::Backend::Job->new(%args); # note:  this is an "FTS job"
    $ftsjob->Log('backend: ' . ref($self));

    eval {
        $self->Dbgmsg('calling Job -> PrepareJson') if $self->{DEBUG}; 
        $ftsjob->Prepare();
        $ftsjob->PrepareJson();
    };
    
    if ($@) {
	my $reason = "Cannot create copyjob";
	$ftsjob->Log("$reason\n$@");
	foreach my $file ( values %files ) {
	    $file->Reason($reason);
	    $kernel->yield('transfer_done', $file->{TASKID}, &xferinfo($file, $ftsjob));
	}
    }

    $self->Dbgmsg("Using copyjob file $ftsjob->{COPYJOB} and $ftsjob->{JSONCOPYJOB} which containts $ftsjob->{JSONJOB}\n") if $self->{DEBUG};

    # now get FTS service for the job
    # we take a first file in the job and determine
    # the FTS endpoint based on this (using ftsmap file, if given)
    my $service = $self->getFTSService( $from_pfn );

    unless ($service) {
	my $reason = "Cannot identify FTS service endpoint based on a sample source PFN $from_pfn";
	$ftsjob->Log("$reason\nSee download agent log file details, grep for\ FTSmap to see problems with FTS map file");
	foreach my $file ( values %files ) {
	    $file->Reason($reason);
	    $kernel->yield('transfer_done', $file->{TASKID}, &xferinfo($file, $ftsjob));
	}
    }

    $ftsjob->Service($service);
    
    $self->{JOBMANAGER}->addJob(
                             $self->{JOB_SUBMITTED_POSTBACK},
                             { JOB => $job, FTSJOB  => $ftsjob,
                               LOGFILE => '/dev/null', KEEP_OUTPUT => 1,
                               TIMEOUT => $self->{FTS_Q_MONITOR}->{Q_TIMEOUT} },
                             $self->{Q_INTERFACE}->Command('Submit',$ftsjob)
                           );
}

sub setup_callbacks
{
  my ($self,$kernel,$session) = @_; #[ OBJECT, KERNEL, SESSION ];

  $self->{SESSION_ID} = $session->ID;
# First the submission-callback
  $kernel->state('fts_job_submitted',$self);
  $self->{JOB_SUBMITTED_POSTBACK} = $session->postback( 'fts_job_submitted'  );

# Now the monitoring callbacks
  if ( $self->{FTS_Q_MONITOR} )
  {
    $kernel->state('fts_job_state_change',$self);
    $kernel->state('fts_file_state_change',$self);
    my $job_postback  = $session->postback( 'fts_job_state_change'  );
    my $file_postback = $session->postback( 'fts_file_state_change' );
    $self->{FTS_Q_MONITOR}->JOB_POSTBACK ( $job_postback );
    $self->{FTS_Q_MONITOR}->FILE_POSTBACK( $file_postback );
  }
}

# Resume a previously created job.  Return 1 for successful resumption, 0 for failure to resume
sub resume_backend_job
{
  my ( $self, $job ) = @_;
  my ($ftsjob_dmp,$ftsjob);

  $ftsjob_dmp = "$job->{DIR}/ftsjob.dmp";
  if ( ! -f $ftsjob_dmp )
  {
#   Job has not been submitted. Queue for submission.
    $self->Logmsg("Resume JOBID=$job->{ID} by submitting to FTS");
    POE::Kernel->post( $self->{SESSION_ID}, 'start_transfer_job', $job->{ID} );
    return 1;
  }

# Job was previously submitted. Recover the job and re-queue for monitoring
  $ftsjob = &evalinfo($ftsjob_dmp);
  if ( ! $ftsjob || $@ )
  {
    $self->Logmsg("Failed to load job for $job->{ID}");
    return 0;
  }
  $self->Logmsg("Resume JOBID=$job->{ID}, FTSjob=",$ftsjob->ID," by adding to monitoring");

  #register this job with queue monitor.
  $self->{FTS_Q_MONITOR}->QueueJob($ftsjob, $ftsjob->Priority);
  
  # the job has officially started
  $job->{STARTED} = &mytimeofday();
  return 1;
}

sub fts_job_submitted
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];

  my $command  = $arg1->[0];  # result of JobManager::addJob in start_transfer_job
  my $job    = $command->{JOB};
  my $ftsjob = $command->{FTSJOB};
  my $result = $self->{Q_INTERFACE}->ParseSubmit( $ftsjob, $command->{STDOUT} );
  
  # Log the command
  my $logsafe_cmd = join(' ', @{$command->{CMD}});
  $logsafe_cmd =~ s/ -p [\S]+/ -p _censored_/;
  $ftsjob->Log($logsafe_cmd);

  if ( $self->{DEBUG} && $command->{DURATION} > 8 )
  {
    my $id = $ftsjob->{ID} || 'unknown';
    my $subtime = int(1000*$command->{DURATION})/1000;
    $self->Warn('FTS job submission took ',$subtime,' seconds for JOBID=',$id);
  }

  if ( exists $result->{ERROR} ) { 
    # something went wrong...
    my $reason = "Could not submit to FTS\n";
    foreach ( split /\n/, $command->{STDERR} ) {
	$ftsjob->Log($_);
    }
    $ftsjob->Log( @{$result->{ERROR}} );
    $ftsjob->RawOutput( @{$result->{RAW_OUTPUT}} );
    foreach my $file ( values %{$ftsjob->FILES} ) {
      $file->Reason($reason);
      $kernel->yield('transfer_done', $file->{TASKID}, &xferinfo($file, $ftsjob));
    }
#   Make sure I forget about this job...?
    $self->{FTS_Q_MONITOR}->cleanup_job_stats($ftsjob);
    return;
  }

  $self->Logmsg("FTS job JOBID=",$ftsjob->ID,' submitted');
  # Save this job for retrieval if the agent is restarted
  my $jobsave = $ftsjob->WORKDIR . '/ftsjob.dmp';
  &output($jobsave, Dumper($ftsjob)) or $self->Fatal("$jobsave: $!");

  # Register this job with queue monitor.
  $self->{FTS_Q_MONITOR}->QueueJob($ftsjob, $ftsjob->Priority);
  
  # Set priority
  $self->{JOBMANAGER}->addJob(
                             undef,
                             { FTSJOB => $ftsjob, LOGFILE => '/dev/null', 
			       TIMEOUT => $self->{FTS_Q_MONITOR}->{Q_TIMEOUT} },
			      $self->{Q_INTERFACE}->Command('SetPriority', $ftsjob)
                           );

  # the job has officially started
  $job->{STARTED} = &mytimeofday();
}

sub fts_job_state_change
{
    my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $job = $arg1->[0];

#   A paranoid but harmless check that I have the right sort of entity!
    if ( ref($job) !~ m%PHEDEX::Transfer::Backend::Job% )
    { $self->Alert("I have a wrong job-type here!"); }

    # I get into this routine every time a job is monitored. Because I don't
    # want verbose monitoring forever, I turn it off here. So the first
    # monitoring call will have been verbose, the rest will not
    $job->VERBOSE(0);

    $self->Dbgmsg("fts_job_state_change callback JOBID=",$job->ID,", STATE=",$job->State) if $self->{DEBUG};
}

sub fts_file_state_change
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];

  my $file = $arg1->[0];
  my $job  = $arg1->[1];

  $self->Dbgmsg("fts_file_state_change TaskID=",$file->TaskID," JOBID=",$job->ID,
	  " STATE=",$file->State,' DEST=',$file->Destination) if $self->{DEBUG};
  
  # If the file is in an exit state, report the transfer done.  Only do so once.
  if ($file->ExitStates->{$file->State} && !$file->{TRANSFER_DONE}++) {
      $kernel->yield('transfer_done', $file->{TASKID}, &xferinfo($file, $job));
  }
}

# Prepares hash with transfer info for passing along to the
# 'transfer_done' event
sub xferinfo {
    my ($file, $job) = @_;

    # by now we report 0 for 'Finished' and 1 for Failed or Canceled
    # where would we do intelligent error processing 
    # and report differrent erorr codes for different errors?
    my $status = $file->ExitStates->{$file->State};
    $status = ($status == 1) ? 0 : 1;
    
    my $log = join("", $file->Log,
		   "-" x 10 . " JOB-LOG " . "-" x 10 . "\n",
		   $job->Log,
		   "-" x 10 . " RAWOUTPUT " . "-" x 10 . "\n",
		   $job->RawOutput,
		   );

    my $info = { START=>$file->Start,
		 END=>&mytimeofday(), 
		 LOG=>$log,
		 STATUS=>$status,
		 DETAIL=>$file->Reason || "", 
		 DURATION=>$file->Duration || 0 };
    
    return $info;
}

1;
