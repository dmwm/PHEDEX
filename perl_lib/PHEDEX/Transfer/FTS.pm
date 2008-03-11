package PHEDEX::Transfer::FTS; use base 'PHEDEX::Transfer::Core';
use strict;
use warnings;
use Getopt::Long;
use PHEDEX::Transfer::Backend::Job;
use PHEDEX::Transfer::Backend::File;
use PHEDEX::Transfer::Backend::Monitor;
use PHEDEX::Transfer::Backend::Interface::Glite;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Monalisa;
use POE;

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
    $params->{PROTOCOLS}   ||= [ 'srm' ];  # Accepted protocols
    $params->{BATCH_FILES} ||= 25;     # Max number of files per batch
    $params->{FTS_LINK_FILES}  ||= 250;    # Queue this number of files in FTS for a link 
    $params->{FTS_POLL_QUEUE} ||= 1;   # Whether to poll all vs. our jobs
    $params->{FTS_Q_INTERVAL} ||= 30;  # Interval for polling queue for new jobs
    $params->{FTS_J_INTERVAL} ||= 5;   # Interval for polling individual jobs

    # Set argument parsing at this level.
    $options->{'batch-files=i'} = \$params->{BATCH_FILES};
    $options->{'link-files=i'} = \$params->{FTS_LINK_FILES};
    $options->{'service=s'} = \$params->{FTS_SERVICE};
    $options->{'mode=s'} = \$params->{FTS_MODE};
    $options->{'mapfile=s'} = \$params->{FTS_MAPFILE};
    $options->{'q_interval=i'} = \$params->{FTS_Q_INTERVAL};
    $options->{'j_interval=i'} = \$params->{FTS_J_INTERVAL};
    $options->{'poll_queue=i'} = \$params->{FTS_POLL_QUEUE};
    $options->{'monalisa_host=s'} = \$params->{FTS_MONALISA_HOST};
    $options->{'monalisa_port=i'} = \$params->{FTS_MONALISA_PORT};
    $options->{'monalisa_cluster=s'} = \$params->{FTS_MONALISA_CLUSTER};
    $options->{'monalisa_node=s'} = \$params->{FTS_MONALISA_NODE};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;

    $self->init();
    use Data::Dumper; # XXX
    print 'FTS $self:  ', Dumper($self), "\n";
    return $self;
}

sub init
{
    my ($self) = @_;

    my $glite = PHEDEX::Transfer::Backend::Interface::Glite->new
	(
	 SERVICE => $self->{FTS_SERVICE},
	 NAME    => '::GLite',
	 );

    $self->{Q_INTERFACE} = $glite;

    print "Using service ",$glite->SERVICE,"\n"; # XXX

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
	 NAME          => '::QMon',
	 );

    $self->{FTS_Q_MONITOR} = $q_mon;

    $self->parseFTSmap() if ($self->{FTS_MAPFILE});
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

    if (!open M, "$mapfile") {	
	print "FTSmap: Could not open ftsmap file $mapfile\n";
	return 1;
    }

    while (<M>) {
	chomp; 
	s|^\s+||; 
	next if /^\#/;
	unless ( /^SRM.Endpoint=\"(.+)\"\s+FTS.Endpoint=\"(.+)\"/ ) {
	    print "FTSmap: Can not parse ftsmap line:\n$_\n";
	    next;
	}

	$map->{$1} = $2;
    }

    unless (defined $map->{DEFAULT}) {
	print "FTSmap: Default FTS endpoit is not defined in the ftsmap file $mapfile\n";
	return 1;
    }

    $self->{FTS_MAP} = $map;
    
    return 0;
}

