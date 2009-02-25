package PHEDEX::Transfer::Backend::Queue;

=head1 NAME

PHEDEX::Transfer::Backend::Queue - Polling or monitoring of a transfer queue.

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

our %params =
	(
	  Q_MANAGER  => undef,		# A transfer queue manager object
	  Q_INTERVAL => 60,		# Queue polling interval
	  J_INTERVAL =>  5,		# Job polling interval
	);
our %ro_params =
	(
	  QUEUE    => undef,		# A POE::Queue of transfers...
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(@_) if ref($proto);
  my %args = (@_);
  map { $$self{$_} = $args{$_} || $params{$_} } keys %params;

  $self->{QUEUE} = POE::Queue::Array->new();
  bless $self, $class;

  POE::Session->create
	(
	  object_states =>
	  [
	    $self =>
	    {
	      _start	 => 'start',
	      poll_queue => 'poll_queue',
	      poll_job   => 'poll_job',
	      report_job => 'report_job',
            },
          ],
	);

# Sanity checks:
  $self->{J_INTERVAL}>0 or die "J_INTERVAL too small:",$self->{J_INTERVAL},"\n";
  $self->{Q_INTERVAL}>0 or die "Q_INTERVAL too small:",$self->{Q_INTERVAL},"\n";
  ref($self->{Q_MANAGER}) or die "No sensible Q_MANAGER object defined...?\n";
  foreach ( qw / ListQueue StatePriority ListJob / )
  {
    $self->{Q_MANAGER}->can($_) or die "Q_MANAGER cannot \"$_\"?\n";
  }

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

sub start
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  print scalar localtime,": $self is starting...\n";
  $kernel->yield('poll_queue');
  $kernel->delay_set('poll_job',$self->{J_INTERVAL});
}

sub poll_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($job,$jobs,$priority);

  print scalar localtime,": $self: poll_queue...\n";
  $jobs = $self->{Q_MANAGER}->ListQueue;
# print map { $_,': ',$jobs->{$_},"\n" } keys %{$jobs};

  foreach $job ( @jobs )
  {
    $priority = $self->{Q_MANAGER}->StatePriority($jobs->{STATE});
    if ( ! $priority )
    {
#     I can forget about these jobs...
      $kernel->yield('report_job',($job->{ID}));
      next;
    }
    if ( ! exists($self->{jobs}{$job->{ID}}) )
    {
#     Queue this job for monitoring...
      $self->{QUEUE}->enqueue($priority,$job->{ID});
      $self->{jobs}{$job}{Queued} = time;
      $self->{jobs}{$job}{ID} = $job;
      print "Queued $job->{ID} at priority $priority(",$job->{STATE},")\n";
      next;
    }
  }
  $kernel->delay_set('poll_queue', $self->{Q_INTERVAL});
}


sub poll_job
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($state,$priority,$id,$job);

# print scalar localtime,": $self: poll_job...\n";
  ($priority,$id,$job) = $self->{QUEUE}->dequeue_next;
  goto DONE unless $id;

# print "$job: priority=$priority\n";

  my $last = $self->{jobs}{$job}{ReportedAt} || $self->{jobs}{$job}{Queued};
  $state = $self->{Q_MANAGER}->ListJob($job);
  $self->{jobs}{$job}{State} = $state;
  $self->{jobs}{$job}{ReportedAt} = time;

  print scalar localtime time, " $job: ETC=",$state->{ETC},' STATE=',$state->{State},' ',
         join(', ',
              map { $_.':'.$state->{States}{$_} }
              sort keys %{$state->{States}}
             ),
         "\n";

  if ( $state->{State} =~ m%^Finished% ||
       $state->{State} =~ m%^Failed% ||
       $state->{State} =~ m%^Canceled% )
  {
    $kernel->yield('report_job',($job));
  }
  else
  {
    $state->{ETC} = 100 if $state->{ETC} < 1;
    $priority = time + $state->{ETC};
    $priority = int($priority/3600);
    $priority = 2 if $priority < 2;
    $self->{QUEUE}->enqueue( $priority, $job );
  }

DONE:
  $kernel->delay_set('poll_job', $self->{J_INTERVAL});
}

sub report_job
{
  my ( $self, $kernel, $job ) = @_[ OBJECT, KERNEL, ARG0 ];
  print "Job $job has ended...\n";

# Now I should take detailed action on any errors...

  delete $self->{jobs}{$job};
}

1;
