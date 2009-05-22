package PHEDEX::Transfer::FTS; use base 'PHEDEX::Transfer::Core';

use strict;
use warnings;

use Getopt::Long;
use POSIX;
use Data::Dumper;

use PHEDEX::Transfer::Backend::Job;
use PHEDEX::Transfer::Backend::File;
use PHEDEX::Transfer::Backend::Monitor;
use PHEDEX::Transfer::Backend::Interface::GliteAsync;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
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
    $params->{PROTOCOLS}           ||= [ 'srm' ];  # Accepted protocols
    $params->{BATCH_FILES}         ||= 30;         # Max number of files per job
    $params->{NJOBS}               ||= 0;          # Max number of jobs.  0 for infinite.
    $params->{LINK_PEND}           ||= 5;          # Submit to FTS until this number of files per link are "pending"
    $params->{FTS_POLL_QUEUE}      ||= 0;          # Whether to poll all vs. our jobs
    $params->{FTS_Q_INTERVAL}      ||= 30;         # Interval for polling queue for new jobs
    $params->{FTS_J_INTERVAL}      ||= 5;          # Interval for polling individual jobs
    $params->{FTS_GLITE_OPTIONS}   ||= {};	   # Specific options for glite commands
    $params->{FTS_JOB_AWOL}        ||= 3600;       # Timeout for successful monitoring of a job.  0 for infinite.

    # Set argument parsing at this level.
    $options->{'service=s'}            = \$params->{FTS_SERVICE};
    $options->{'myproxy=s'}            = \$params->{FTS_MYPROXY};
    $options->{'passfile=s'}           = \$params->{FTS_PASSFILE};
    $options->{'priority=s'}           = \$params->{FTS_PRIORITY};
    $options->{'mapfile=s'}            = \$params->{FTS_MAPFILE};
    $options->{'q_interval=i'}         = \$params->{FTS_Q_INTERVAL};
    $options->{'j_interval=i'}         = \$params->{FTS_J_INTERVAL};
    $options->{'poll_queue=i'}         = \$params->{FTS_POLL_QUEUE};
    $options->{'monalisa_host=s'}      = \$params->{FTS_MONALISA_HOST};
    $options->{'monalisa_port=i'}      = \$params->{FTS_MONALISA_PORT};
    $options->{'monalisa_cluster=s'}   = \$params->{FTS_MONALISA_CLUSTER};
    $options->{'monalisa_node=s'}      = \$params->{FTS_MONALISA_NODE};
    $options->{'glite-options=s'}      =  $params->{FTS_GLITE_OPTIONS};
    $options->{'job-awol=i'}           = \$params->{FTS_JOB_AWOL};

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

    $self->init();
    if ( $self->{DEBUG} )
    {
      my $dump = Dumper($self);
      my $password = $self->{FTS_Q_MONITOR}{Q_INTERFACE}{PASSWORD};
      $dump =~ s%$password%_censored_%g if $password;
      $self->Dbgmsg('FTS $self:  ', $dump) if $self->{DEBUG};
    }

#   Enhanced debugging!
    PHEDEX::Monitoring::Process::MonitorSize('FTS',\$self);
    PHEDEX::Monitoring::Process::MonitorSize('QMon',\$self->{FTS_Q_MONITOR});
    PHEDEX::Monitoring::Process::MonitorSize('GLite',\$self->{FTS_Q_MONITOR}{Q_INTERFACE});
    return $self;
}

sub init
{
    my ($self) = @_;

    my $glite = PHEDEX::Transfer::Backend::Interface::GliteAsync->new
	(
	 SERVICE => $self->{FTS_SERVICE},
	 OPTIONS => $self->{FTS_GLITE_OPTIONS},
	 ME      => 'GLite',
	 );

    $glite->MYPROXY($self->{FTS_MYPROXY}) if $self->{FTS_MYPROXY};

    if ($self->{FTS_PASSFILE}) {
	my $passfile = $self->{FTS_PASSFILE};
	my $ok = 1;
	if (! -f $passfile) {
	    $self->Alert("FTS passfile '$passfile' does not exist");
	    $ok = 0;
	} elsif (! -r $passfile) {
	    $self->Alert("FTS passfile '$passfile' is not readable");
	    $ok = 0;
	} elsif ( (stat($passfile))[2] != 0100600 &&
                  (stat($passfile))[2] != 0100400 ) {
	    $self->Warn("FTS passfile '$passfile' has vulnerable file access permissions, ",
			"please restrict with 'chmod 600 $passfile'");
	}

	if ($ok) {
	    open PASSFILE, "< $passfile" or die $!;
	    my $pass = <PASSFILE>; chomp $pass;
	    close PASSFILE;
	    $glite->PASSWORD($pass);
	}
    }

    $self->{Q_INTERFACE} = $glite;

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
	 Q_INTERFACE   => $glite,
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

    return $service;
}

