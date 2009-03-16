package PHEDEX::Transfer::Backend::Monitor;

=head1 NAME

PHEDEX::Transfer::Backend::Monitor - Polling or monitoring of a transfer queue.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item Name

=back

=head1 EXAMPLES

pending...

=head1 SEE ALSO...

L<PHEDEX::Transfer::Backend::Interface::Glite|PHEDEX::Transfer::Backend::Interface::Glite>

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use POE::Session;
use POE::Queue::Array;
use PHEDEX::Monalisa;

our %params =
	(
	  Q_INTERFACE		=> undef, # A transfer queue interface object
	  Q_INTERVAL		=> 60,	  # Queue polling interval
	  Q_TIMEOUT		=> 60,	  # Timeout for Q_INTERFACE commands
	  J_INTERVAL		=>  5,	  # Job polling interval
	  POLL_QUEUE		=>  0,	  # Poll the queue or not?
	  ME			=> 'QMon',# Arbitrary name for this object
	  STATISTICS_INTERVAL	=> 60,	  # Interval for reporting statistics
	  JOB_POSTBACK		=> undef, # Callback for job state changes
	  FILE_POSTBACK		=> undef, # Callback for file state changes
	  SANITY_INTERVAL	=> 60,	  # Interval for internal sanity-checks
	  DEBUG			=> $ENV{PHEDEX_DEBUG} || 0,
 	  VERBOSE		=> $ENV{PHEDEX_VERBOSE} || 0,
	);
our %ro_params =
	(
	  QUEUE	=> undef,	# A POE::Queue of transfer jobs...
	  WORKSTATS	=> {},	# Statistics on the job or file states
	  LINKSTATS     => {},  # Statistics on the link TODO:  combine with WORKSTATS
	  JOBS		=> {},  # A hash of Job-IDs.
	  APMON => undef,	# A PHEDEX::Monalisa object, if I want it!
	  LAST_SUCCESSFULL_POLL => time,	# When I last got a job status
	);
our $dbg=1;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? delete $args{$_} : $params{$_}
      } keys %params;
  map {
        $self->{$_} = defined($args{$_}) ? delete $args{$_} : $ro_params{$_}
      } keys %ro_params;

  $self->{QUEUE} = POE::Queue::Array->new();
  bless $self, $class;

  POE::Session->create
	(
	  object_states =>
	  [
	    $self =>
	    {
	      poll_queue		=> 'poll_queue',
	      poll_queue_postback	=> 'poll_queue_postback',
	      poll_job			=> 'poll_job',
	      poll_job_postback		=> 'poll_job_postback',
	      report_job		=> 'report_job',
	      report_statistics		=> 'report_statistics',
	      forget_job    		=> 'forget_job',
	      shoot_myself		=> 'shoot_myself',

	      _default	 => '_default',
	      _stop	 => '_stop',
	      _start	 => '_start',
	      _child	 => '_child',
            },
          ],
	);

# Sanity checks:
  $self->{J_INTERVAL}>0 or die "J_INTERVAL too small:",$self->{J_INTERVAL},"\n";
  $self->{Q_INTERVAL}>0 or die "Q_INTERVAL too small:",$self->{Q_INTERVAL},"\n";
  ref($self->{Q_INTERFACE}) or die "No sensible Q_INTERFACE object defined.\n";

# foreach ( qw / ListQueue ListJob / )
# { $self->{Q_INTERFACE}->can($_) or warn "Q_INTERFACE cannot \"$_\"?\n"; }
  foreach ( qw / StatePriority / )
  { $self->{Q_INTERFACE}->can($_) or die "Q_INTERFACE cannot \"$_\"?\n"; }

  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;

  return $self->{$attr} if exists $ro_params{$attr};

  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub _stop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  print $self->Hdr, "is ending, for lack of work...\n";
}

sub _default
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my $ref = ref($self);
  die <<EOF;

  Default handler for class $ref:
  The default handler caught an unhandled "$_[ARG0]" event.
  The $_[ARG0] event was given these parameters: @{$_[ARG1]}

  (...end of dump)
EOF
}

