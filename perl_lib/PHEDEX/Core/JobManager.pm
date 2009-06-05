package PHEDEX::Core::JobManager;
use base 'PHEDEX::Core::Logging';

=pod

=head1 NAME

PHEDEX::Core::JobManager - a POE-based job-manager for external commands

=cut

use strict;
use warnings;
use POSIX;
use POE;
use POE::Queue::Array;
use POE::Component::Child;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;

# Contains job hashes which are returned back to the caller who
# submitted the job.  They are identified by a POE::Wheel ID, which is
# supposed to be unique, so there should be no collision with multiple
# job managers.
our %PAYLOADS = ();

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);
    my $self = $class->SUPER::new(@_);
    my %params = ( NJOBS      => 1,  # number of parallel jobs, 0 for infinite
		   KEEPALIVE  => 1,  # whether or not to quit after all jobs are complete
		   VERBOSE    => 0,
		   DEBUG      => 0,
		   POCO_DEBUG => $ENV{POCO_DEBUG} || 0   # special debugging flag
		   );
    $$self{$_} = exists $args{$_} ? $args{$_} : $params{$_} for keys %params;

    $self->{JOB_QUEUE} = POE::Queue::Array->new();
    $self->{JOBS_RUNNING} = {};

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

    $self->{_child} = 
      POE::Component::Child->new(
           events => {
	       stdout => \&_child_stdout,
	       stderr => \&_child_stderr,
	       error  => \&_child_error,
	       done   => \&_child_done,
	       died   => \&_child_died,
	   },
           debug  => $self->{POCO_DEBUG},
          );

    return $self;
}

sub _jm_start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("starting JobManager session (id=",$session->ID,")") if $self->{DEBUG};
  $self->{JOB_MANAGER_SESSION_ID} = $session->ID;
  $kernel->delay_set('heartbeat',60) if $self->{KEEPALIVE};
}

sub _jm_stop
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("stopping JobManager session (id=",$session->ID,")") if $self->{DEBUG};
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

  # Check if we can start the job now, or whether we need to wait
  if ( $self->{NJOBS} && scalar(keys %{$self->{JOBS_RUNNING}}) >= $self->{NJOBS} )
  {
    $kernel->delay_set('job_queued',0.3);
    return;
  }

  # Get the job from the queue
  my ($priority,$id,$job) = $self->{JOB_QUEUE}->dequeue_next();

  # Validate the job
  # FIXME:  Should we really ignore this?
  if ( !$job )
  {
    $kernel->delay_set('job_queued',0.1);
    return;
  }

  # Start the job and record the PID
  my $wheelid = $self->{_child}->run(@{$job->{CMD}});
  $job->{PID} = $self->{_child}->wheel($wheelid)->PID;
  
  # Other variables we add to the job
  $job->{_start} = &mytimeofday();
  $job->{_cmdname} = $job->{CMD}[0];
  $job->{_cmdname} =~ s|.*/||;

  # Store the job in the package global and our running catalogue
  $PAYLOADS{$wheelid} = $job;
  $self->{JOBS_RUNNING}{$wheelid} = $job->{PID};

  # Handle the timeout.  We temporarily store some "private" keys to
  # the job hash.
  if ( exists $job->{TIMEOUT} && defined $job->{TIMEOUT} )
  {
    my $timer_id = $kernel->delay_set('timeout',$job->{TIMEOUT},$wheelid);
    $job->{_timer_id} = $timer_id;
    $job->{_timeout_grace} = exists $job->{TIMEOUT_GRACE} ? $job->{TIMEOUT_GRACE} : 3;
    $job->{_signals} = [ qw / 1 15 9 / ];
  }

  # A closure to clean up after the job is finished
  $job->{_cleanup} = sub { $self->_cleanup(@_) };

  # Whether or not we keep the output in memory
  if ( exists $job->{KEEP_OUTPUT} && $job->{KEEP_OUTPUT} ) {
      $job->{_keep_output} = 1;
      $job->{STDOUT} = "";
      $job->{STDERR} = "";
  }

  # Whether or not we prefix the output
  if (exists $job->{LOGPREFIX} && $job->{LOGPREFIX}) {
      $job->{_logprefix} = 1;
  }

  # Add start line to log
  if (exists $job->{LOGFILE})
  {
    $job->{_logprefix} = 1;
    open($job->{_logfh}, '>>', $job->{LOGFILE})
	or die "Couldn't open log file $job->{LOGFILE}: $!";
    my $logfh = \*{$job->{_logfh}};
    my $oldfh = select($logfh); local $| = 1; select($oldfh);
    print $logfh
	(strftime ("%Y-%m-%d %H:%M:%S", gmtime),
         " $job->{_cmdname}($job->{PID}): Executing: @{$job->{CMD}}\n");
  } 
  else
  {
    open($job->{_logfh}, '>&', \*STDOUT);
  }
}

