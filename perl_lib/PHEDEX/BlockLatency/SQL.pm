package PHEDEX::BlockLatency::SQL;

=head1 NAME

PHEDEX::BlockLatency::SQL

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It is not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

SQL calls for interacting with t_dps_block_latency and t_xfer_file_latency,
two tables to monitor the current progress of block completion at a node,
and with t_log_file_latency and t_log_block_latency, two table for
logging the historical record of the time it took for block completion at
a node

=head1 METHODS

=over

=item mergeXferFileLatency(%args)

Updates the t_xfer_file_latency table using current data in
t_xfer_task_* and t_xfer_path. Keeps track of number of file
transfer attempts, source node for the first transfer attempt,
and source node for the current transfer attempt. For multi-hop
transfers, only the transfer tasks to the final destination are
counted. For transfers to MSS destinations, only the WAN transfer
tasks to the Buffer node are counted; but the time for migration
to the MSS node is also recorded.
This method needs to be run by the FilePump agent on every cycle
when receiving "task done" events, because the agent immediately
cleans up the entries in the t_xfer_task_* tables afterwards.

Returns a statistics array containing ('stats name', number of rows
updated) for each statement in the subroutine.

=item mergeStatusBlockLatency(%args)

Creates new entries in t_dps_block_latency and t_xfer_file_latency
when a new block destination is created, initializing file-level
entries from t_xfer_replica for pre-existing files.
Updates the t_dps_block_latency table using current data in
t_dps_block_dest and t_xfer_file_latency.
Keeps track of latency up to the time the block is first completed, after
which any changes to the block (e.g. file retransferred) are not
accounted for.  Keeps track of block suspension time and subtracts
that from the total latency.

This method can be run asynchronously, but it makes little sense to
run it any faster than BlockAllocator, since the state from that agent
is used to determine important events such as suspension and block
completion.  On the other hand, if it is run slower than
BlockAllocator it will miss events.  For this reason it is run after
BlockAllocator completes.

Returns a statistics array containing ('stats name', number of rows
updated) for each statement in the subroutine.

=item mergeLogBlockLatency(%args)

Migrates latency entries for completed block destinations
from t_xfer_file_latency to t_log_file_latency,
and from t_dps_block_latency to t_log_block_latency
respectively. Fills missing file-level events from t_xfer_replica.
Calculates the time markers for several steps
in the block completion history. Cleans up the archived entries
from t_xfer_file_latency and t_dps_block_latency.

Returns a statistics array containing ('stats name', number of rows
updated) for each statement in the subroutine.

=item cleanLogFileLatency(%args)

Cleans up old entries in the t_log_file_latency table.
The default is to clean up file-level information for
block destinations completed more than 30 days ago.
Block-level information is kept indefinitely.