sub _start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  print $self->Hdr,"is starting (session ",$session->ID,")\n";

  $self->{SESSION_ID} = $session->ID;
  $kernel->alias_set($self->{ME});

  my $poll_queue_postback  = $session->postback( 'poll_queue_postback'  );
  $self->{POLL_QUEUE_POSTBACK} = $poll_queue_postback;
  my $poll_job_postback  = $session->postback( 'poll_job_postback'  );
  $self->{POLL_JOB_POSTBACK} = $poll_job_postback;
  $kernel->yield('poll_queue')
	if $self->{Q_INTERFACE}->can('ListQueue')
	&& $self->{POLL_QUEUE};
  $kernel->delay_set('poll_job',$self->{J_INTERVAL})
	if $self->{Q_INTERFACE}->can('ListJob');
  $kernel->yield('report_statistics') if $self->{STATISTICS_INTERVAL};
}

sub _child {}

sub shoot_myself
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->call( $session, 'report_statistics' );
  if ( $self->{APMON} ) { $self->{APMON}->ApMon->free(); }
  print $self->Hdr,"shooting myself...\n";
  $kernel->alarm_remove_all();
}

sub poll_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  return unless $self->{POLL_QUEUE};
  $self->Logmsg('Why am I in poll_queue?') if $self->{DEBUG};
die "I do not want to be here...";
  $self->{JOBMANAGER}->addJob(
                             $self->{POLL_QUEUE_POSTBACK},
                             { TIMEOUT => $self->{Q_TIMEOUT} },
                             $self->{Q_INTERFACE}->Command('ListQueue')
                           );
}

sub poll_queue_postback
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my ($id,$result,$priority,$wheel);
die "This code has not been tested...";
  $wheel = $arg1->[0];
  $result = $self->{Q_INTERFACE}->ParseListQueue( $wheel );

  if ( $self->{DEBUG} && $result->{DURATION} > 8 )
  { $self->Logmsg('ListQueue took ',$result->{DURATION},' seconds'); }

  if ( $result->{ERROR} )
  {
    print $self->Hdr,"ListQueue error: ",join("\n",@{$result->{ERROR}}),"\n";
    goto PQDONE;
  }
  else
  { $self->{LAST_SUCCESSFULL_POLL} = time; }

  foreach my $h ( values %{$result->{JOBS}} )
  {
    my $job;
    if ( ! exists($self->{JOBS}{$h->{ID}}) )
    {
      $job = PHEDEX::Transfer::Backend::Job->new
			(
			 ID		=> $h->{ID},
			 STATE		=> $h->{STATE},
			 SERVICE        => $h->{SERVICE},
			 TIMESTAMP	=> time,
			 VERBOSE	=> 1,
			);
    }
    else { $job = $self->{JOBS}{$h->{ID}}; }

# priority calculation here needs to be consistant with what is calculated
# later
    $priority = $self->{Q_INTERFACE}->StatePriority($h->{STATE});
    if ( ! $priority )
    {
#     I can forget about this job...
      $kernel->yield('report_job',$job);
      next;
    }

    if ( ! exists($self->{JOBS}{$h->{ID}}) )
    {
#     Queue this job for monitoring...
      $job->Priority($priority);
      $self->Logmsg('requeue(1) JOBID=',$job->ID) if $self->{DEBUG};
      $self->{QUEUE}->enqueue( $priority, $job );
      $self->{JOBS}{$h->{ID}} = $job;
      print $self->Hdr,"Queued $h->{ID} at priority $priority (",$h->{STATE},")\n" if $self->{VERBOSE};
    }
  }
PQDONE:
  $kernel->delay_set('poll_queue', $self->{Q_INTERVAL});
}

sub poll_job
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($priority,$id,$job);

  ($priority,$id,$job) = $self->{QUEUE}->dequeue_next;
  if ( ! $id )
  {
    $self->{LAST_SUCCESSFUL_POLL} = time;
    $kernel->delay_set('poll_job', $self->{J_INTERVAL});
    return;
  }

  $self->Logmsg('dequeue JOBID=',$job->ID) if $self->{DEBUG};
  $self->{JOBMANAGER}->addJob(
                             $self->{POLL_JOB_POSTBACK},
                             { FTSJOB => $job, TIMEOUT => $self->{Q_TIMEOUT} },
                             $self->{Q_INTERFACE}->Command('ListJob',$job)
                           );

}