# Cleanup actions.  Only call when completely done with a job
sub _cleanup
{
    my ($self, $wheelid, $payload) = @_;

    # Cleanup the global and private job payload references
    delete $PAYLOADS{$wheelid};
    delete $self->{JOBS_RUNNING}{$wheelid};

    # Cleanup any timeout alramrs
    POE::Kernel->post( $self->{JOB_MANAGER_SESSION_ID}, 'maybe_clear_alarms', $payload->{_timer_id} ) 
	if $payload->{_timer_id};

    # Cleanup any private keys we stuck onto the job paylaod
    delete $payload->{$_} foreach ( qw(_start _signals _timer_id _timeout_grace 
				       _logfh _logprefix _keep_output _cmdname
				       _priority _cleanup) );
}

sub _child_stdout {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheelid = $args->{wheel};
  my $payload = $PAYLOADS{$wheelid};

  if ($payload->{_keep_output}) {
      $payload->{STDOUT} .= $args->{out}."\n";
  }

  my $logfhtmp = \*{$payload->{_logfh}};
  if ($payload->{_logprefix})
  {
    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
    print $logfhtmp "$date $payload->{_cmdname}($payload->{PID}): ";
  }
  print $logfhtmp $args->{out},"\n";
}

sub _child_stderr {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheelid = $args->{wheel};
  my $payload = $PAYLOADS{$wheelid};

  if ($payload->{_keep_output}) {
      $payload->{STDERR} .= $args->{out}."\n";
  }
}

sub _child_done {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheelid = $args->{wheel};
  my $payload = $PAYLOADS{$wheelid};

  my $finish   =  &mytimeofday();
  my $duration = $finish - $payload->{_start};

  # Set the various return values
  @$payload{qw(STATUS EXIT SIGNAL CORE STATUS_CODE)} = &runerror ($args->{rc});
  $payload->{START}    = $payload->{_start};
  $payload->{FINISH}   = $finish;
  $payload->{DURATION} = $duration;

  # Final status line to log file
  if (exists $payload->{LOGFILE})
  {
    my $logfh = \*{$payload->{_logfh}};
    print $logfh (strftime ("%Y-%m-%d %H:%M:%S", gmtime),
      " $payload->{_cmdname}($payload->{PID}): Job exited with status code",
      " $payload->{STATUS} ($payload->{STATUS_CODE})",
      sprintf(" after %.3f seconds", $duration), "\n" );
    close $logfh;
  }

  # Cleanup payload reference and timeout alarms
  $payload->{_cleanup}->( $wheelid, $payload );

  # _action callback
  if ( defined($payload->{_action}) )
  {
    my $action = delete $payload->{_action};  # first remove the reference
    $action->( $payload );                    # then call the action
  }
}

sub _child_died {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheelid = $args->{wheel};
  my $payload = $PAYLOADS{$wheelid};

  # pipe this event into _child_done event handler
  _child_done( $self, $args );
}

sub _child_error {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheelid = $args->{wheel};
  my $payload = $PAYLOADS{$wheelid};

  # pipe this internal error to stderr event handler
  chomp $args->{error}; 
  $args->{out} = 'child_error: [' . $args->{err} . '] ' . $args->{error};
  _child_stderr( $self, $args );
}