Returns a statistics array containing ('stats name', number of rows
updated) for each statement in the subroutine.

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
sub mergeXferFileLatency
{
    my ($self,%h) = @_;
    my $sql;
    
    my %stats;
    my @stats_order = ('transfers to buffer','transfers to final destination');
    $stats{$_} = 0 foreach @stats_order;

    # SPECIAL-case: Merge tasks to Buffer nodes before recording taks to final destination

    $sql = qq { merge into t_xfer_file_latency fl using
                    (select xtd.time_update, xt.from_node, nmss.id to_node, xt.fileid,
                     xf.inblock, xf.filesize,
                     (xt.priority-1)/2 priority,
                     xt.is_custodial, xp.time_request, xp.time_confirm time_route,
                     xt.time_assign, xte.time_update time_export, xtd.report_code
                     from t_xfer_task_harvest xth
                     join t_xfer_task xt on xt.id = xth.task
		     left join t_xfer_task_export xte on xte.task = xt.id
                     join t_xfer_file xf on xf.id=xt.fileid
                     join t_xfer_task_done xtd on xtd.task = xt.id
                     left join t_xfer_path xp on xp.fileid=xt.fileid and xp.from_node=xt.from_node and xp.to_node=xt.to_node
                     join t_adm_link ln on ln.from_node=xt.from_node and ln.to_node=xt.to_node and ln.is_local='n'
		     join t_adm_node nd on nd.id=xt.to_node and nd.kind='Buffer'
		     join t_adm_link lnmig on lnmig.from_node=xt.to_node and lnmig.is_local='y'
		     join t_adm_node nmss on nmss.id=lnmig.to_node and nmss.kind='MSS'
                     join t_dps_block_latency bl on bl.destination=nmss.id and bl.block=xf.inblock
                     ) new
                  on (fl.destination = new.to_node and fl.fileid = new.fileid)
                  when matched then
                  update set
                  fl.time_update=new.time_update, fl.priority=new.priority, fl.is_custodial=new.is_custodial,
                  fl.from_node=new.from_node,
		  fl.attempts=nvl(fl.attempts,0)+1,
                  fl.time_latest_attempt=new.time_update,
                  fl.time_on_buffer=decode(new.report_code,0,new.time_update,NULL)
                  where fl.time_at_destination is null and fl.time_on_buffer is null
                  when not matched then
                  insert (time_update, destination, fileid, inblock, filesize, priority, is_custodial, time_request,
			  original_from_node, from_node, time_route, time_assign, time_export, attempts,
			  time_first_attempt, time_latest_attempt, time_on_buffer)
                  values (new.time_update, new.to_node, new.fileid, new.inblock, new.filesize,
                          new.priority, new.is_custodial, new.time_request, new.from_node, new.from_node,
			  new.time_route, new.time_assign, new.time_export, 1,
			  new.time_update, new.time_update, decode(new.report_code,0,new.time_update,NULL))
	      };

    my @rv = execute_sql( $self, $sql );
    $stats{'transfers to buffer'} = $rv[1] || 0;

    # Merge transfers to final destination
    # NOTE: don't increment attempts count for Buffer-->MSS transfers, so that 'attempts' is only the number of WAN attempts

    $sql = qq { merge into t_xfer_file_latency fl using
		    (select xtd.time_update, xt.from_node, xt.to_node, xt.fileid,
		     xf.inblock, xf.filesize, 
		     decode(ln.is_local,'y',xt.priority/2,'n',(xt.priority-1)/2) priority,
		     xt.is_custodial, xp.time_request, xp.time_confirm time_route,
		     xt.time_assign, xte.time_update time_export, xtd.report_code
		     from t_xfer_task_harvest xth
		     join t_xfer_task xt on xt.id = xth.task
		     left join t_xfer_task_export xte on xte.task = xt.id
		     join t_xfer_file xf on xf.id=xt.fileid
		     join t_xfer_task_done xtd on xtd.task = xt.id
		     left join t_xfer_path xp on xp.fileid=xt.fileid and xp.from_node=xt.from_node and xp.to_node=xt.to_node
		     join t_adm_link ln on ln.from_node=xt.from_node and ln.to_node=xt.to_node
		     join t_adm_node nd on ln.to_node=nd.id
		     join t_dps_block_latency bl on bl.destination=xt.to_node and bl.block=xf.inblock
		     ) new
		  on (fl.destination = new.to_node and fl.fileid = new.fileid)
		  when matched then
		  update set
		  fl.time_update=new.time_update, fl.priority=new.priority, fl.is_custodial=new.is_custodial,
		  fl.from_node=nvl2(fl.time_on_buffer,fl.from_node,new.from_node),
		  fl.attempts=nvl2(fl.time_on_buffer,fl.attempts,nvl(fl.attempts,0)+1),
		  fl.time_latest_attempt=nvl2(fl.time_on_buffer, fl.time_latest_attempt, new.time_update),
		  fl.time_at_destination=decode(new.report_code,0,new.time_update,NULL)
		  where fl.time_at_destination is null
		  when not matched then
		  insert (time_update, destination, fileid, inblock, filesize, priority, is_custodial, time_request, 
			  original_from_node, from_node, time_route, time_assign, time_export, attempts,
			  time_first_attempt, time_latest_attempt, time_at_destination)
		  values (new.time_update, new.to_node, new.fileid, new.inblock, new.filesize, 
			  new.priority, new.is_custodial, new.time_request, new.from_node, new.from_node,
			  new.time_route, new.time_assign, new.time_export, 1,
			  new.time_update, new.time_update, decode(new.report_code,0,new.time_update,NULL))
			  };

    my @rv2 = execute_sql( $self, $sql );
    $stats{'transfers to final destination'} = $rv2[1] || 0;
    
    # Return statistics
    return map { [$_, $stats{$_}] } @stats_order;
}