sub poll_job_postback
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my ($result,$priority,$id,$job,$summary,$wheel);

  $wheel = $arg1->[0];
  $result = $self->{Q_INTERFACE}->ParseListJob( $wheel );
  $job = $wheel->{FTSJOB};

  if ( $self->{DEBUG} && $wheel->{DURATION} > 8 )
  { $self->Logmsg('ListJob took ',$wheel->{DURATION},' seconds'); }

# Arbitrary value, fixed, for now.
  $priority = 30;
  if (exists $result->{ERROR}) {
      print $self->Hdr,"ListJob for ",$job->ID," returned error: ",
			join("\n",@{$result->{ERROR}}),"\n";

#     If I haven't been successful monitoring this job for a long time, give up on it
      my $timeout = $job->Timeout;
      if ( $timeout && $job->Timestamp + $timeout < time  )
      {
        $self->Logmsg('Abandoning JOBID=',$job->ID," after timeout ($timeout seconds)");
        $job->State('abandoned');
# FIXME This duplicates some code below, could be made cleaner...
        $self->WorkStats('JOBS', $job->ID, $job->State);
        $self->{JOB_POSTBACK}->($job) if $self->{JOB_POSTBACK};
        if ( $job->ExitStates->{$result->{JOB_STATE}} )
        {
          push @{$self->{EXITED_JOBS}}, $job->ID;
          $kernel->yield('report_job',$job);
          goto PJDONE;
        }
      }

#     Put this job back in the queue before I forget about it completely!
      $priority = $job->Priority();
      $self->Logmsg('requeue(2) JOBID=',$job->ID) if $self->{DEBUG};
      $self->{QUEUE}->enqueue( $priority, $job );
      goto PJDONE;
  }

  if ( $job->VERBOSE )
  {
    foreach ( @{$result->{INFO}} ) { chomp; $job->Log($_) };
    $job->VERBOSE(0);
  };

  $self->{LAST_SUCCESSFULL_POLL} = time;
  print $self->Hdr,"JOBID=",$job->ID," STATE=$result->{JOB_STATE}\n";

  $job->State($result->{JOB_STATE});
  $job->RawOutput(@{$result->{RAW_OUTPUT}});

  my $files = $job->Files;
  foreach ( keys %{$result->{FILES}} )
  {
    my $s = $result->{FILES}{$_};
    my $f = $files->{$s->{DESTINATION}};
    if ( ! $f )
    {
      $f = PHEDEX::Transfer::Backend::File->new( %{$s} );
      $job->Files($f);
    }

#   Paranoia!
    if ( ! exists $f->ExitStates->{$s->{STATE}} )
    { die "Unknown file-state: " . $s->{STATE}."\n"; }

    $self->WorkStats('FILES', $f->Destination, $f->State);
    $self->LinkStats($f->Destination, $f->FromNode, $f->ToNode, $f->State);

    if ( $_ = $f->State( $s->{STATE} ) )
    {
      $f->Log($f->Timestamp,"from $_ to ",$f->State);
      $job->Log($f->Timestamp,$f->Source,$f->Destination,$f->State );
      if ( $f->ExitStates->{$f->State} )
      {
#       Log the details...
	$summary = join (' ',
			  map { "$_=\"" . $s->{$_} ."\"" }
			  qw / SOURCE DESTINATION DURATION RETRIES REASON /
			);
        $job->Log( time, 'file transfer details',$summary,"\n" );
        $f->Log  ( time, 'file transfer details',$summary,"\n" );

        foreach ( qw / DURATION RETRIES REASON / ) { $f->$_($s->{$_}); }
      }
      $job->FILE_POSTBACK->( $f, $_, $s ) if $job->FILE_POSTBACK;
      $self->{FILE_POSTBACK}->( $f, $job ) if $self->{FILE_POSTBACK};
    }
  }

  $summary = join(' ',
		   "ETC=" . $result->{ETC},
		   'JOB_STATE=' . $result->{JOB_STATE},
		   'FILE_STATES:',
              	   map { $_.'='.$result->{FILE_STATES}{$_} }
               	         sort keys %{$result->{FILE_STATES}}
                 );
  if ( $job->Summary ne $summary )
  {
    print $self->Hdr,' JOBID=',$job->ID," $summary\n" if $self->{VERBOSE};
    $job->Summary($summary);
  }

