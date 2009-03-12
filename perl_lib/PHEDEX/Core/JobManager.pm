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

######################################################################
# JOB MANAGEMENT TOOLS

our %events = (
  stdout => \&_child_stdout,
  stderr => \&_child_stderr,
  error  => \&_child_error,
  done   => \&_child_done,
  died   => \&_child_died,
);

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
    $self->{_child}{caller} = $self;

#   Hold the output of the children...
    $self->{wheels} = {};

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
  if ( scalar(keys %{$self->{wheels}}) >= $self->{NJOBS} )
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
  my $wheel = $self->{_child}->run(@{$job->{CMD}});
  my $pkg = 'POE::Component::Child';
  $job->{PID} = $self->{_child}{$pkg}{wheels}{$wheel}{ref}->PID;
  $self->{wheels}{$wheel} = $job;
  $self->{wheels}{$wheel}{start} = &mytimeofday();
  if ( $job->{TIMEOUT} )
  {
    my $timer_id = $kernel->delay_set('timeout',$job->{TIMEOUT},$wheel);
    $self->{wheels}{$wheel}{timer_id} = $timer_id;
    $self->{wheels}{$wheel}{signals} = [ qw / 1 15 9 / ];
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
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  $self->{caller}->Logmsg("STDOUT: $args->{out}\n") if $self->{caller}{DEBUG};
  push @{$wheel->{result}->{RAW_OUTPUT}}, $args->{out};

  my $logfhtmp = \*{$wheel->{LOGFH}};
  my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);

  if ($wheel->{LOGPREFIX})
  {
    print $logfhtmp "$date $wheel->{CMDNAME}($wheel->{PID}): ";
  }
  print $logfhtmp $args->{out},"\n";
}

sub _child_stderr {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  $self->{caller}->Logmsg("STDERR: $args->{out}\n") if $self->{caller}{DEBUG};
  chomp $args->{out};
  push @{$wheel->{result}->{ERROR}}, $args->{out};
}

sub _child_done {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  $self->{caller}{JOBS}--;

# FIXME This could be cleaner...?
  $wheel->{STATUS_CODE} = $args->{rc};
  $wheel->{RC}  = $args->{rc} >> 8;
  $wheel->{SIG} = $args->{rc} & 127;
  $wheel->{STATUS} = &runerror ($args->{rc});

  my $duration = &mytimeofday() - $wheel->{start};

  if (exists $wheel->{LOGFILE})
  {
    my $logfh = \*{$wheel->{LOGFH}};
    print $logfh (strftime ("%Y-%m-%d %H:%M:%S", gmtime),
      " $wheel->{CMDNAME}($wheel->{PID}): Job exited with status code",
      " $wheel->{STATUS} ($wheel->{STATUS_CODE})",
      sprintf(" after %.3f seconds", $duration), "\n" );
    close $logfh;
  }

  if ( $self->{caller}{DEBUG} )
  {
    print "PID=$wheel->{PID} RC=$wheel->{RC} SIGNAL=$wheel->{SIG} CMD=\"@{$wheel->{CMD}}\"\n";
  }

# Some monitoring...
  $self->{caller}->Logmsg(sprintf("$wheel->{CMD}[0] took %.3f seconds", $duration)) if $self->{caller}{DEBUG};

  my $result;
  if ( defined($wheel->{ACTION}) )
  {
    $wheel->{DURATION} = $duration;
    $wheel->{ACTION}->( $wheel );
  }
  else
  {
    $result = $wheel->{result} unless defined($result);
    $result->{DURATION} = $duration;
    if ( $result && defined($wheel->{arg}) )
    {
      my ($job,$str,$k);
      $job = $wheel->{arg};
      $str = uc $wheel->{parse};
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
  delete $self->{caller}{wheels}{$args->{wheel}};
  POE::Kernel->post( $self->{caller}{JOB_MANAGER_SESSION_ID}, 'maybe_clear_alarms', $wheel->{timer_id} );
}

sub _child_died {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  $args->{out} ||= '';
  chomp $args->{out};
  my $text = 'child_died: [' . $args->{rc} . '] ' . $args->{out};
  push @{$wheel->{result}->{ERROR}}, $text;
  _child_done( $self, $args );
}

sub _child_error {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  chomp $args->{error};
  my $text = 'child_error: [' . $args->{err} . '] ' . $args->{error};
  push @{$wheel->{result}->{ERROR}}, $text;
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
  my ( $self, $kernel, $wheelID ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $job = $self->{wheels}{$wheelID};
  return unless defined $job;
  my $signal = shift @{$job->{signals}};
  return unless $signal;
  my $wheel = $self->{_child}->wheel($wheelID);
  $wheel->kill( $signal );
  my $timeout = $job->{TIMEOUT_GRACE} || 3;
  print "Sending signal $signal to wheel $wheelID\n" if $self->{VERBOSE};
  $kernel->delay_set( 'timeout', $timeout, $wheelID );
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