#-------------------------------------------------------------------------------
sub mergeLogBlockLatency
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n);

    my %stats;
    my @stats_order = ('files merged','file replicas merged',
		       'anonymous files merged','blocks merged',
		       'block logs deleted');
    
    $stats{$_} = 0 foreach @stats_order;
    
    # Merge file latency information into history table for finished blocks
    $sql = qq {
	merge into t_log_file_latency u
	    using
	    (select bl.time_subscription, fl.time_update, fl.destination, fl.fileid, fl.inblock, 
	          fl.filesize, fl.priority, fl.is_custodial, fl.time_request, fl.original_from_node, fl.from_node,
	          fl.time_route, fl.time_assign, fl.time_export, fl.attempts, fl.time_first_attempt,
	          fl.time_on_buffer, fl.time_at_destination
	    from t_dps_block_latency bl join t_xfer_file_latency fl on bl.block=fl.inblock and bl.destination=fl.destination
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
		       u.original_from_node,
		       u.from_node,
		       u.time_route,
		       u.time_assign,
		       u.time_export,
		       u.attempts,
		       u.time_first_attempt,
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
		d.original_from_node,
		d.from_node,
		d.time_route,
		d.time_assign,
		d.time_export,
		d.attempts,
		d.time_first_attempt,
		d.time_on_buffer,
		d.time_at_destination)
	   };

    ($q, $n) = execute_sql( $self, $sql, %p );
    $stats{'files merged'} = $n || 0;

# Merge file replica information into history table for finished blocks for files with no latency info (already at destination, or missed events)
    $sql = qq {
	merge into t_log_file_latency u
	    using
	    (select bl.time_subscription, xr.time_create time_update, bl.destination, xr.fileid, xf.inblock, 
	          xf.filesize, xr.time_create time_at_destination
	    from t_dps_block_latency bl join t_xfer_file xf on bl.block=xf.inblock
	     join t_xfer_replica xr on xr.fileid=xf.id and xr.node=bl.destination
	     left join t_xfer_file_latency fl on fl.fileid=xf.id and fl.destination=xr.node
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
    $stats{'file replicas merged'} = $n || 0 ;
    
    # Add anonymous file statistics for completed blocks (invalidated files)
    $sql = qq {
	insert into t_log_file_latency d
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
                d.time_on_buffer,
                d.time_at_destination)
	    select bl.time_subscription, fl.time_update, fl.destination, fl.fileid, fl.inblock,
                  fl.filesize, fl.priority, fl.is_custodial, fl.time_request, fl.time_route,
            fl.time_assign, fl.time_export, fl.attempts, fl.time_first_attempt,
            fl.time_on_buffer, fl.time_at_destination
            from t_dps_block_latency bl join t_xfer_file_latency fl on bl.block=fl.inblock and bl.destination=fl.destination
            where bl.last_replica is not null and fl.fileid is null
    };

    ($q, $n) = execute_sql( $self, $sql );
    $stats{'anonymous files merged'} = $n || 0;

    # Merge latency information into history table for finished blocks
    $sql = qq{
	merge into t_log_block_latency u
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
	       sum(fl.attempts) total_xfer_attempts, stats_mode(fl.from_node) primary_from_node,
	       max(fl.nfrom) primary_from_files,
	       bl.last_replica, bl.total_suspend_time, bl.latency
		from t_dps_block_latency bl
	        left join (select destination, inblock, attempts, from_node,
			     time_at_destination, time_request,
			     count(from_node) over (partition by destination, inblock, from_node) nfrom
			   from t_xfer_file_latency) fl 
	        on bl.destination=fl.destination and bl.block=fl.inblock
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
	 u.percent50_replica,u.percent75_replica,u.percent95_replica,u.last_replica,
	 u.total_xfer_attempts,u.primary_from_node,u.primary_from_files,u.total_suspend_time,u.latency)
	values
	(d.time_update,d.destination,d.block,d.files,d.bytes,d.priority,d.is_custodial,d.time_subscription,              
         d.block_create,d.block_close,d.first_request,d.first_replica,d.percent25_replica,                 
         d.percent50_replica,d.percent75_replica,d.percent95_replica,d.last_replica,
	 d.total_xfer_attempts,d.primary_from_node,d.primary_from_files,d.total_suspend_time,d.latency) 
	
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    $stats{'blocks merged'} = $n || 0;

    # Now clean up all we have archived (will also cascade deletion of file-level entries)
    $sql = qq {
	delete from t_dps_block_latency where last_replica is not null
	};

    ($q, $n) = execute_sql( $self, $sql, %p );
    $stats{'block logs deleted'} = $n || 0;
    
    return map { [$_, $stats{$_}] } @stats_order;
}

