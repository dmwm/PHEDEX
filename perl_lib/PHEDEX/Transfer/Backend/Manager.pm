package PHEDEX::Transfer::Backend::Manager;

=head1 NAME

PHEDEX::Transfer::Backend::Manager - Transfer a number of files.

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
use Time::HiRes qw / time /;
use POE::Session;
use POE::Queue::Array;
use PHEDEX::Transfer::Backend::Job;
use PHEDEX::Transfer::Backend::File;

our %params =
	(
	  Q_MONITOR		=> undef, # Transfer queue monitor object
	  Q_INTERFACE		=> undef, # Transfer queue interface object
	  FILES_PER_JOB		=> 23,    # Queue polling interval
	  RETRIES_PER_FILE	=> 3,     # Job polling interval
	  JOB_POLL_INTERVAL	=> 10,    # Period to check for more jobs
	  FILE_POLL_INTERVAL	=> 10,    # Period to wait for more files
	  FILE_FLUSH_INTERVAL	=> 600,   # Force flush after this time
	  EXIT_WHEN_EMPTY	=> 0,     # Or continue waiting for files?
	  EXIT_GRACE_PERIOD	=> 300,   # Time to wait for new stuff?
	  TEMP_DIR		=> undef, # Directory for temporary files
	  JOB_TRACE_DIR		=> undef, # Directory for detailed job reports
	  FILE_TRACE_DIR	=> undef, # Directory for detailed file reports
	  MAX_PARALLEL_JOBS	=> 10,    # Max. # of jobs to run at a time
	  RETRY_MIN_FILE_GROUP	=>   3,   # Don't retry a single file in a job
	  RETRY_MAX_AGE		=> 900,   # Retry anyway after this long...
	  SERVICE		=> undef, # Glite service for jobs
	  ME			=> 'Mgr', # Arbitrary name for this object

	  SUSPEND_SUBMISSION	=>  0,	  # Allows me to suspend job submission
	);
our %ro_params =
	(
	  FILE_QUEUE	    => undef,	# A POE::Queue of files to transfer...
	  FILE_FLUSH_TIME   => time,	# Set the clock for flushing the queue
	  JOB_COUNT	    => 0,	# Count the number of active jobs
	);
our $dbg=1;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map { 
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  map {
        $self->{$_} = defined($args{$_}) ? delete $args{$_} : $ro_params{$_}
      } keys %ro_params;

  bless $self, $class;

  POE::Session->create
	(
	  object_states =>
	  [
	    $self =>
	    {
	      check_file_queue	=> 'check_file_queue',
	      check_job_queue	=> 'check_job_queue',
	      submit_job	=> 'submit_job',
	      file_state	=> 'file_state',
	      job_state		=> 'job_state',
	      shoot_myself	=> 'shoot_myself',

	      _start		=> '_start',
	      _stop		=> '_stop',
	      _default		=> '_default',
            },
          ],
	);

  $self->{FILE_QUEUE} = POE::Queue::Array->new();
  $self->{FILE_FLUSH_TIME} = time;

# Sanity checks:
  ref($self->{Q_INTERFACE}) or die "No sensible Q_INTERFACE object defined.\n";

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
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
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
  $kernel->yield('check_job_queue');
  $kernel->yield('check_file_queue') if $self->{FILE_POLL_INTERVAL};
}

sub select_for_retry
{
  my $f = $_[0];
  return 0 unless $f->Retries;
  return 0 unless $f->Timestamp + $f->RetryMaxAge > time;
  return 1;
}

