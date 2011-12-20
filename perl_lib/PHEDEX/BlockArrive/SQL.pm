package PHEDEX::BlockArrive::SQL;

=head1 NAME

PHEDEX::BlockArrive::SQL

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It is not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

SQL calls for interacting with t_status_block_arrive, a table for the predicted arrival
time of a block on a node

=head1 METHODS

=over

=item mergeStatusBlockArrive(%args)

Updates the t_status_block_arrive table using current data in
t_dps_block_destination, t_status_block_request, xfer_request and t_xfer_replica, status information in t_status_link
and historical data in
t_history_dest, t_history_link_stats, t_history_link_events, t_adm_link_param.
Keeps track of predicted arrival time for closed blocks currently subscribed for transfer
and incomplete at destination.

This method can be run asynchronously, there are a few agents where it would make sense to run it:
PerfMonitor (manages status/history), FileRouter (manages t_xfer_request) and FilePump (manages t_xfer_replica)
TBD.

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
sub mergeStatusBlockArrive
{
    my ($self,%h) = @_;
    my ($sql,%p,$q,$n,@r);

    $p{':now'} = $h{NOW} || &mytimeofday();

    # Clean up status table
    
    $sql = qq{ delete from t_status_block_arrive };
    ($q, $n) = execute_sql( $self, $sql );
    push @r, $n;

    # Create the stats (files, bytes, priority) for incomplete block destinations
    # Set basis to 'o'/'s'/'rs' for open/suspended/routersuspended blocks respectively for which no estimate can be done
    # TODO: suspensions can expire - should we use this in estimate?
    # Set basis to 'd' (dummy) for other blocks, to be updated later

    $sql = qq{
	insert into t_status_block_arrive
	    ( time_update, destination, block, files, bytes, priority, basis )
	    select :now, bd.destination, bd.block, b.files, b.bytes, bd.priority,
	            case
	              when bd.state = 2 then 's'
		      when bd.state = 4 then 'rs'
	              when b.is_open = 'y' then 'o'
		    end basis
	        from t_dps_block_dest bd
	        join t_dps_block b on b.id = bd.block
	        where bd.state = 2 or bd.state = 4 or b.is_open = 'y' };

    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;
    
    # Estimate the arrival time for block destinations which are currently waiting for routing allocation (bd.state=0)
    # Possible reasons for this:
    # 1) The destination node is dead (has no valid download link). In this case no estimate is possible.
    # 2) The priority queue to the destination node is full. In this case the minimum possible arrival time is the time to enter the queue.
    # 3) The block was recently subscribed and is still waiting for activation by BlockActivate or allocation by FileRouter.
    # In this case, the minimum arrival time is the cycle time for these agents (10 minutes in the worst case).
    # TODO: WHERE TO PUT THIS??? THE FILEROUTER IS THE MOST LOGICAL PLACE because it knows about 1 and 2...

    $sql = qq{
	merge into t_status_block_arrive barr
	    using ( select bd.destination, bd.block, b.files, b.bytes,
		           bd.priority, 'ur' basis
		      from t_dps_block_dest bd
		      join t_dps_block b on b.id=bd.block
		    where bd.state=0 ) bdest
	    on barr.block = bdest.block and barr.destination = bdest.destination
	    when not matched then
	      insert ( time_update, destination, block, files, bytes, priority, basis )
	      values ( :now, bdest.destination, bdest.block, bdest.files, bdest.bytes,
		       bdest.priority, bdest.basis )
	  };
    
    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;    
    
 
    # Estimate the arrival time for block destinations which are currently activated for routing (bd.state=1)
    # but for which some of the files are currently unroutable (t_xfer_request.state!=0).
    # The FileRouter logs this information in the t_status_block_request table.
    # Possible states are:
    # state=4 (files with no replica; block will never complete)
    # state=3 (no path to destination; block might complete eventually
    # if direct link is enabled or the file is replicated to an intermediate site with a valid link; no possible arrival time estimate
    # (NOTE - if the file is also already requested for transfer to an intermediate site with a valid link to the destination,
    # we could estimate arrival time in theory - in practice, won't do... Would rather enable multi-hop routing in this case)
    # state=2 (the request has expired; it should be reactivated in the same FileRouter cycle if the destination site is alive. --> no need to worry about it here.
    # state=1 (there was a recent failure for this transfer request; if the destination site is alive,
    # the request will be reactivated after its expiration time has passed: normally 40-90 minutes; 7-10 hours for expired transfers due to #89643)
    # TODO: IN THIS CASE, THE FILEROUTER SLOW FLUSH DELETES THE FILE PATHS TO TRIGGER REROUTING, SO WE MIGHT NOT HAVE
    # THE POSSIBILITY TO PROVIDE A ROUTING ESTIMATE ANYMORE. WHAT SHOULD WE USE FOR THE ESTIMATE??? FILE LATENCY TABLES???
    
    $sql = qq{
        merge into t_status_block_arrive barr
            using ( select br.destination, br.block, b.files, b.bytes,
		           br.priority, 
		           case
		           when max(br.state)=4 then 'nsr'
		           when max(br.state)=3 then 'np'
		           when max(br.state)=1 then 'co'
		           end basis
                      from t_status_block_request br
		      join t_dps_block b on b.id=br.block
                    where br.state = 4 or br.state = 3 or br.state =1
		    group by br.destination, br.block, b.files, b.bytes,
		          br.priority
		    ) breq
	    on barr.block = breq.block and barr.destination = breq.destination
            when not matched then
              insert ( time_update, destination, block, files, bytes, priority, basis )
              values ( :now, bdest.destination, bdest.block, bdest.files, bdest.bytes,
                       bdest.priority, bdest.basis )
          };
    
    ($q, $n) = execute_sql( $self, $sql, %p );
    push @r, $n;

    # What remains is the files with an active request - for these, the ETA is estimated by the router in the path cost.

    $sql = qq{
        merge into t_status_block_arrive barr
            using
            ( select xp.destination, xf.inblock, decode(xp.is_local,'y',xp.priority/2,'n',(xp.priority-1)/2) priority,  
	             'r' basis, :now + max(xp.total_cost) time_arrive
	        from t_xfer_path xp
	        join t_xfer_file xf on xp.fileid=xf.id
	        where xp.is_valid = 1
	        group by xp.destination, xf.inblock, priority
	      ) blockstats
	      on barr.block=bdest.block and barr.destination=bdest.destination                                                                                                                  
	      when matched then                                                                                                                                                                 
              update set barr.time_update = :now,                                                                                                                                             
                         barr.files = bdest.files,                                                                                                                                            
	  };      
                                                                                                                                                                                              
    ($q, $n) = execute_sql( $self, $sql, %p );                                                                                                                                                
    push @r, $n;


}

1;