# Add a new command to the job list.  The command will only be started
# if the current limit of available job slots is not exceeded; otherwise
# the job simply gets added to the list of processes to start later on.
#
# The following optional job hash keys affect the behavior of the job
#   PRIORITY      priority for starting a job; lower number is higher priority
#   TIMEOUT       seconds after which the job will be timed out
#   TIMEOUT_GRACE seconds between attempts to kill a timed-out job
#   LOGFILE       file to which STDOUT should be written
#   LOGPREFIX     writes a timestamp and command name before each output line if true
#   KEEP_OUTPUT   saves output to job hash, keyed as STDOUT and STDERR
#
# The following keys will always be added to the job hash upon
# completion.  Do not set these keys beforehand in the job hash, or
# they will be overwritten.
#   CMD           arrayref of the job command and options
#   PID           the process id the job ran as
#   START         timestamp of the job start time
#   FINISH        timestamp of the job finish time
#   DURATION      duration of the job in seconds
#   STATUS        the exit code of the command, or a string indicating a signal or other problem
#   STATUS_CODE   unchanged exit code of the command; see perlvar for $?
#   EXIT          the exit code of the command (only) 
#   SIGNAL        the signal number the command received, if signaled
#   CORE          true if there was a core dump
#
# The following keys will optionally be added to the job hash,
# depending on what happened to the job:
#   TIMED_OUT     timestamp at which point the job timed-out
#   STDOUT        standard output of the command, if KEEP_OUTPUT was set
#   STDERR        standard error of the command, if KEEP_OUTPUT was set
sub addJob
{
  my ($self, $action, $jobargs, @cmd) = @_;
  my $job = { CMD => [ @cmd ],
	      PID => 0,
	      _action => $action,
	      %{$jobargs || {}} };

  # Default priority ideally the lowest possible in order to give the
  # user the option to make certain jobs high priority.
  $job->{_priority} = exists $job->{PRIORITY} ? $job->{PRIORITY} : POSIX::DBL_MAX;

  $self->{JOB_QUEUE}->enqueue($job->{_priority} ,$job);
  POE::Kernel->post($self->{JOB_MANAGER_SESSION_ID}, 'job_queued');
}



# Event to kill a job
sub timeout
{
  my ( $self, $kernel, $wheelid ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $payload = $PAYLOADS{$wheelid};
  return unless defined $payload;
  my $signal = shift @{$payload->{_signals}};
  return unless $signal; # we couldn't kill -9 the job?

  my $wheel = $self->{_child}->wheel($wheelid);
  $payload->{TIMED_OUT} = &mytimeofday();
  $wheel->kill( $signal );
  my $timeout = $payload->{_timeout_grace};
  $kernel->delay_set( 'timeout', $timeout, $wheelid );
}

# Terminate the children (yikes!)
sub killAllJobs
{
  my $self = shift;

  foreach my $wheelID ( keys %{$self->{JOB_PAYLOADS}} )
  {
    POE::Kernel->post($self->{JOB_MANAGER_SESSION_ID}, 'timeout', $wheelID);
  }
}

# Waits for the queue to drain and makes a callback when it does
sub whenQueueDrained
{
  my ($self, $callback) = @_;
  $callback = sub {} unless $callback;
  push @{$self->{JOB_QUEUE_DRAINED_CALLBACKS}}, $callback;
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
  while ( my $callback = pop @{$self->{JOB_QUEUE_DRAINED_CALLBACKS}} )
  {
    &$callback() if $callback;
    $self->{_DOINGSOMETHING}--;
  }
}

sub jobsRemaining()
{
  my $self = shift;
  return $self->jobsActive() + $self->jobsQueued();
}

sub jobsQueued()
{
    my $self = shift;
    return $self->{JOB_QUEUE}->get_item_count();
}

sub jobsActive()
{
    my $self = shift;
    return scalar(keys %{$self->{JOB_PAYLOADS}});
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