sub check_job_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($items,$nfetch,$ttflush,@h);

  $ttflush = $self->{FILE_FLUSH_TIME} + $self->{FILE_FLUSH_INTERVAL} - time;
  $items   = $self->{FILE_QUEUE}->get_item_count;
  $nfetch  = $self->{FILES_PER_JOB};

  if ( $items && ( $self->{JOB_COUNT} < $self->{MAX_PARALLEL_JOBS} ) )
  {
#   If there are plenty of files to fetch, I look to see if I should retry
#   any first. That means checking that I have enough files queued for retry,
#   or that the files waiting to be retried have been waiting too long.
#   If there are still slots left in the job, I pick up other files to fill
#   the job.
    if ( $items >= $nfetch || ( $ttflush <= 0 ) )
    {
      if ( $items >= $nfetch )
      {
#       Fetch files for retry, but only if I have enough!
        @h = $self->{FILE_QUEUE}->peek_items( \&select_for_retry, $nfetch);
        if ( scalar @h >= $self->{RETRY_MIN_FILE_GROUP} )
        {
          @h = $self->{FILE_QUEUE}->remove_items( \&select_for_retry, $nfetch);
          $nfetch -= scalar @h;
        }
      }
      else
      {
#       Time to flush the queue, take everything!
        print $self->Hdr,"flushing $items files from the queue\n";
        $nfetch = $items;
      }

#     @h may already have entries (retryables!), and $nfetch will have been
#     adjusted accordingly
      if ( $nfetch )
      { push @h, $self->{FILE_QUEUE}->remove_items( sub{1}, $nfetch ); }
      @h = map { $_->[2] } @h;
      $kernel->yield('submit_job',\@h);
      $self->{JOB_COUNT}++;
      $self->{FILE_FLUSH_TIME} = time;
    }
  }

  if ( $self->{FILE_QUEUE}->get_item_count  &&
       ( $self->{JOB_COUNT} < $self->{MAX_PARALLEL_JOBS} )
     )
  {
#   come back for more immediately!
    $kernel->yield('check_job_queue');
  }
  else
  {
#   No rush, come back later...
    $kernel->delay_set('check_job_queue', $self->{JOB_POLL_INTERVAL});
  }
}

sub check_file_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($items,$nfetch,$ttflush);

  goto DONE if ( $self->{JOB_COUNT} >= $self->{MAX_PARALLEL_JOBS} );
# $self->{FILE_FLUSH_TIME} = time unless $self->{FILE_FLUSH_TIME};
  $ttflush = $self->{FILE_FLUSH_TIME} + $self->{FILE_FLUSH_INTERVAL} - time;
  $items   = $self->{FILE_QUEUE}->get_item_count;
  $nfetch  = $self->{FILES_PER_JOB};

  while ( $items >= $nfetch || $ttflush <= 0 )
  {
    $self->{FILE_FLUSH_TIME} = time;
    last unless $items;
    $nfetch = $items if $nfetch > $items;
    my @h = map { $_->[2] } 
            $self->{FILE_QUEUE}->remove_items( sub{1}, $nfetch );
    $items -= $nfetch;
    print "Queueing submission of $nfetch files, $items left\n";
    $kernel->yield('submit_job',\@h);
    $self->{JOB_COUNT}++;
    last if ( $self->{JOB_COUNT} >= $self->{MAX_PARALLEL_JOBS} );
  }

DONE:
  $kernel->delay_set('check_file_queue', $self->{FILE_POLL_INTERVAL})
}

sub submit_job
{
  my ( $self, $kernel, $session, $files ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my $job;

  print $self->Hdr,'submit_job: ',
	$self->{JOB_COUNT},' of ',
	$self->{MAX_PARALLEL_JOBS},"\n";
  print $self->Hdr,"Submit job for:\n",
	map { ' ' . $_->Source . "\n" } @{$files};

  $job = PHEDEX::Transfer::Backend::Job->new();
  $job->Service( $self->{SERVICE} );
  $job->Files( @{$files} );
  $job->Prepare;
  my $result = $self->{Q_INTERFACE}->Submit( $job );
  if ( $result->{ERROR} )
  {
    $self->Warn($result->{ERROR});
    $job->Log($result->{ERROR});
    $job->Log("RAW_OUTPUT:\n",@{$result->{RAW_OUTPUT}});
    $job->ID( $job->ID || 'undefined_at_' . time );
    $kernel->yield('job_state',[ $job ]);
    return;
  }

  if ( $self->{Q_MONITOR} )
  {
    my $job_postback = $session->postback( 'job_state', $job );
    $job->JOB_POSTBACK( $job_postback );

    my $file_postback = $session->postback( 'file_state', $job );
    $job->FILE_POSTBACK( $file_postback );

    $self->{Q_MONITOR}->QueueJob( $job, $job->Priority );
  }
}

sub job_state
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my $job = $arg0->[0];
  print $self->Hdr,$job->ID," has ended\n";
  $self->{JOB_COUNT}--;

  my ($fh,$close_it);
  if ( $self->{JOB_TRACE_DIR} )
  {
    my $logfile = $self->{JOB_TRACE_DIR} . '/job-' . $job->ID . '.log';
    $close_it = 1;
    open $fh, ">$logfile" or do
    {
      warn "Cannot open $logfile: using STDOUT\n";
      $fh = *STDOUT;
      $close_it = 0;
    };
  }
  else { $fh = *STDOUT; }
  print $fh "#-------------------------------------------------------------\n",
             scalar localtime time, ' Log for ',$job->ID,"\n",
             $job->Log,
             scalar localtime time," Log ends\n",
            "#-------------------------------------------------------------\n";
  close $fh if $close_it;

  if ( $self->{FILE_TRACE_DIR} )
  {
    foreach ( values %{$job->Files} )
    {
      $_->WriteLog($self->{FILE_TRACE_DIR});
    }
  }

  my $fq = $self->{FILE_QUEUE}->get_item_count;
  print $self->Hdr,"Job count now: ",$self->{JOB_COUNT},
                   ' Files remaining:',$fq,
                   "\n";

  if ( !$self->{JOB_COUNT} && !$fq && $self->{EXIT_WHEN_EMPTY} )
  {
#   Allow other things to happen first!
    my $shoot= $self->{EXIT_GRACE_PERIOD} || 300;
    print $self->Hdr,"shoot myself in $shoot seconds\n";
    $kernel->delay_set('shoot_myself',$shoot);
  }
}

