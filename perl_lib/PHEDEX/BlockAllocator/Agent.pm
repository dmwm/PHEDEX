package PHEDEX::BlockAllocator::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockAllocator::Core', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE    => undef,           # my TMDB nodename
    	  DBCONFIG  => undef,		# Database configuration file
	  WAITTIME  => 300,		# Agent cycle time
	  DUMMY     => 0,		# Dummy the updates
	  ONCE      => 0,		# Quit after one run

	  BLOCK_LIMIT => 5000,		# Number of blocks to process at once (memory safeguard)
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(%params,@_);

  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

# Update statistics.
sub idle
{
  my ($self, @pending) = @_;
  my $dbh = undef;

  my $t0 = time();

  eval
  {
    $dbh = $self->connectAgent();
    my $now = &mytimeofday ();

    my @stats0 = $self->addBlockSubscriptions($now);
    my @stats1 = $self->blockSubscriptions($now);
    my @stats2 = $self->datasetSubscriptions($now);
    my @stats3 = $self->suspendBlockSubscriptions($now);
    my @stats4 = $self->allocate($now);
    my @stats5 = $self->blockDestinations($now);
    my @stats6 = $self->deleteSubscriptionParams($now);
    my @blockLatencyStats = $self->mergeStatusBlockLatency();
    $dbh->commit();
    if (grep $_->[1] != 0,  @stats0, @stats1, @stats2, @stats3, @stats4, @stats5, @stats6) {
	$self->printStats('allocation stats', @stats0, @stats1, @stats2, @stats3, @stats4, @stats5, @stats6);
    } else {
	$self->Logmsg('nothing to do');
    }
    $self->printStats('Merged block-level latency information', @blockLatencyStats );
};
    do { chomp ($@); $self->Alert ("database error: $@");
         eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();

    $self->doStop() if $self->{ONCE};
}

sub IsInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / MYNODE DROPDIR DBCONFIG / ],
                );
  return $errors;
}

1;



=pod

=head1 NAME

BlockAllocator - allocate blocks for transfer to a destination

=head1 DESCRIPTION

The BlockAllocator agent is the bridge between a data subscription,
which is a user-created and modifiable instruction for data to
transfer to a destination, and a block destination, which is what
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> really uses to
initate the file-transfer process. All subscriptions are tracked 
internally at block-level; the agent takes care of creating the appropriate
block-level subscriptions when a dataset-level subscription is created,
and keeps their parameters in sync.
It also turns block-level subscriptions into block destinations and keeps
block subscritpion / block destination parameters (e.g. priority, suspension,
user group) in sync.

It also monitors subscriptions in order to mark them as "complete" or
"done".  "Complete" subscriptions have all of their files transferred
to the destination.  "Done" subscriptions are "complete" I<and> only
involve closed blocks, so that it is expected that work on the
subscription is done forever.

Finally, BlockAllocator keeps track of block latency history using the
L<BlockLatency|PHEDEX::BlockLatency::SQL> module.

=head1 TABLES USED

=over

=item L<t_dps_subs_dataset|Schema::OracleCoreSubscription/t_dps_subs_dataset>
=item L<t_dps_subs_block|Schema::OracleCoreSubscription/t_dps_subs_block>                                                                                
=item L<t_dps_subs_param|Schema::OracleCoreSubscription/t_dps_subs_param>                                                                                

BlockAllocator reads dataset- and block-level subscriptions and their parameters,
creates new block-level subscriptions from dataset-level subscriptions,
turns them into block destinations, and updates subscriptions which
are complete or done.

=item L<t_dps_block_dest|Schema::OracleCoreBlock/t_dps_block_dest>

BlockAllocator creates block destinations, and removes block
destinations if they are no longer subscribed.  It also updates them
to keep their parameters in sync with the subscription, and to manage
their suspension state.

=item L<t_log_block_latency|Schema::OracleCoreRequest/t_log_block_latency>

BlockAllocator logs various events which can be used to calculate
varios latencies for the block.  See
L<BlockLatency|PHEDEX::BlockLatency::SQL> module for more details.

=back

=head1 COOPERATING AGENTS

=over

=item L<Data Service: Subscribe|PHEDEX::Web::API::Subscribe>

Subscribe creates subscriptions, which are turned into block
destinations by BlockAllocator.

=item L<BlockMonitor|PHEDEX::BlockMonitor::Agent>

BlockMonitor keeps track of block-level replica status, which is
needed by BlockAllocator in order to determine if a block destination
or subscription is "complete" or "done".

=item L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>

Block destinations are consumed by FileRouter, which initiates the
file transfer workflow.

=item L<BlockActivate|PHEDEX::BlockActivate::Agent>

When BlockAllocator creates a block destination for an inactive block,
BlockActivate must activate it.

=back

=head1 STATISTICS

=over

=item L<t_status_block_dest|Schema::OracleCoreStatus/t_status_block_dest>

node-level file/byte counts of destined blocks, by custodial flag and state.

=item L<t_history_dest|Schema::OracleCoreStatus/t_history_dest>

History of node-level file/byte counts of destined blocks in the
dest_files, dest_bytes, cust_dest_files, and cust_dest_bytes columns.

=back

=head1 SEE ALSO

=over

=item L<PHEDEX::BlockAllocator::Core|PHEDEX::BlockAllocator::Core>

=item L<PHEDEX::BlockAllocator::SQL|PHEDEX::BlockAllocator::SQL>

=item L<PHEDEX::BlockLatency::SQL|PHEDEX::BlockLatency::SQL>

=item L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>

=back

=cut