sub getFTSService {
    my $self = shift;
    my $to_pfn = shift;

    my $service;

    my ($endpoint) = ( $to_pfn =~ /(srm.+)\?SFN=/ );

    unless ($endpoint) {
	print" FTSmap: Could not get the end point from to_pfn $to_pfn\n";
    }

    if ( exists $self->{FTS_MAP} ) {
	my $map = $self->{FTS_MAP};

	$service = $map->{ (grep { $_ eq $endpoint } keys %$map)[0] || "DEFAULT" };
	print "FTSmap: Could not get FTS service endpoint from ftsmap file for file, even default\n" unless $service;
    }

    #fall back to command line option
    $service ||= $self->{FTS_SERVICE};

    return $service;
}

# If $to and $from are not given, then the question is:
# "Are you too busy to take ANY transfers?"
# If they are provided, then the question is:
# "Are you too busy to take transfers on linke $from -> $to?"
sub isBusy
{
    my ($self, $jobs, $tasks, $to, $from)  = @_;
    my ($stats, $busy,$valid,%h,$n,$t);
    $busy = $valid = $t = $n = 0;

    if (defined $from && defined $to) {
	$stats = $self->{FTS_Q_MONITOR}->{LINKSTATS};

	foreach my $file (keys %$stats) {
	    if (exists $stats->{$file}{$from}{$to}) {
		$h{ $stats->{$file}{$from}{$to} }++;
	    }
	}
	print "Transfer::FTS::isBusy Link Stats $from->$to\n",
	Dumper(\%h), "\n";

	# Count files in the Ready or Pending state
	foreach ( qw / Ready Pending / )
	{
	    if ( defined($h{$_}) ) { $n += $h{$_}; }
	}
	# If there are 5 files in the Ready||Pending state
	if ( $n >= 5 ) { $busy = 1; }
      
	if ( exists($stats->{START}) ) { $t = time - $stats->{START}; }
	if ( $t > 60 ) { $valid = 1; }

	print "Transfer::FTS::isBusy $from->$to: busy=$busy valid=$valid\n";

    } else {
	$stats = $self->{FTS_Q_MONITOR}->WorkStats();
	if ( $stats &&
	     exists $stats->{FILES} &&
	     exists $stats->{FILES}{STATES} )
	{
	    # Count the number of all file states
	    foreach ( values %{$stats->{FILES}{STATES}} ) { $h{$_}++; }
	}
      
	# Count files in the Ready, Pending, or undefined states
	foreach ( qw / Ready Pending undefined / )
	{
	    if ( defined($h{$_}) ) { $n += $h{$_}; }
	}
	# If there are 5 files in the Ready||Pending||undefined state
	if ( $n >= 5 ) { $busy = 1; }
	
	if ( exists($stats->{START}) ) { $t = time - $stats->{START}; }
	if ( $t > 60 ) { $valid = 1; }
	
	print "Transfer::FTS::isBusy IN TOTAL: busy=$busy valid=$valid\n";
    }

  print "Transfer::FTS::isBusy: busy=$busy valid=$valid\n";
  return $busy && $valid ? 1 : 0;
}


