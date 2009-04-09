package PHEDEX::Core::JobManager;

=head1 NAME

PHEDEX::Core::JobManager - a POE-based job-manager for external commands

=cut

use strict;
use warnings;
use base 'Exporter', 'PHEDEX::Core::Logging';
use POSIX;
use POE;
use POE::Queue::Array;
use POE::Component::Child;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Util ( qw / str_hash / );
use Data::Dumper;
$|=1;
######################################################################
# JOB MANAGEMENT TOOLS

our %events = (
  stdout => \&_child_stdout,
  stderr => \&_child_stderr,
  error  => \&_child_error,
  done   => \&_child_done,
  died   => \&_child_died,
);

our $pkg = $POE::Component::Child::PKG;
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);
    my $self = { NJOBS => $args{NJOBS} || 1, JOBS => 0, KEEPALIVE => 1 };
    $self->{POCO_DEBUG} = $ENV{POCO_DEBUG} || 0; # Specially for PoCo::Child
    $self->{VERBOSE}    = $args{VERBOSE} || 0;
    $self->{DEBUG}      = $args{DEBUG}   || 0;
    $self->{KEEPALIVE}  = $args{KEEPALIVE} if defined $args{KEEPALIVE};

#   A queue to hold the jobs we will run
    $self->{QUEUE} = POE::Queue::Array->new();
    bless $self, $class;

#   Start a POE session for myself
    POE::Session->create
      (
        object_states =>
        [
          $self =>
          {
	    job_queued		=> 'job_queued',
	    timeout		=> 'timeout',
	    queue_drained	=> 'queue_drained',
	    maybe_clear_alarms	=> 'maybe_clear_alarms',
	    heartbeat		=> 'heartbeat',

            _start	=> '_jm_start',
            _stop	=> '_jm_stop',
	    _child	=> '_jm_child',
            _default	=> '_jm_default',
          },
        ],
      );

#   And now a child-manager
    $self->{_child} = POE::Component::Child->new(
           events => \%events,
           debug => $self->{POCO_DEBUG},
          );

#   Hold the output of the children...
    $self->{payloads} = {};

    return $self;
}

sub _jm_start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("starting (session ",$session->ID,")");
  $self->{JOB_MANAGER_SESSION_ID} = $session->ID;
  $kernel->delay_set('heartbeat',60) if $self->{KEEPALIVE};
}

sub _jm_stop
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("stopping (session ",$session->ID,")");
}

sub _jm_child {} # Dummy event-handler, to silence warnings

sub _jm_default
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

sub heartbeat
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $kernel->delay_set('heartbeat',60);
}

sub job_queued
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  if ( scalar(keys %{$self->{payloads}}) >= $self->{NJOBS} )
  {
    $kernel->delay_set('job_queued',0.3);
    return;
  }
  my ($priority,$id,$job) = $self->{QUEUE}->dequeue_next();
  if ( !$job )
  {
    $kernel->delay_set('job_queued',0.1);
    return;
  }

  my $wheelid = $self->{_child}->run(@{$job->{CMD}});
  $job->{PID} = $self->{_child}{$pkg}{wheels}{$wheelid}{ref}->PID;
#print "Start WheelID=$wheelid, owner=$self->{JOB_MANAGER_SESSION_ID}, pid=$job->{PID},\n";
  $self->{_child}{$pkg}{owner}{$wheelid} = $self;
  $self->{payloads}{$wheelid} = $job;
  $self->{payloads}{$wheelid}{start} = &mytimeofday();

  if ( $job->{TIMEOUT} )
  {
    my $timer_id = $kernel->delay_set('timeout',$job->{TIMEOUT},$wheelid);
    $self->{payloads}{$wheelid}{timer_id} = $timer_id;
    $self->{payloads}{$wheelid}{signals} = [ qw / 1 15 9 / ];
  }
  $job->{CMDNAME} = $job->{CMD}[0];
  $job->{CMDNAME} =~ s|.*/||;

  if (exists $job->{LOGFILE})
  {
    $job->{LOGPREFIX} = 1;
    open($job->{LOGFH}, '>>', $job->{LOGFILE})
	or die "Couldn't open log file $job->{LOGFILE}: $!";
    my $logfh = \*{$job->{LOGFH}};
    my $oldfh = select($logfh); local $| = 1; select($oldfh);
    print $logfh
	(strftime ("%Y-%m-%d %H:%M:%S", gmtime),
         " $job->{CMDNAME}($job->{PID}): Executing: @{$job->{CMD}}\n");
  } 
  else
  {
    open($job->{LOGFH}, '>&', \*STDOUT);
  }
}