# Paranoia!
  if ( ! exists $job->ExitStates->{$result->{JOB_STATE}} )
  { die "Unknown job-state: " . $result->{JOB_STATE}."\n"; }

  $job->State($result->{JOB_STATE});
  $self->WorkStats('JOBS', $job->ID, $job->State);
  $self->{JOB_POSTBACK}->($job) if $self->{JOB_POSTBACK};
  if ( $job->ExitStates->{$result->{JOB_STATE}} )
  {
    push @{$self->{EXITED_JOBS}}, $job->ID;
    $kernel->yield('report_job',$job);
  }
  else
  {
# Leave priority fixed for now.
#   $result->{ETC} = 100 if $result->{ETC} < 1;
#   $priority = $result->{ETC};
#   $priority = int($priority/60);
#   $priority = 30 if $priority < 30;
    $job->Priority($priority);
    $self->Logmsg('requeue(3) JOBID=',$job->ID) if $self->{DEBUG};
    $self->{QUEUE}->enqueue( $priority, $job );
  }

PJDONE:
  $kernel->delay_set('poll_job', $self->{J_INTERVAL});
}

sub report_job
{
  my ( $self, $kernel, $job ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $jobid = $job->ID;
  $self->Logmsg("$jobid has ended in state ",$job->State) if $self->{VERBOSE};

  $job->Log(time,'Job has ended');
  $self->WorkStats('JOBS', $job->ID, $job->State);
  foreach ( values %{$job->Files} )
  {
    $self->WorkStats('FILES', $_->Destination, $_->State);
    $self->LinkStats($_->Destination, $_->FromNode, $_->ToNode, $_->State);
  }

  $self->{JOB_POSTBACK}->($job) if $self->{JOB_POSTBACK};
  if ( defined $job->JOB_POSTBACK ) { $job->JOB_POSTBACK->(); }
  else
  {
    print $self->Hdr,'Log for ',$job->ID,"\n",
	  $job->Log,
	  $self->Hdr,'Log ends for ',$job->ID,"\n" if $self->{VERBOSE};
  }

# Now I should take detailed action on any errors...
  $self->cleanup_job_stats($job);
  $kernel->delay_set('forget_job',900,$job);
}

sub forget_job
{
  my ( $self, $kernel, $job ) = @_[ OBJECT, KERNEL, ARG0 ];
  delete $self->{JOBS}{$job->ID} if $job->ID;
}

sub cleanup_job_stats
{
  my ( $self, $job ) = @_;
  my $jobid = $job->ID || 'unknown-job';
  $self->Logmsg("Cleaning up stats for JOBID=$jobid...") if $self->{VERBOSE};
  delete $self->{WORKSTATS}{JOBS}{STATES}{$jobid};
  foreach ( values %{$job->Files} )
  {
    $self->cleanup_file_stats($_);
  }
}

sub cleanup_file_stats
{
  my ( $self, $file ) = @_;
  $self->Logmsg("Cleaning up stats for file destination=",$file->Destination) if $self->{VERBOSE};
  delete $self->{WORKSTATS}{FILES}{STATES}{$file->Destination};
  delete $self->{LINKSTATS}{$file->Destination};
}

sub report_statistics
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($s,$t,$key,$summary);

  if ( ! defined($self->{WORKSTATS}{START}) )
  {
    $self->{WORKSTATS}{START} = time;
    print $self->Hdr,"STATISTICS: INTERVAL=",$self->{STATISTICS_INTERVAL},"\n";
  }
  $t = time - $self->{WORKSTATS}{START};

  foreach $key ( keys %{$self->{WORKSTATS}} )
  {
    next unless ref($self->{WORKSTATS}{$key}) eq 'HASH';
    next unless defined $self->{WORKSTATS}{$key}{STATES};
    $self->{WORKSTATS}{$key}{SUMMARY} = '' unless $self->{WORKSTATS}{$key}{SUMMARY};

    foreach ( keys %{$self->{WORKSTATS}{$key}{STATES}} )
    {
      $s->{$key}{TOTAL}++;
      $s->{$key}{STATES}{$self->{WORKSTATS}{$key}{STATES}{$_} || 'undefined'}++;
    }

    next unless defined( $s->{$key}{TOTAL} );
    $summary = join(' ', 'Total='.$s->{$key}{TOTAL},
    (map { "$_=" . $s->{$key}{STATES}{$_} } sort keys %{$s->{$key}{STATES}} ));
#   if ( $self->{WORKSTATS}{$key}{SUMMARY} ne $summary )
    {
      print $self->Hdr,"STATISTICS: TIME=$t $key: $summary\n";
      $self->{WORKSTATS}{$key}{SUMMARY} = $summary;
    }

#    use Data::Dumper();
#    print "STATS DUMP: ", Data::Dumper::Dumper ($self->{STATS}), "\n"; # XXX

    if ( $self->{APMON} )
    {
      my $h = $s->{$key}{STATES};
      my $g;
      if ( $key eq 'JOBS'  ) { $g = PHEDEX::Transfer::Backend::Job::ExitStates(); }
      if ( $key eq 'FILES' ) { $g = PHEDEX::Transfer::Backend::File::ExitStates(); }
      foreach ( keys %{$g} )
      {
        $h->{$_} = 0 unless defined $h->{$_};
      }
      $h->{Cluster} = $self->{APMON}{Cluster} || 'PhEDEx';
      $h->{Node}    = ($self->{APMON}{Node} || $self->{ME}) . '_' . $key;
      $self->{APMON}->Send($h);
    }
  }

  $kernel->delay_set( 'report_statistics', $self->{STATISTICS_INTERVAL} );
}

