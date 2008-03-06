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
use POE::Session;
use POE::Queue::Array;
use PHEDEX::Monalisa;

our %params =
	(
	  Q_INTERFACE		=> undef, # A transfer queue interface object
	  Q_INTERVAL		=> 60,	  # Queue polling interval
	  J_INTERVAL		=>  5,	  # Job polling interval
	  POLL_QUEUE		=>  1,	  # Poll the queue or not?
	  NAME			=> undef, # Arbitrary name for this object
	  STATISTICS_INTERVAL	=> 60,	  # Interval for reporting statistics
	  JOB_CALLBACK		=> undef, # Callback for job state changes
	  FILE_CALLBACK		=> undef, # Callback for file state changes
	  VERBOSE		=> 0,
	);
our %ro_params =
	(
	  QUEUE	=> undef,	# A POE::Queue of transfer jobs...
	  STATS	=> {},		# Statistics on the transfer states
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
  $self->{JOBS} = {};
  bless $self, $class;

  POE::Session->create
	(
	  object_states =>
	  [
	    $self =>
	    {
	      poll_queue	=> 'poll_queue',
	      poll_job		=> 'poll_job',
	      report_job	=> 'report_job',
	      report_statistics	=> 'report_statistics',
	      cleanup_stats    	=> 'cleanup_stats',
	      shoot_myself	=> 'shoot_myself',

	      _default	 => '_default',
	      _stop	 => '_stop',
	      _start	 => '_start',
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

sub hdr
{
  my $self = shift;
  my $name = $self->{NAME} || ref($self) || "(unknown object $self)";
  return scalar(localtime) . ': ' . $name . ' ';
}

sub _stop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  print $self->hdr, "is ending, for lack of work...\n";
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
  print $self->hdr,"is starting (session ",$session->ID,")\n";

  $self->{SESSION_ID} = $session->ID;
  $kernel->yield('poll_queue')
	if $self->{Q_INTERFACE}->can('ListQueue')
	&& $self->{POLL_QUEUE};
  $kernel->delay_set('poll_job',$self->{J_INTERVAL})
	if $self->{Q_INTERFACE}->can('ListJob');
  $kernel->yield('report_statistics') if $self->{STATISTICS_INTERVAL};
}

sub shoot_myself
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->call( $session, 'report_statistics' );
  if ( $self->{APMON} ) { $self->{APMON}->ApMon->free(); }
  print $self->hdr,"shooting myself...\n";
  $kernel->alarm_remove_all();
}

sub poll_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($id,$list,$priority);

  return unless $self->{POLL_QUEUE};
  print $self->hdr,"poll_queue...\n";

  $list = $self->{Q_INTERFACE}->ListQueue;
  if ( $list ) { $self->{LAST_SUCCESSFULL_POLL} = time; }
  else
  {
    warn "No successfull queue- or job-poll in ",
	 time-$self->{LAST_SUCCESSFULL_POLL},
	 " seconds\n";
    goto DONE;
  }

  foreach $id ( keys %{$list} )
  {
    my $job;
    if ( ! exists($self->{JOBS}{$id}) )
    {
      $job = PHEDEX::Transfer::Backend::Job->new
			(
				ID		=> $id,
				STATE		=> $list->{$id},
				TIMESTAMP	=> time,
			);
    }
    else { $job = $self->{JOBS}{$id}; }

    $priority = $self->{Q_INTERFACE}->StatePriority($list->{$id});
    if ( ! $priority )
    {
#     I can forget about this job...
      $kernel->yield('report_job',$job);
      next;
    }

    if ( ! exists($self->{JOBS}{$id}) )
    {
#     Queue this job for monitoring...
      $self->{QUEUE}->enqueue( $priority, $job );
      $self->{JOBS}{$id} = $job;
      print "Queued $id at priority $priority (",$list->{$id},")\n" if $self->{VERBOSE};
    }
  }
  $kernel->delay_set('poll_queue', $self->{Q_INTERVAL});
}

sub poll_job
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($state,$priority,$id,$job,$summary);

  ($priority,$id,$job) = $self->{QUEUE}->dequeue_next;
  goto DONE unless $id;

  $state = $self->{Q_INTERFACE}->ListJob($job);

  print "JOBID $job->{ID} STATE $state->{JOB_STATE}\n";

  if ( $state ) { $self->{LAST_SUCCESSFULL_POLL} = time; }
  else
  {
    warn "No successfull queue- or job-poll in ",
	 time-$self->{LAST_SUCCESSFULL_POLL},
	 " seconds\n";
    goto DONE;
  }

  $job->STATE($state->{JOB_STATE});
  $job->RAW_OUTPUT($state->{RAW_OUTPUT});

  my $files = $job->FILES;
  foreach ( keys %{$state->{FILES}} )
  {
    my $s = $state->{FILES}{$_};
    my $f = $files->{$s->{DESTINATION}};
    if ( ! $f )
    {
      $f = PHEDEX::Transfer::Backend::File->new( %{$s} );
      $job->FILES($f);
    }

#   Paranoia!
    if ( ! exists $f->EXIT_STATES->{$s->{STATE}} )
    { die "Unknown file-state: " . $s->{STATE}."\n"; }

    $self->Stats('FILES', $f->DESTINATION, $f->STATE);
    if ( $_ = $f->STATE( $s->{STATE} ) )
    {
      $f->LOG($f->TIMESTAMP,"from $_ to ",$f->STATE);
      $job->LOG($f->TIMESTAMP,$f->SOURCE,$f->DESTINATION,$f->STATE );
      if ( $f->EXIT_STATES->{$f->STATE} )
      {
#       Log the details...
	$summary = join (' ',
			  map { "$_=\"" . $s->{$_} ."\"" }
			  qw / SOURCE DESTINATION DURATION RETRIES REASON /
			);
        $job->LOG( time, 'file transfer details',$summary,"\n" );
        $f->LOG  ( time, 'file transfer details',$summary,"\n" );

        foreach ( qw / DURATION RETRIES REASON / ) { $f->{$_} = $s->{$_}; }
      }
      $job->FILE_CALLBACK->( $f, $_, $s ) if $job->FILE_CALLBACK;
      $self->{FILE_CALLBACK}->( $f, $job ) if $self->{FILE_CALLBACK};
    }
  }

  $summary = join(' ',
		   "ETC=" . $state->{ETC},
		   'JOB_STATE=' . $state->{JOB_STATE},
		   'FILE_STATES:',
              	   map { $_.'='.$state->{FILE_STATES}{$_} }
               	         sort keys %{$state->{FILE_STATES}}
                 );
  if ( $job->SUMMARY ne $summary )
  {
    print $self->hdr,"$job->{ID}: $summary\n" if $self->{VERBOSE};
    $job->SUMMARY($summary);
  }

# Paranoia!
  if ( ! exists $job->EXIT_STATES->{$state->{JOB_STATE}} )
  { die "Unknown job-state: " . $state->{JOB_STATE}."\n"; }

  $job->STATE($state->{JOB_STATE});
  $self->Stats('JOBS', $job->ID, $job->STATE);
  $self->{JOB_CALLBACK}->($job) if $self->{JOB_CALLBACK};
  if ( $job->EXIT_STATES->{$state->{JOB_STATE}} )
  {
    $kernel->yield('report_job',$job);
  }
  else
  {
    $state->{ETC} = 100 if $state->{ETC} < 1;
    $priority = $state->{ETC};
    $priority = int($priority/60);
    $priority = 30 if $priority < 30;
    $self->{QUEUE}->enqueue( $priority, $job );
  }

DONE:
  $kernel->delay_set('poll_job', $self->{J_INTERVAL});
}