sub _child_stdout {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my ($wheelid,$payload,$owner);
  $wheelid = $args->{wheel};
  $owner = $self->{$pkg}{owner}{$wheelid};
  $payload = $owner->{payloads}{$wheelid};

  $owner->Logmsg("STDOUT: $args->{out}\n") if $owner->{DEBUG};
  push @{$payload->{result}->{RAW_OUTPUT}}, $args->{out};

  my $logfhtmp = \*{$payload->{LOGFH}};
  my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);

  if ($payload->{LOGPREFIX})
  {
    print $logfhtmp "$date $payload->{CMDNAME}($payload->{PID}): ";
  }
  print $logfhtmp $args->{out},"\n";
}

sub _child_stderr {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my ($wheelid,$payload,$owner);
  $wheelid = $args->{wheel};
  $owner = $self->{$pkg}{owner}{$wheelid};
  $payload = $owner->{payloads}{$wheelid};

  $owner->Logmsg("STDERR: $args->{out}\n") if $owner->{DEBUG};
  chomp $args->{out};
  push @{$payload->{result}->{ERROR}}, $args->{out};
}

sub _child_done {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my ($wheelid,$payload,$owner);
  $wheelid = $args->{wheel};
  $owner = $self->{$pkg}{owner}{$wheelid};
  $payload = $owner->{payloads}{$wheelid};
  $owner->{JOBS}--;

  # Set the various return values
  @$payload{qw(STATUS EXIT SIGNAL CORE STATUS_CODE)} = &runerror ($args->{rc});

  my $duration = &mytimeofday() - $payload->{start};

  if (exists $payload->{LOGFILE})
  {
    my $logfh = \*{$payload->{LOGFH}};
    print $logfh (strftime ("%Y-%m-%d %H:%M:%S", gmtime),
      " $payload->{CMDNAME}($payload->{PID}): Job exited with status code",
      " $payload->{STATUS} ($payload->{STATUS_CODE})",
      sprintf(" after %.3f seconds", $duration), "\n" );
    close $logfh;
  }

  if ( $owner->{DEBUG} )
  {
    if ( ref($payload->{CMD}) eq 'ARRAY' )
    {
    print "PID=$payload->{PID} RC=$payload->{RC} SIGNAL=$payload->{SIGNAL} CMD=\"@{$payload->{CMD}}\"\n";
    }
    else
    {
    print str_hash($payload),"\n";
    }
  }

# Some monitoring...
  $owner->Logmsg(sprintf("$payload->{CMD}[0] took %.3f seconds", $duration)) if $owner->{DEBUG};

  my $result;
  if ( defined($payload->{ACTION}) )
  {
    $payload->{DURATION} = $duration;
    $payload->{ACTION}->( $payload );
  }
  else
  {
    $result = $payload->{result} unless defined($result);
    $result->{DURATION} = $duration;
    if ( $result && defined($payload->{FTSJOB}) )
    {
      my ($job,$str,$k);
      $job = $payload->{FTSJOB};
      $str = uc $payload->{parse};
      foreach $k ( keys %{$result} )
      {
        if ( ref($result->{$k}) eq 'ARRAY' )
        {
          $job->Log(map { "$str: $k: $_" } @{$result->{$k}});
        }
        else
        {
          $job->Log("$str: $k: $result->{$k}");
        }
      }
    }
  }

# cleanup...
  delete $owner->{payloads}{$wheelid};
  POE::Kernel->post( $owner->{JOB_MANAGER_SESSION_ID}, 'maybe_clear_alarms', $payload->{timer_id} ) if $payload->{timer_id};
}