sub shoot_myself
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];

# Win a reprieve if something else comes along!
  return if ( ! $self->{EXIT_WHEN_EMPTY} ||
		$self->{JOB_COUNT}	 ||
		$self->{FILE_QUEUE}->get_item_count
	    );

  print $self->Hdr,"shooting myself...\n";

  if ( $self->{Q_MONITOR} )
  {
    $kernel->post( $self->{Q_MONITOR}{SESSION_ID}, 'shoot_myself' );
    undef $self->{Q_MONITOR};
  }

# clear all alarms you might have set
  $kernel->alarm_remove_all();

# get rid of external ref count
  my $i=1;
  while ( $i > 0 )
  { $i = $kernel->refcount_decrement( $session->ID, 'anon_event' ); }
  return;
}

sub file_state
{
  my ( $self, $kernel, $arg0, $arg1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my ($job,$file,$old_state,$details);
  $job       = $arg0->[0];
  $file      = $arg1->[0];
  $old_state = $arg1->[1];
  $details   = $arg1->[2];

  if ( ! ref($file) )
  {
    $DB::single=1;
  }

  my $exit_states = $file->ExitStates || \%PHEDEX::Transfer::Backend::File::exit_states;
  if ( $exit_states->{$file->State} == 2 )
  {
    if ( $file->RETRY )
    {
      print $self->Hdr,"Requeue ",$file->Source,"\n";
      $file->RetryMaxAge($self->{RETRY_MAX_AGE});
      $file->Nice(4);
      $self->QueueFile( $file );
    }
    else
    {
      print $self->Hdr,'Maximum retries exceeded for ',$file->Destination,"\n";
    }
  }

# This is to trap a bizarre error seen once, but that shouldn't happen...
  defined $file or $DB::single=1;
  defined $file->State or $DB::single=1;
  my $a = $file->ExitStates; defined $a or $DB::single=1;
  my $aa = $a->{$file->State}; defined $aa or $DB::single=1;

  return unless defined($file->State);
  if ( $exit_states->{$file->State} == 1 ||
     ( $exit_states->{$file->State} == 2 && !$file->Retry ) )
  {
    $file->WriteLog($self->{FILE_TRACE_DIR}) if $self->{FILE_TRACE_DIR};
  }
}

sub QueueFile
{
  my $self = shift;
  my $h = shift;

  $h->Timeout(0)     unless $h->Timeout;
  $h->Priority(1000) unless $h->Priority;
  $h->MaxTries(2)    unless $h->MaxTries;

  print $self->Hdr,"Queueing ",$h->Source," -> ",$h->Destination,"\n";
  $self->{FILE_QUEUE}->enqueue($h->Priority,$h);
  if ( $self->{Q_MONITOR} )
  {
    $self->{Q_MONITOR}->WorkStats('FILES',$h->Destination,'undefined');
  }
}

sub QueueCopyjob
{
  my ($self,$copyjob,%h) = @_;

  open COPYJOB, "<$copyjob" or die "open $copyjob: $!\n";
  while ( <COPYJOB> )
  {
    m%^\s*(\S+)\s+(\S+)\s*$% or
	die "Format of \"$_\" unrecognised, aborting!\n";
    my $f = PHEDEX::Transfer::Backend::File->new
		(
		  SOURCE	=>   $1,
		  DESTINATION	=>   $2,
		  MAX_TRIES	=>    3,
		  TIMEOUT	=>    0,
		  PRIORITY	=> 1000,
		  %h,
		);
    $self->QueueFile( $f );
  }
}

1;