sub report_job
{
  my ( $self, $kernel, $job ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $jobid = $job->ID;
  print $self->hdr,"Job $jobid has ended...\n" if $self->{VERBOSE};

  $job->LOG(time,'Job has ended');
  $self->Stats('JOBS', $job->ID, $job->STATE);
  foreach ( values %{$job->FILES} )
  {
    $self->Stats('FILES', $_->DESTINATION, $_->STATE);
  }

  if ( defined $job->JOB_CALLBACK ) { $job->JOB_CALLBACK->(); }
  else
  {
    print $self->hdr,'Log for ',$job->ID,"\n",
		scalar $job->LOG,
	  $self->hdr,'Log ends for ',$job->ID,"\n" if $self->{VERBOSE};
  }

# Now I should take detailed action on any errors...
  $kernel->yield('cleanup_stats',$job);
}

sub cleanup_stats
{
  my ( $self, $kernel, $job ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $jobid = $job->ID;
  print $self->hdr,"Cleaning up stats for job $jobid...\n" if $self->{VERBOSE};
  delete $self->{STATS}{JOBS}{STATES}{$job->ID};
  foreach ( values %{$job->FILES} )
  {
    delete $self->{STATS}{FILES}{STATES}{$_->DESTINATION};
  }

  delete $self->{JOBS}{$job->ID};
}



sub report_statistics
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($s,$t,$key,$summary);

  if ( ! defined($self->{STATS}{START}) )
  {
    $self->{STATS}{START} = time;
    print $self->hdr,"STATISTICS: INTERVAL=",$self->{STATISTICS_INTERVAL},"\n";
  }
  $t = time - $self->{STATS}{START};

  foreach $key ( keys %{$self->{STATS}} )
  {
    next unless ref($self->{STATS}{$key}) eq 'HASH';
    next unless defined $self->{STATS}{$key}{STATES};
    $self->{STATS}{$key}{SUMMARY} = '' unless $self->{STATS}{$key}{SUMMARY};

    foreach ( keys %{$self->{STATS}{$key}{STATES}} )
    {
      $s->{$key}{TOTAL}++;
      $s->{$key}{STATES}{$self->{STATS}{$key}{STATES}{$_} || 'undefined'}++;
    }

    next unless defined( $s->{$key}{TOTAL} );
    $summary = join(' ', 'Total='.$s->{$key}{TOTAL},
    (map { "$_=" . $s->{$key}{STATES}{$_} } sort keys %{$s->{$key}{STATES}} ));
    if ( $self->{STATS}{$key}{SUMMARY} ne $summary )
    {
      print $self->hdr,"STATISTICS: TIME=$t $key: $summary\n";
      $self->{STATS}{$key}{SUMMARY} = $summary;
    }

    use Data::Dumper();
    print "STATS DUMP: ", Data::Dumper::Dumper ($self->{STATS}), "\n"; # XXX

    if ( $self->{APMON} )
    {
      my $h = $s->{$key}{STATES};
      my $g;
      if ( $key eq 'JOBS'  ) { $g = PHEDEX::Transfer::Backend::Job::EXIT_STATES(); }
      if ( $key eq 'FILES' ) { $g = PHEDEX::Transfer::Backend::File::EXIT_STATES(); }
      foreach ( keys %{$g} )
      {
        $h->{$_} = 0 unless defined $h->{$_};
      }
      $h->{Cluster} = $self->{APMON}{Cluster} || 'PhEDEx';
      $h->{Node}    = ($self->{APMON}{Node} || $self->{NAME}) . '_' . $key;
      $self->{APMON}->Send($h);
    }
  }

  $kernel->delay_set( 'report_statistics', $self->{STATISTICS_INTERVAL} );
}

sub Stats
{
  my ($self,$class,$key,$val) = @_;
  if ( defined($class) && !defined($key))
  {
      return $self->{STATS}{$class}{STATES};
  }
  elsif ( defined($class) && defined($key) )
  {
    $self->{STATS}{$class}{STATES}{$key} = $val;
    return $self->{STATS}{$class};
  }
  return $self->{STATS};
}

sub QueueJob
{
  my ( $self, $priority, $job ) = @_;
  $self->Stats('JOBS', $job->ID, $job->STATE);
  $self->{QUEUE}->enqueue( $priority, $job );
}

1;