sub _child_died {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my ($wheelid,$payload,$owner);
  $wheelid = $args->{wheel};
  $owner = $self->{$pkg}{owner}{$wheelid};
  $payload = $owner->{payloads}{$wheelid};

  $args->{out} ||= '';
  chomp $args->{out};
  my $text = 'child_died: [' . $args->{rc} . '] ' . $args->{out};
  push @{$payload->{result}->{ERROR}}, $text;
  _child_done( $self, $args );
}

sub _child_error {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my ($wheelid,$payload,$owner);
  $wheelid = $args->{wheel};
  $owner = $self->{$pkg}{owner}{$wheelid};
  $payload = $owner->{payloads}{$wheelid};

  chomp $args->{error};
  my $text = 'child_error: [' . $args->{err} . '] ' . $args->{error};
  push @{$payload->{result}->{ERROR}}, $text;
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
  $job->{PRIORITY} = POSIX::DBL_MAX   # default ideally the lowest possible.
      unless exists $job->{PRIORITY};
  $self->{QUEUE}->enqueue($job->{PRIORITY} ,$job);
  $self->{JOBS}++;
  POE::Kernel->post($self->{JOB_MANAGER_SESSION_ID}, 'job_queued');
}

sub timeout
{
  my ( $self, $kernel, $wheelid ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $payload = $self->{payloads}{$wheelid};
  return unless defined $payload;
  my $signal = shift @{$payload->{signals}};
  return unless $signal;
  my $wheel = $self->{_child}->wheel($wheelid);
  $payload->{TIMED_OUT} = &mytimeofday();
  $wheel->kill( $signal );
  my $timeout = $payload->{TIMEOUT_GRACE} || 3;
  print "Sending signal $signal to wheel $wheelid\n" if $self->{VERBOSE};
  $kernel->delay_set( 'timeout', $timeout, $wheelid );
}

# Terminate the children (yikes!)
sub killAllJobs
{
  my $self = shift;

  foreach my $wheelID ( keys %{$self->{wheels}} )
  {
    POE::Kernel->post($self->{JOB_MANAGER_SESSION_ID}, 'timeout', $wheelID);
  }
}

sub pumpJobs
{
  print <<EOD;
'pumpJobs' is obsolete, and can seriously damage your POE-health.
EOD
}

sub whenQueueDrained
{
  my ($self,$callback) = @_;
  $callback = sub {} unless $callback;
  push @{$self->{QUEUE_DRAINED_CALLBACKS}}, $callback;
  if ( ! $self->{_DOINGSOMETHING}++ )
  {
#   Kick off the queue_drained loop if it isn't already running
    POE::Kernel->post( $self->{JOB_MANAGER_SESSION_ID}, 'queue_drained' );
  }
}
 
sub queue_drained
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  if ( $self->jobsRemaining() )
  {
    $kernel->delay_set('queue_drained',0.1);
    return;
  }

# use pop instead of shift to get the callbacks in the order they were
# added to the queue, just in case that matters
  while ( my $callback = pop @{$self->{QUEUE_DRAINED_CALLBACKS}} )
  {
    &$callback() if $callback;
    $self->{_DOINGSOMETHING}--;
  }
}

sub jobsRemaining()
{
  my $self = shift;
  return scalar(keys %{$self->{wheels}}) + $self->{QUEUE}->get_item_count();
}
 
sub maybe_clear_alarms
{
# After a child is completed, if there are no other jobs running or queued,
# I clear all timers. This makes sure the session can quit early. Otherwise,
# it will wait for the timeouts to fire, even for tasks that have finished.
  my ($self,$kernel,$session,$timer_id) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

  $kernel->alarm_remove($timer_id) if $timer_id;

  return if $self->jobsRemaining();
#  my @removed_alarms = $kernel->alarm_remove_all();
#  foreach my $alarm (@removed_alarms) {
#    my ($name, $time, $param) = @$alarm;
#    print "Cleared alarm: alarm=@{$alarm}, time=$time, param=$param\n";
#  }
    $kernel->post( 'queue_drained' );
}

1;