#----------------------------------------------------------------------------------------
sub mergeStatusBlockLatency
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n);
    
    my %stats;
    my @stats_order = ('unfinished blocks deleted','block stats updated',
		       'new blocks added', 'new blocks with files added',
		       'latest replica updated','finished blocks updated',
		       'unfinished blocks updated');
    $stats{$_} = 0 foreach @stats_order;

    $p{':now'} = $h{NOW} || &mytimeofday();

    # delete log of unfinished blocks which are no longer destined.
    $sql = qq{
	delete from t_dps_block_latency l
	     where l.last_replica is null and 
	      not exists
	       ( select 1 from t_dps_block_dest bd
		     where bd.destination = l.destination
		 and bd.block = l.block ) };

    ($q, $n) = execute_sql( $self, $sql );
    $stats{'unfinished blocks deleted'} = $n || 0;

    # Update statistics for existing block status latency entries:
    # update the suspension time since the latest replication 
    # as long as the block isn't complete at the destination.
    # Also update block and subs stats (files, bytes, block_close, priority)
    $sql = qq{
	merge into t_dps_block_latency l
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
    $stats{'block stats updated'} = $n || 0;
    
    # Get new block destinations which don't have a block latency status entry yet
    # Don't wait for block activation because the block will be reactivated anyway
    # if the block destination is incomplete.

    $sql = qq{ 
	select bd.destination, b.id block, b.files, b.bytes, b.time_create block_create, decode(b.is_open,'n',b.time_update,'y',NULL) block_close,
                  bd.priority, bd.is_custodial, bd.time_subscription, nvl2(bd.time_suspend_until, :now, NULL) last_suspend
              from t_dps_block_dest bd
              join t_dps_block b on b.id = bd.block
              left join t_dps_block_latency bl on bl.destination=bd.destination and bl.block=bd.block
              where bl.block is null and bd.time_complete is null
	  };

    ($q,$n) = execute_sql( $self, $sql, %p );
    
    my $blocksql = qq{
	insert into t_dps_block_latency 
	    (time_update, destination, block, files, bytes, block_create, block_close,
                  priority, is_custodial, time_subscription, last_suspend)
	    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	};
    
    my %bargs;
    my %fargs;

    my $filesql = qq {
	insert into t_xfer_file_latency
	    (time_update, destination, fileid, inblock, filesize, time_on_buffer, time_at_destination)
	    select ?, xr.node, xr.fileid, xf.inblock, xf.filesize, xrb.time_create, xr.time_create
	        from t_xfer_replica xr join t_xfer_file xf on xr.fileid=xf.id
		join t_adm_node nd on xr.node=nd.id
		left join t_adm_link ln on ln.to_node=nd.id and ln.is_local='y'
		left join t_adm_node nbuf on nbuf.id=ln.from_node and nbuf.kind='Buffer'
		left join t_xfer_replica xrb on xrb.node=nbuf.id and xrb.fileid=xf.id
		where xr.node = ? and xf.inblock = ?
	};
	    

    my $brow;
    while ($brow = $q->fetchrow_hashref()) {
	my $nb = 1;
	push(@{$bargs{$nb++}}, $p{':now'});
	push(@{$bargs{$nb++}}, $brow->{DESTINATION});
	push(@{$bargs{$nb++}}, $brow->{BLOCK});
	push(@{$bargs{$nb++}}, $brow->{FILES});
	push(@{$bargs{$nb++}}, $brow->{BYTES});
	push(@{$bargs{$nb++}}, $brow->{BLOCK_CREATE});
	push(@{$bargs{$nb++}}, $brow->{BLOCK_CLOSE});
	push(@{$bargs{$nb++}}, $brow->{PRIORITY});
	push(@{$bargs{$nb++}}, $brow->{IS_CUSTODIAL});
	push(@{$bargs{$nb++}}, $brow->{TIME_SUBSCRIPTION});
	push(@{$bargs{$nb++}}, $brow->{LAST_SUSPEND});
	my $nf = 1;
	push(@{$fargs{$nf++}}, $p{':now'});
        push(@{$fargs{$nf++}}, $brow->{DESTINATION});
	push(@{$fargs{$nf++}}, $brow->{BLOCK});
    }

    my @rv = &dbexec($self->{DBH}, $blocksql, %bargs) if %bargs;
    $stats{'new blocks added'} = $rv[1] || 0;

    my @rv2 = &dbexec($self->{DBH}, $filesql, %fargs) if %fargs;
    $stats{'new blocks with files added'} = $rv2[1] || 0;
  
    # Update most recent replica if the block record is not complete; if a new replica was created
    # since the previous update, add the partial suspension time since the latest replica to the total suspension time
    $sql = qq{
        merge into t_dps_block_latency u
        using
          (select l.destination, l.block,
	       max(fl.time_at_destination) latest_replica, l.partial_suspend_time
	    from t_xfer_file_latency fl
              join t_dps_block_latency l on l.destination = fl.destination
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
    $stats{'latest replica updated'} = $n || 0;
   
    # Update last replica and latency total for finished blocks
    # The formula is t_last_replica - t_soonest_possible_start - t_suspended
    $sql = qq{
	merge into t_dps_block_latency u
	using
          (select l.destination, l.block,
	       max(fl.time_at_destination) last_replica
             from t_dps_block_dest bd
	     join t_dps_block b on b.id = bd.block
	     join t_dps_block_latency l on l.block = bd.block
	                               and l.destination = bd.destination
	     join t_xfer_file_latency fl on fl.inblock=l.block
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
    $stats{'finished blocks updated'} = $n || 0;

    # Update current latency totals for unfinished blocks
    # The formula is now - t_soonest_possible_start - t_suspended
    $sql = qq{
	update t_dps_block_latency l
	   set l.time_update = :now, 
               l.latency = :now - 
	                   greatest(l.block_create,l.time_subscription)
		           - l.total_suspend_time - l.partial_suspend_time
         where l.last_replica is null
    };

    ($q, $n) = execute_sql( $self, $sql, %p );
    $stats{'unfinished blocks updated'} = $n || 0;

    return map { [$_, $stats{$_}] } @stats_order;

}

sub cleanLogFileLatency {
    
    my ($self, %h) = @_;
    my ($sql,%p,$q,$n);
    my %stats;
    my @stats_order = ('file logs deleted');
    $stats{$_} = 0 foreach @stats_order;

    my $now = $h{NOW} || &mytimeofday();
    my $limit = 30*86400;
    $limit = $h{LIMIT} if defined $h{LIMIT};

    $p{':old'} = $now - $limit;

    $sql = qq{
	delete from t_log_file_latency
	    where (time_subscription, destination, inblock) in
	    ( select time_subscription, destination, block from t_log_block_latency
	          where time_update < :old )
	};
    
    ($q, $n) = execute_sql( $self, $sql, %p );
    $stats{'file logs deleted'} = $n || 0;

    return map { [$_, $stats{$_}] } @stats_order;

}

1;
