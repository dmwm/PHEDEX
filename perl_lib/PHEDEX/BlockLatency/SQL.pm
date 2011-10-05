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
use base 'PHEDEX::Core::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;

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

    # If a block latency record doesn't exist for a block destination,
    # create it -- but only consider active blocks because we can't
    # calculate the latency for inactive ones.  If the record does
    # exist, update the suspension time since the latest replication 
    # as long as the block isn't complete at the destination.
    # Also update block and subs stats (files, bytes, block_close, priority)
    $sql = qq{
	merge into t_log_block_latency l
	using
	  (select bd.destination, b.id block, b.files, b.bytes, b.time_create block_create,
	          decode(b.is_open,'n',b.time_update,'y',NULL) block_close, bd.priority,
	          bd.is_custodial, bd.time_subscription, bd.time_create, bd.time_complete time_done,
	          nvl2(bd.time_suspend_until, :now, NULL) this_suspend
	     from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	     join t_dps_block_replica br on br.block = bd.block and br.node = bd.destination
	     where br.is_active = 'y'
	   ) d
	on (d.destination = l.destination
            and d.block = l.block
            and d.time_subscription = l.time_subscription)
	when matched then
          update set l.files = d.files,
	             l.bytes = d.bytes,
	             l.block_close = d.block_close,
	             l.priority = d.priority,
		     l.partial_suspend_time = nvl(l.partial_suspend_time,0) + nvl(:now - l.last_suspend,0),
                     l.last_suspend = d.this_suspend,
	             l.time_update = :now
           where l.last_replica is null
	when not matched then
          insert (l.time_update, l.destination, l.block, l.files, l.bytes, l.block_create, l.block_close,
		  l.priority, l.is_custodial, l.time_subscription, l.last_suspend, l.partial_suspend_time)
          values (:now, d.destination, d.block, d.files, d.bytes, d.block_create, d.block_close,
		  d.priority, d.is_custodial, d.time_subscription, d.this_suspend, 0)
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Performance note:
    # These merge...update statements are about 25x more efficient than the equivalent (but shorter)
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

    # Update most recent replica if the block record is not complete; if a new replica was created
    # since the previous update, add the partial suspension time since the latest replica to the total suspension time
    $sql = qq{
        merge into t_log_block_latency u
        using
          (select l.time_subscription, l.destination, l.block,
	       max(xr.time_create) latest_replica, l.partial_suspend_time
	    from t_xfer_replica xr
             join t_xfer_file xf on xf.id = xr.fileid
             join t_log_block_latency l on l.destination = xr.node
                                       and l.block = xf.inblock
            where l.first_replica is not null and l.last_replica is null
            group by l.time_subscription, l.destination, l.block, l.partial_suspend_time) d
        on (u.time_subscription = d.time_subscription
            and u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
                     u.latest_replica = d.latest_replica,
                     u.total_suspend_time = nvl(d.partial_suspend_time,0) + nvl(u.total_suspend_time,0),
	             u.partial_suspend_time=0
	    where d.latest_replica>nvl(u.latest_replica,0)
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Update last replica and latency total for finished blocks
    # The formula is t_last_replica - t_soonest_possible_start - t_suspended
    $sql = qq{
	merge into t_log_block_latency u
	using
          (select l.time_subscription, l.destination, l.block,
	       percentile_disc(0.25) within group (order by xr.time_create asc) percent25_replica,
	       percentile_disc(0.50) within group (order by xr.time_create asc) percent50_replica,
               percentile_disc(0.75) within group (order by xr.time_create asc) percent75_replica,
               percentile_disc(0.95) within group (order by xr.time_create asc) percent95_replica,
	       max(xr.time_create) last_replica
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
	             u.percent25_replica = d.percent25_replica,
	             u.percent50_replica = d.percent50_replica,
                     u.percent75_replica = d.percent75_replica,
                     u.percent95_replica = d.percent95_replica,
	             u.last_replica = d.last_replica,
                     u.last_suspend = NULL,
                     u.latency = d.last_replica - 
	                         greatest(u.block_create,u.time_subscription)
			          - u.total_suspend_time
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Update current latency totals for unfinished blocks
    # The formula is now - t_soonest_possible_start - t_suspended
    $sql = qq{
	update t_log_block_latency l
	   set l.time_update = :now, 
               l.latency = :now - 
	                   greatest(l.block_create,l.time_subscription)
		           - l.total_suspend_time - l.partial_suspend_time
         where l.last_replica is null
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    return @r;
}


#-------------------------------------------------------------------------------
sub mergeStatusFileArrive
{
    my ($self,%h) = @_;
    my ($sql,$q,$n,@r);

    $sql = qq { merge into t_status_file_arrive fl using
		    (select xtd.time_update, xt.to_node, xt.fileid,
		     xf.inblock, xf.filesize, 
		     decode(ln.is_local,'y',xt.priority/2,'n',(xt.priority-1)/2) priority,
		     xt.is_custodial, xp.time_request, xp.time_confirm time_route,
		     xt.time_assign, xte.time_update time_export, xtd.report_code
		     from t_xfer_task_harvest xth
		     join t_xfer_task xt on xt.id = xth.task
		     join t_xfer_task_export xte on xte.task = xt.id
		     join t_xfer_file xf on xf.id=xt.fileid
		     join t_xfer_task_done xtd on xtd.task = xth.task
		     left join t_xfer_path xp on xp.fileid=xt.fileid and xp.from_node=xt.from_node and xp.to_node=xt.to_node
		     join t_adm_link ln on ln.from_node=xt.from_node and ln.to_node=xt.to_node
		     join t_status_block_latency bl on bl.destination=xt.to_node and bl.block=xf.inblock
		     ) new
		  on (fl.destination = new.to_node and fl.fileid = new.fileid)
		  when matched then
		  update set
		  fl.time_update=new.time_update, fl.priority=new.priority, fl.is_custodial=new.is_custodial,
		  fl.attempts=nvl(fl.attempts,0)+1,
		  fl.time_latest_attempt=new.time_update,
		  fl.time_at_destination=decode(new.report_code,0,new.time_update,NULL)
		  where fl.time_at_destination is null
		  when not matched then
		  insert (time_update, destination, fileid, inblock, filesize, priority, is_custodial, time_request, time_route, 
			  time_assign, time_export, attempts, time_first_attempt, time_latest_attempt, time_at_destination)
		  values (new.time_update, new.to_node, new.fileid, new.inblock, new.filesize, 
			  new.priority, new.is_custodial, new.time_request, new.time_route, new.time_assign, new.time_export,
			  1, new.time_update, new.time_update, decode(new.report_code,0,new.time_update,NULL))
			  };

    ($q, $n) = execute_sql( $self, $sql );
    push @r, $n;
    
    return @r;
}

#-------------------------------------------------------------------------------
sub mergeBlockLatencyHistory
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n,@r);

    # Merge file latency information into history table for finished blocks
    $sql = qq {
	merge into t_history_file_arrive u
	    using
	    (select bl.time_subscription, fl.time_update, fl.destination, fl.fileid, fl.inblock, 
	          fl.filesize, fl.priority, fl.is_custodial, fl.time_request, fl.time_route,
	    fl.time_assign, fl.time_export, fl.attempts, fl.time_first_attempt, fl.time_latest_attempt,
	    fl.time_on_buffer, fl.time_at_destination
	    from t_status_block_latency bl join t_status_file_arrive fl on bl.block=fl.inblock and bl.destination=fl.destination
	    where bl.last_replica is not null)
	    d
	    on (u.time_subscription=d.time_subscription and
	       u.destination=d.destination and
	       u.fileid=d.fileid)
	       when not matched then
	       insert (u.time_subscription,
		       u.time_update,
		       u.destination,
		       u.fileid,
		       u.inblock,
		       u.filesize,
		       u.priority,
		       u.is_custodial,
		       u.time_request,
		       u.time_route,
		       u.time_assign,
		       u.time_export,
		       u.attempts,
		       u.time_first_attempt,
		       u.time_latest_attempt,
		       u.time_on_buffer,
		       u.time_at_destination)
	       values
	       (d.time_subscription,
		d.time_update,
		d.destination,
		d.fileid,
		d.inblock,
		d.filesize,
		d.priority,
		d.is_custodial,
		d.time_request,
		d.time_route,
		d.time_assign,
		d.time_export,
		d.attempts,
		d.time_first_attempt,
		d.time_latest_attempt,
		d.time_on_buffer,
		d.time_at_destination)
	   };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

# Merge file replica information into history table for finished blocks for files with no latency info (already at destination, or missed events)
    $sql = qq {
	merge into t_history_file_arrive u
	    using
	    (select bl.time_subscription, xr.time_create time_update, bl.destination, xr.fileid, xf.inblock, 
	          xf.filesize, xr.time_create time_at_destination
	    from t_status_block_latency bl join t_xfer_file xf on bl.block=xf.inblock
	     join t_xfer_replica xr on xr.fileid=xf.id and xr.node=bl.destination
	     left join t_status_file_arrive fl on fl.fileid=xf.id and fl.destination=xr.node
	     where bl.last_replica is not null and fl.fileid is null)
	    d
	    on (u.time_subscription=d.time_subscription and
	       u.destination=d.destination and
	       u.fileid=d.fileid)
	       when not matched then
	       insert (u.time_subscription,
		       u.time_update,
		       u.destination,
		       u.fileid,
		       u.inblock,
		       u.filesize,
		       u.time_at_destination)
	       values
	       (d.time_subscription,
		d.time_update,
		d.destination,
		d.fileid,
		d.inblock,
		d.filesize,
		d.time_at_destination)
	   };

    ($q, $n) = execute_sql( $self, $sql );
    push @r, $n;

    # Add anonymous file statistics for completed blocks (invalidated files)
    $sql = qq {
	insert into t_history_file_arrive d
	    (d.time_subscription,
                d.time_update,
                d.destination,
                d.fileid,
                d.inblock,
                d.filesize,
                d.priority,
                d.is_custodial,
                d.time_request,
                d.time_route,
                d.time_assign,
                d.time_export,
                d.attempts,
                d.time_first_attempt,
                d.time_latest_attempt,
                d.time_on_buffer,
                d.time_at_destination)
	    select bl.time_subscription, fl.time_update, fl.destination, fl.fileid, fl.inblock,
                  fl.filesize, fl.priority, fl.is_custodial, fl.time_request, fl.time_route,
            fl.time_assign, fl.time_export, fl.attempts, fl.time_first_attempt, fl.time_latest_attempt,
            fl.time_on_buffer, fl.time_at_destination
            from t_status_block_latency bl join t_status_file_arrive fl on bl.block=fl.inblock and bl.destination=fl.destination
            where bl.last_replica is not null and fl.fileid is null
    };

    ($q, $n) = execute_sql( $self, $sql );
    push @r, $n;

   

    # Merge latency information into history table for finished blocks
    $sql = qq{
	merge into t_history_block_latency u
	using
          (select bl.time_update, bl.time_subscription, bl.destination, bl.block, bl.files,
	   bl.bytes, bl.priority,
	       bl.is_custodial, bl.block_create, bl.block_close,
	       min(fl.time_request) first_request,
	       min(fl.time_at_destination) first_replica,
	       percentile_disc(0.25) within group (order by fl.time_at_destination asc) percent25_replica,
	       percentile_disc(0.50) within group (order by fl.time_at_destination asc) percent50_replica,
               percentile_disc(0.75) within group (order by fl.time_at_destination asc) percent75_replica,
               percentile_disc(0.95) within group (order by fl.time_at_destination asc) percent95_replica,
	       bl.last_replica, bl.total_suspend_time, bl.latency
		from t_status_block_latency bl
	        left join t_status_file_arrive fl on bl.destination=fl.destination and bl.block=fl.inblock
	   where bl.last_replica is not null
	   group by bl.time_update, bl.time_subscription, bl.destination, bl.block,
	    bl.files, bl.bytes, bl.priority,                                                                                      
               bl.is_custodial, bl.block_create, bl.block_close,                   
	                  bl.last_replica, bl.total_suspend_time, bl.latency
	   ) d
        on (u.time_subscription = d.time_subscription
            and u.destination = d.destination
            and u.block = d.block)
        when not matched then
	insert
	(u.time_update,u.destination,u.block,u.files,u.bytes,u.priority,u.is_custodial,u.time_subscription,
	 u.block_create,u.block_close,u.first_request,u.first_replica,u.percent25_replica,
	 u.percent50_replica,u.percent75_replica,u.percent95_replica,u.last_replica,u.total_suspend_time,
	 u.latency)
	values
	(d.time_update,d.destination,d.block,d.files,d.bytes,d.priority,d.is_custodial,d.time_subscription,              
         d.block_create,d.block_close,d.first_request,d.first_replica,d.percent25_replica,                 
         d.percent50_replica,d.percent75_replica,d.percent95_replica,d.last_replica,d.total_suspend_time, 
         d.latency) 
	
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Now clean up all we have archived (will also cascade deletion of file-level entries)
$sql = qq {
    delete from t_status_block_latency where last_replica is not null
};

($q, $n) = execute_sql( $self, $sql, %p );
push @r, $n;

    return @r;
}

sub mergeStatusBlockLatency
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n,@r);

    $p{':now'} = $h{NOW} || &mytimeofday();

    # Update statistics for existing block status latency entries:
    # update the suspension time since the latest replication 
    # as long as the block isn't complete at the destination.
    # Also update block and subs stats (files, bytes, block_close, priority)
    $sql = qq{
	merge into t_status_block_latency l
	using
	  (select bd.destination, b.id block, b.files, b.bytes, b.time_create block_create,
	          decode(b.is_open,'n',b.time_update,'y',NULL) block_close, bd.priority,
	          bd.is_custodial, nvl2(bd.time_suspend_until, :now, NULL) this_suspend
	     from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	   ) d
	on (d.destination = l.destination
            and d.block = l.block)
	when matched then
          update set l.files = d.files,
	             l.bytes = d.bytes,
	             l.block_close = d.block_close,
	             l.priority = d.priority,
		     l.partial_suspend_time = nvl(l.partial_suspend_time,0) + nvl(:now - l.last_suspend,0),
                     l.last_suspend = d.this_suspend,
	             l.time_update = :now
           where l.last_replica is null
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;
    

    # Get new block destinations which don't have a block latency status entry yet
    # Only consider active blocks, because for inactive blocks we don't have file-level information anymore

    $sql = qq{ 
	select bd.destination, b.id block, b.files, b.bytes, b.time_create block_create, decode(b.is_open,'n',b.time_update,'y',NULL) block_close,
                  bd.priority, bd.is_custodial, bd.time_subscription, nvl2(bd.time_suspend_until, :now, NULL) last_suspend
              from t_dps_block_dest bd
              join t_dps_block b on b.id = bd.block
              join t_dps_block_replica br on br.block = bd.block and br.node = bd.destination
              left join t_status_block_latency bl on bl.destination=br.node and bl.block=br.block
              where br.is_active = 'y' and bl.block is null and bd.time_complete is null 
	  };

    ($q,$n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    my $blocksql = qq{
	insert into t_status_block_latency 
	    (time_update, destination, block, files, bytes, block_create, block_close,
                  priority, is_custodial, time_subscription, last_suspend)
	    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	};
    
    my %bargs;
    my %fargs;

    my $filesql = qq {
	insert into t_status_file_arrive
	    (time_update, destination, fileid, inblock, filesize, time_at_destination)
	    select ?, xr.node, xr.fileid, xf.inblock, xf.filesize, xr.time_create
	        from t_xfer_replica xr join t_xfer_file xf on xr.fileid=xf.id
		where xr.node = ? and xf.inblock = ?
	};
	    

    my $brow;
    while ($brow = $q->fetchrow_hashref()) {
	my $n = 1;
	push(@{$bargs{$n++}}, $p{':now'});
	push(@{$bargs{$n++}}, $brow->{DESTINATION});
	push(@{$bargs{$n++}}, $brow->{BLOCK});
	push(@{$bargs{$n++}}, $brow->{FILES});
	push(@{$bargs{$n++}}, $brow->{BYTES});
	push(@{$bargs{$n++}}, $brow->{BLOCK_CREATE});
	push(@{$bargs{$n++}}, $brow->{BLOCK_CLOSE});
	push(@{$bargs{$n++}}, $brow->{PRIORITY});
	push(@{$bargs{$n++}}, $brow->{IS_CUSTODIAL});
	push(@{$bargs{$n++}}, $brow->{TIME_SUBSCRIPTION});
	push(@{$bargs{$n++}}, $brow->{LAST_SUSPEND});
	my $nf = 1;
	push(@{$fargs{$nf++}}, $p{':now'});
        push(@{$fargs{$nf++}}, $brow->{DESTINATION});
	push(@{$fargs{$nf++}}, $brow->{BLOCK});
    }

    my @rv = &dbexec($self->{DBH}, $blocksql, %bargs) if %bargs;
    my @rv2 = &dbexec($self->{DBH}, $filesql, %fargs) if %fargs;
  
    # Update most recent replica if the block record is not complete; if a new replica was created
    # since the previous update, add the partial suspension time since the latest replica to the total suspension time
    $sql = qq{
        merge into t_status_block_latency u
        using
          (select l.destination, l.block,
	       max(fl.time_at_destination) latest_replica, l.partial_suspend_time
	    from t_status_file_arrive fl
              join t_status_block_latency l on l.destination = fl.destination
	                                    and l.block = fl.inblock
            where l.last_replica is null
            group by l.destination, l.block, l.partial_suspend_time) d
        on (u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
                     u.latest_replica = d.latest_replica,
                     u.total_suspend_time = nvl(d.partial_suspend_time,0) + nvl(u.total_suspend_time,0),
	             u.partial_suspend_time=0
	    where d.latest_replica>nvl(u.latest_replica,0)
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;
   
    # Update last replica and latency total for finished blocks
    # The formula is t_last_replica - t_soonest_possible_start - t_suspended
    $sql = qq{
	merge into t_status_block_latency u
	using
          (select l.destination, l.block,
	       max(fl.time_at_destination) last_replica
             from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	     join t_status_block_latency l on l.block = bd.block
	                               and l.destination = bd.destination
	     join t_status_file_arrive fl on fl.inblock=l.block
	                               and fl.destination = l.destination
	     where b.is_open = 'n'
               and bd.time_complete is not null
	       and l.last_replica is null
             group by l.destination, l.block) d
        on (u.destination = d.destination
            and u.block = d.block)
        when matched then
          update set u.time_update = :now,
	             u.latest_replica = NULL,
	             u.last_replica = d.last_replica,
                     u.last_suspend = NULL,
	             u.partial_suspend_time = NULL,
                     u.latency = d.last_replica - 
	                         greatest(u.block_create,u.time_subscription)
			          - u.total_suspend_time
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # Update current latency totals for unfinished blocks
    # The formula is now - t_soonest_possible_start - t_suspended
    $sql = qq{
	update t_status_block_latency l
	   set l.time_update = :now, 
               l.latency = :now - 
	                   greatest(l.block_create,l.time_subscription)
		           - l.total_suspend_time - l.partial_suspend_time
         where l.last_replica is null
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    return @r;
}

1;
