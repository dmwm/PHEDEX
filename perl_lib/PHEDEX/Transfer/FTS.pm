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
    $params->{PROTOCOLS}   ||= [ 'srm' ];  # Accepted protocols
    $params->{BATCH_FILES} ||= 25;     # Max number of files per batch
    $params->{FTS_LINK_FILES}  ||= 250;    # Queue this number of files in FTS for a link 
    $params->{FTS_POLL_QUEUE} ||= 1;       # Whether to poll all vs. our jobs
    $params->{FTS_Q_INTERVAL} ||= 30;       # Whether to poll all vs. our jobs
    $params->{FTS_J_INTERVAL} ||= 5;       # Whether to poll all vs. our jobs

    # Set argument parsing at this level.
    $options->{'batch-files=i'} = \$params->{BATCH_FILES};
    $options->{'link-files=i'} = \$params->{FTS_LINK_FILES};
    $options->{'service=s'} = \$params->{FTS_SERVICE};
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
}

# If $to and $from are not given, then the question is:
# "Are you too busy to take ANY transfers?"
# If they are provided, then the question is:
# "Are you too busy to take transfers on linke $from -> $to?"
sub isBusy
{
  my ($self, $jobs, $tasks, $to, $from)  = @_;
  my ($busy,$valid,%h,$n,$t);
  $busy = $valid = $t = $n = 0;

  # TODO:  Decide busy state per link!

  my $stats = $self->{FTS_Q_MONITOR}->Stats();

  if ( $stats &&
       exists $stats->{FILES} &&
       exists $stats->{FILES}{STATES} )
  {
      # Count the number of all file states
      foreach ( values %{$stats->{FILES}{STATES}} ) { $h{$_}++; }
  }

  # Count files in the Ready or Pending state
  foreach ( qw / Ready Pending / )
  {
      if ( defined($h{$_}) ) { $n += $h{$_}; }
  }
  # If there are 5 files in the Ready||Pending state
  if ( $n >= 5 ) { $busy = 1; }

  if ( exists($stats->{START}) ) { $t = time - $stats->{START}; }
  if ( $t > 60 ) { $valid = 1; }

  print "Transfer::FTS::isBusy: busy=$busy valid=$valid\n";
  return ($busy,$valid);
}


# Transfer batch of files.  Forks off the transfer wrapper for each
# file in the copy job (= one source, destination file pair).
sub startBatch
{
    my ($self, $jobs, $tasks, $dir, $jobname, $list) = @_;
    my @batch = splice(@$list, 0, $self->{BATCH_FILES});
    my $info = { ID => $jobname, DIR => $dir,
                 TASKS => { map { $_->{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($info));
    &touch("$dir/live");
    $jobs->{$jobname} = $info;
#    $self->clean($info, $tasks);

    #create the copyjob file via Job->PREPARE method
    
    my %files = ();

    foreach my $taskid ( keys %{$info->{TASKS}} ) {
	my $task = $tasks->{$taskid};

	my %args = (
		    SOURCE=>$task->{FROM_PFN},
		    DESTINATION=>$task->{TO_PFN},
		    TASKID=>$taskid,
		    TO_NODE=>$task->{TO_NODE},
		    FROM_NODE=>$task->{FROM_NODE},
		    WORKDIR=>$dir,
		    START=>&mytimeofday(),
		    );
	$files{$task->{TO_PFN}} = PHEDEX::Transfer::Backend::File->new(%args);
    }
    
    
    my $job = PHEDEX::Transfer::Backend::Job->new(COPYJOB=>"$dir/copyjob",
						  WORKDIR=>$dir,
						  FILES=>\%files,
						  );
    $job->PREPARE();

    my $id = $self->{Q_INTERFACE}->Submit($job);

    #FIX me check validity here - may be submission failed? - then report job done etc

    $job->ID($id);

    #register this job with queue monitor. We pass some hardcoded priority.
    $self->{FTS_Q_MONITOR}->QueueJob(1,$job);

    
}

sub check {

#    my ($self, $jobname, $job, $tasks) = @_;    

}

# sub transferBatch
# {
#     my ($self, $job, $tasks) = @_;
#     foreach (keys %{$job->{TASKS}})
#     {
#         $self->addJob(undef, { DETACHED => 1 },
# 		      $self->{WRAPPER}, $job->{DIR}, $self->{TIMEOUT},
# 		      @{$self->{COMMAND}}, $tasks->{$_}{FROM_PFN},
# 		      $tasks->{$_}{TO_PFN});
#     }
# }

sub setup_callbacks
{
  my ($self,$kernel,$session) = @_; #[ OBJECT, KERNEL, SESSION ];

  if ( $self->{FTS_Q_MONITOR} )
  {
    $kernel->state('job_state',$self);
    $kernel->state('file_state',$self);
    my $job_postback  = $session->postback( 'job_state'  );
    my $file_postback = $session->postback( 'file_state' );
    $self->{FTS_Q_MONITOR}->JOB_CALLBACK ( $job_postback );
    $self->{FTS_Q_MONITOR}->FILE_CALLBACK( $file_postback );
  }
}

sub job_state
{
    my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    print "Job-state callback", Dumper $arg0, "\n", Dumper $arg1, "\n";

    my $isexited = 0;

    my $job = $arg1->[0];

    if ($job->EXIT_STATES->{$job->{STATE}}) {
    }else{
	&touch($job->{WORKDIR}."/live");
    }
}

sub file_state
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
$DB::single=1;
  print "File-state callback", Dumper $arg0, "\n", Dumper $arg1, "\n"; 

  my $file = $arg1->[0];
  my $job  = $arg1->[1];

  if ($file->EXIT_STATES->{$file->{STATE}}) {
	
      my $summary = {START=>$file->{START},
		     END=>&mytimeofday(), 
		     LOG=> "@{$job->RAW_OUTPUT}",
		     DETAIL=>$file->{REASON}, 
		     DURATION=>$file->{DURATION}
		 };

      #make a done file
      &output($file->{WORKDIR}."/T".$file->{TASKID}."X", Dumper $summary);
  }

}


1;