sub isBusy
{
    my ($self, $from, $to)  = @_;

    # Transfer::Core isBusy will honor all limits to jobs, files, and pending submitions
    my $busy = $self->SUPER::isBusy($from, $to);
    return $busy if $busy;

    # We additionaly define a busy state based on the number of
    # pending jobs in the FTS queue
    if (defined $from && defined $to) {
	# FTS states to consider as "pending"
	my @pending_states = ('Ready', 'Pending', 'Submitted', 'undefined');
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

	$self->Dbgmsg("Transfer::FTS::isBusy Link Stats $from -> $to: ",
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
		    TASKID=>$task->{TASKID},
		    WORKDIR=>$dir,
		    START=>&mytimeofday(),
		    );
	my $f = PHEDEX::Transfer::Backend::File->new(%args);
	$files{$task->{TO_PFN}} = $f;
    }
 
    my $avg_priority = int( $sum_priority / $n_files );
    $avg_priority = $self->{PRIORITY_MAP}{$avg_priority} || $avg_priority;
    my %args = (
		COPYJOB	   => "$dir/copyjob",
		WORKDIR	   => $dir,
		FILES	   => \%files,
		VERBOSE	   => 1,
		PRIORITY   => $avg_priority,
		TIMEOUT	   => $self->{FTS_JOB_AWOL},
		SPACETOKEN => $spacetoken,
		);
    my $ftsjob = PHEDEX::Transfer::Backend::Job->new(%args); # note:  this is an "FTS job"
    $ftsjob->Log('backend: ' . ref($self));

    # this writes out a copyjob file
    $ftsjob->Prepare();

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

sub resume_backend_job
{
  my ( $self, $job, $taskid ) = @_;
  my ($ftsjob_dmp,$ftsjob);

  if ( exists($self->{_resumed_jobs}{$job->{ID}}) )
  {
    $self->Logmsg("Already resumed JOBID=$job->{ID}, NOP this time...");
    return;
  }

  $ftsjob_dmp = "$job->{DIR}/ftsjob.dmp";
  if ( ! -f $ftsjob_dmp )
  {
#   Job has not been submitted. Queue for submission.
    $self->Logmsg("Resume JOBID=$job->{ID} by submitting to FTS");
    POE::Kernel->post( $self->{SESSION_ID}, 'start_transfer_job', $job->{ID} );
    $self->{_resumed_jobs}{$job->{ID}}{$taskid}++;
    return;
  }

# Job was previously submitted. Recover the job and re-queue for monitoring
  $ftsjob = evalinfo($ftsjob_dmp);
  if ( ! $ftsjob || $@ )
  {
    $self->Logmsg("Failed to load job for $job->{ID}");
    return;
  }
  $self->Logmsg("Resume JOBID=$job->{ID}, FTSjob=",$ftsjob->ID," by adding to monitoring");

  #register this job with queue monitor.
  $self->{FTS_Q_MONITOR}->QueueJob($ftsjob);
  
  # the job has officially started
  $job->{STARTED} = &mytimeofday();
  $self->{_resumed_jobs}{$job->{ID}}{$taskid}++;
}

sub fts_job_submitted
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];

  my $wheel = $arg1->[0];
  my $result = $self->{Q_INTERFACE}->ParseSubmit( $wheel );
  my $job    = $wheel->{JOB};
  my $ftsjob = $wheel->{FTSJOB};
  
  if ( $self->{DEBUG} && $wheel->{DURATION} > 8 )
  {
    my $id = $ftsjob->{ID} || 'unknown';
    $self->Warn('FTS job submition took ',$wheel->{DURATION},' seconds for JOBID=',$id);
  }

  if ( exists $result->{ERROR} ) { 
    # something went wrong...
    my $reason = "Could not submit to FTS\n";
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
  open JOB, ">$jobsave" or $self->Fatal("$jobsave: $!");
  print JOB Dumper($ftsjob);
  close JOB;

  #register this job with queue monitor.
  $self->{FTS_Q_MONITOR}->QueueJob($ftsjob);
  
  # the job has officially started
  $job->{STARTED} = &mytimeofday();
}

sub fts_job_state_change
{
    my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my $job = $arg1->[0];

#   A paranoid but harmless check that I have the right sort of entity!
    if ( ref($job) !~ m%PHEDEX::Transfer::Backend::Job% )
    { print "I have a wrong job-type here!\n"; }

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