sub startBatch
{
    my ($self, $jobs, $tasks, $dir, $jobname, $list) = @_;

    my @batch = splice(@$list, 0, $self->{BATCH_FILES});
    my $info = { ID => $jobname, DIR => $dir,
                 TASKS => { map { $_->{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($info));
    &touch("$dir/live");
    $jobs->{$jobname} = $info;

    #create the copyjob file via Job->Prepare method
    my %files = ();

    foreach my $taskid ( keys %{$info->{TASKS}} ) {
	my $task = $tasks->{$taskid};

	my %args = (
		    SOURCE=>$task->{FROM_PFN},
		    DESTINATION=>$task->{TO_PFN},
		    FROM_NODE=>$task->{FROM_NODE},
		    TO_NODE=>$task->{TO_NODE},
		    TASKID=>$taskid,
		    WORKDIR=>$dir,
		    START=>&mytimeofday(),
		    );
	$files{$task->{TO_PFN}} = PHEDEX::Transfer::Backend::File->new(%args);
    }
    
    my %args = (
		COPYJOB=>"$dir/copyjob",
		WORKDIR=>$dir,
		FILES=>\%files,
#		SERVICE=>$service,
		);
    
    my $job = PHEDEX::Transfer::Backend::Job->new(%args);

    #this writes out a copyjob file
    $job->Prepare();


    #now get FTS service for the job
    #we take a first file in the job and determine
    #the FTS endpoint based on this (using ftsmap file, if given)
    my $service = $self->getFTSService( $batch[0]->{FROM_PFN} );

    unless ($service) {
	my $reason = "Cannot identify FTS service endpoint based on a sample source PFN $batch[0]->{FROM_PFN}";
	print $reason, "\n";
	$job->Log("$reason\nSee download agent log file details, grep for\ FTSmap to see problems with FTS map file");
	foreach my $file ( keys %files ) {
	    $file->Reason($reason);
	    $self->mkTransferSummary($file, $job);
	}
    }

    $job->Service($service);

    my $result = $self->{Q_INTERFACE}->Submit($job);

    if ( exists $result->{ERROR} ) { 
	# something went wrong...
	my $reason = "Could not submit to FTS\n";
	$job->Log( $result->{ERROR} );
	foreach my $file ( keys %files ) {
            $file->Reason($reason);
            $self->mkTransferSummary($file, $job);
        }

	$self->mkTranserSummary();
	return;
    }

    my $id = $result->{ID};

    $job->ID($id);

    #register this job with queue monitor.
    $self->{FTS_Q_MONITOR}->QueueJob($job);
}

sub check 
{
}

sub setup_callbacks
{
  my ($self,$kernel,$session) = @_; #[ OBJECT, KERNEL, SESSION ];

  if ( $self->{FTS_Q_MONITOR} )
  {
    $kernel->state('job_state_change',$self);
    $kernel->state('file_state_change',$self);
    my $job_postback  = $session->postback( 'job_state_change'  );
    my $file_postback = $session->postback( 'file_state_change' );
    $self->{FTS_Q_MONITOR}->JOB_POSTBACK ( $job_postback );
    $self->{FTS_Q_MONITOR}->FILE_POSTBACK( $file_postback );
  }
}

sub job_state_change
{
    my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
#    print "Job-state callback", Dumper $arg0, "\n", Dumper $arg1, "\n";

    my $job = $arg1->[0];
    print "Job-state callback ID ",$job->ID,", STATE ",$job->State,"\n";

    if ($job->ExitStates->{$job->State}) {
    }else{
	&touch($job->Workdir."/live");
    }
}

sub file_state_change
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
#  print "File-state callback", Dumper $arg0, "\n", Dumper $arg1, "\n"; 

  my $file = $arg1->[0];
  my $job  = $arg1->[1];

  print "File-state callback TASKID ",$file->TaskID," JOBID ",$job->ID," STATE ",$file->State,' ',$file->Destination,"\n";

  if ($file->ExitStates->{$file->State}) {
      $self->mkTransferSummary($file,$job);
  }
}

sub mkTransferSummary {
    my $self = shift;
    my $file = shift;
    my $job = shift;

    #by now we report 0 for 'Finished' and 1 for Failed or Canceled
    #where would we do intelligent error processing 
    #and report differrent erorr codes for different errors?
    my $status = $file->ExitStates->{$file->State};

    $status = ($status == 1)?0:1;
    
    my $log = join("", $file->Log,
		   "-" x 10 . " RAWOUTPUT " . "-" x 10 . "\n",
		   $job->RawOutput);

    my $summary = {START=>$file->Start,
		   END=>&mytimeofday(), 
		   LOG=>$log,
		   STATUS=>$status,
		   DETAIL=>$file->Reason || "", 
		   DURATION=>$file->Duration || 0
		   };
    
    #make a done file
    &output($job->Workdir."/T".$file->{TASKID}."X", Dumper $summary);

    print "mkTransferSummary done for task: ",$job->Workdir,' ',$file->TaskID,"\n";
}

1;