sub WorkStats
{
  my ($self,$class,$key,$val) = @_;
  if ( defined($class) && !defined($key))
  {
      return $self->{WORKSTATS}{$class}{STATES};
  }
  elsif ( defined($class) && defined($key) )
  {
    $self->Logmsg("WorkStats: class=$class key=$key value=$val") if $self->{DEBUG};
    $self->{WORKSTATS}{$class}{STATES}{$key} = $val;
    return $self->{WORKSTATS}{$class};
  }
  return $self->{WORKSTATS};
}

sub LinkStats
{
    my ($self,$file,$from,$to,$state) = @_;
    return $self->{LINKSTATS} unless defined $file &&
				     defined $from &&
				     defined $to;
    $self->{LINKSTATS}{$file}{$from}{$to} = $state;
    return $self->{LINKSTATS}{$file}{$from}{$to};
}

sub isKnown
{
  my ( $self, $job ) = @_;
  return 0 unless defined $self->{JOBS}{$job->{ID}};
  return 1;
}

sub QueueJob
{
  my ( $self, $job, $priority ) = @_;

  return if $self->isKnown($job);
  $priority = 1 unless $priority;
  $self->Logmsg('Queueing JOBID=',$job->ID,' at priority ',$priority);

  $self->WorkStats('JOBS', $job->ID, $job->State);
  foreach ( values %{$job->Files} )
  {
    $self->WorkStats('FILES', $_->Destination, $_->State);
    $self->LinkStats($_->Destination, $_->FromNode, $_->ToNode, $_->State);
  }
  $job->Priority($priority);
  $job->Timestamp(time);
  $self->Logmsg('enqueue JOBID=',$job->ID) if $self->{DEBUG};
  $self->{QUEUE}->enqueue( $priority, $job );
  $self->{JOBS}{$job->{ID}} = $job;
  $self->{JOBMANAGER}->addJob(
                             undef,
                             { FTSJOB => $job, TIMEOUT => $self->{Q_TIMEOUT} },
                             $self->{Q_INTERFACE}->Command('SetPriority',$job)
                           );
}

1;
