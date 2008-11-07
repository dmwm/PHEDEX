package PHEDEX::BlockLatency::SQL;

=head1 NAME

PHEDEX::BlockLatency::SQL

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It is not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

SQL calls for interacting with t_log_block_latency, a table for
logging the time it takes blocks to complete at a node

=head1 METHODS

=over

=item mergeLogBlockLatency(%args)

Updates the t_log_block_latency table using current data in
t_dps_block_destination, t_xfer_request and t_xfer_replica.  Keeps
track of latency up to the time the block is first completed, after
which any changes to the block (e.g. file retransferred) are not
accounted for.  Keeps track of block suspension time and subtracts
that from the total latency.

This method can be run asynchronously, but it makes little sense to
run it any faster than BlockAllocator, since the state from that agent
is used to determine important events such as suspension and block
completion.  On the other hand, if it is run slower than
BlockAllocator it will miss events.  For this reason it is run after
BlockAllocator completes.

Returns an array containing the number of rows updated by each
statement in the subroutine.

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use PHEDEX::Core::Timing;
use PHEDEX::Core::Logging;

use Carp;

our @EXPORT = qw( );

our %params =
	(
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
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

#-------------------------------------------------------------------------------
sub mergeLogBlockLatency
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n,@r);

    $p{':now'} = $h{NOW} || &mytimeofday();

    # delete log of unfinished blocks which are no longer destined.
    # this will also clear anonymous block statistics (l.block = NULL)
    # for unfinished blocks
    $sql = qq{
	delete from t_log_block_latency l
	 where l.last_replica is null and 
	 not exists
	 ( select 1 from t_dps_block_dest bd
	    where bd.destination = l.destination
	      and bd.block = l.block ) };

    ($q, $n) = execute_sql( $self, $sql );
    push @r, $n;

    # Create or update unfinished blocks
    $sql = qq{
	merge into t_log_block_latency l
	using
	  (select bd.destination, b.id block, b.files, b.bytes, b.time_create block_create, bd.priority,
	          bd.is_custodial, bd.time_subscription, bd.time_create, bd.time_complete time_done,
	          nvl2(bd.time_suspend_until, :now, NULL) this_suspend
	     from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	    where b.is_open = 'n'
            and bd.time_complete is null
	   ) d
	on (d.destination = l.destination
            and d.block = l.block
            and d.time_subscription = l.time_subscription
            and l.last_replica is null)
	when matched then
          update set l.priority = d.priority,
		     l.suspend_time = nvl(l.suspend_time,0) + nvl(:now - l.last_suspend,0),
                     l.last_suspend = d.this_suspend,
	             l.time_update = :now
	when not matched then
          insert (l.time_update, l.destination, l.block, l.files, l.bytes, l.block_create,
		  l.priority, l.is_custodial, l.time_subscription, l.last_suspend, l.suspend_time)
          values (:now, d.destination, d.block, d.files, d.bytes, d.block_create,
		  d.priority, d.is_custodial, d.time_subscription, d.this_suspend, 0)
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Performance note:
    # These merge...update statements are about 25x more efficient than the equivilent (but shorter)
    # update t_log_block_latency set X = (select ...) where Y is null

    # Update first request
    $sql = qq{
	merge into t_log_block_latency u
	using
          (select l.time_subscription, l.destination, l.block, min(xq.time_create) first_request
             from t_xfer_request xq
             join t_xfer_file xf on xf.id = xq.fileid
             join t_log_block_latency l on l.destination = xq.destination
                                       and l.block = xf.inblock
            where l.first_request is null
            group by l.time_subscription, l.destination, l.block) d
        on (u.time_subscription = d.time_subscription
            and u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
	             u.first_request = d.first_request
    };
	
    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;
	             
    # Update first replica
    $sql = qq{
	merge into t_log_block_latency u
	using
          (select l.time_subscription, l.destination, l.block, min(xr.time_create) first_replica
             from t_xfer_replica xr
             join t_xfer_file xf on xf.id = xr.fileid
             join t_log_block_latency l on l.destination = xr.node
                                       and l.block = xf.inblock
            where l.first_replica is null
            group by l.time_subscription, l.destination, l.block) d
        on (u.time_subscription = d.time_subscription
            and u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
	             u.first_replica = d.first_replica
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Update last replica and latency total for finished blocks
    # The formula is t_last_replica - t_soonest_possible_start - t_suspended
    $sql = qq{
	merge into t_log_block_latency u
	using
          (select l.time_subscription, l.destination, l.block, max(xr.time_create) last_replica
             from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	     join t_xfer_replica xr on xr.node = bd.destination
	     join t_xfer_file xf on xf.id = xr.fileid and xf.inblock = bd.block
             join t_log_block_latency l on l.block = bd.block
	                               and l.destination = bd.destination
	                               and l.time_subscription = bd.time_subscription
	     where b.is_open = 'n'
               and bd.time_complete is not null
	       and l.last_replica is null
             group by l.time_subscription, l.destination, l.block) d
        on (u.time_subscription = d.time_subscription
            and u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
	             u.last_replica = d.last_replica,
                     u.last_suspend = NULL,
                     u.latency = d.last_replica - 
	                         case when u.block_create > u.time_subscription then u.block_create
                                 else u.time_subscription end
			          - u.suspend_time
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Update current latency totals for unfinished blocks
    # The formula is now - t_soonest_possible_start - t_suspended
    $sql = qq{
	update t_log_block_latency l
	   set l.time_update = :now, 
               l.latency = :now - 
	                   case when l.block_create > l.time_subscription then l.block_create
                           else l.time_subscription end
		           - l.suspend_time
         where l.last_replica is null
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    return @r;
}

1;
