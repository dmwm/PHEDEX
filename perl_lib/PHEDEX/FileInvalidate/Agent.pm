package PHEDEX::FileInvalidate::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My TMDB node
		  ONCE => 0,			# Quit after one run
		  WAITTIME => 120 + rand(30));	# Agent cycle time
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Do some work.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;

    eval
    {
	$dbh = $self->connectAgent();
	my $now = &mytimeofday();

	# Issue file replica invalidation tasks for file replicas scheduled
	# for invalidation and for which no invalidation task yet exists.
	# Take care not to create deletion requests for actively
	# transferring or deleting files:
	#   - no transfer task (outgoing), on target and locally linked Buffer node
	#   - no deletion request
	# NOTE - all file invalidation requests and tasks for Buffer/MSS node pairs
	# are created at MSS node; FilePump will take care of also removing
	# file replica from Buffer nodes locally linked to the target MSS node
	my ($stmt, $nrow) = &dbexec($dbh, qq{
	   insert into t_xfer_invalidate (fileid, node, time_request)
	   (select fi.fileid, fi.node, fi.time_request
	    from t_dps_file_invalidate fi
	      join t_xfer_file f
	        on f.id=fi.fileid
	      left join t_adm_link ln on ln.from_node=fi.node and ln.is_local='y'
	      left join t_adm_node ndbuf on ndbuf.id=ln.to_node and ndbuf.kind='Buffer'
	      left join t_xfer_task xt
                on xt.fileid = f.id
               and (xt.from_node = fi.node or xt.to_node = fi.node
		    or xt.from_node=ndbuf.id or xt.to_node = ndbuf.id)
	      left join t_xfer_delete xd
	        on xd.fileid = f.id and xd.node = fi.node
              left join t_xfer_invalidate xi
                on xi.fileid = f.id and xi.node = fi.node
	    where xi.fileid is null
              and xd.fileid is null
              and xt.id is null
              and fi.time_complete is null)});
	$self->Logmsg ("$nrow file replica invalidations scheduled") if $nrow > 0;

        # Mark the file invalidation request completed if the file
        # invalidation task is completed, where
        # completed means that the invalidation task is finished AND the
        # replica is gone from the target node and the locally linked Buffer node
        ($stmt, $nrow) = &dbexec ($dbh, qq{
          merge into t_dps_file_invalidate fi
          using (select xi.fileid, xi.node, xi.time_request, xi.time_complete
                   from t_xfer_invalidate xi
              left join t_xfer_replica xr on xr.fileid = xi.fileid and xr.node = xi.node
              left join t_adm_link ln on ln.from_node=xi.node and ln.is_local='y'
              left join t_adm_node ndbuf on ndbuf.id=ln.to_node and ndbuf.kind='Buffer'
              left join t_xfer_replica xrb on xrb.fileid = xi.fileid and xrb.node = ndbuf.id
                   join t_xfer_file xf on xf.id = xi.fileid
                   join t_dps_file_invalidate fin on xi.node = fin.node and xi.fileid = fin.fileid
                  where fin.time_complete is null
                    and xr.fileid is null
                    and xrb.fileid is null
                    and xi.time_complete is not null) d
             on (fi.fileid=d.fileid and fi.node=d.node and fi.time_request=d.time_request)
             when matched then update set fi.time_complete = :now}, ':now' => $now);
	$self->Logmsg ("$nrow file replica invalidations completed") if $nrow > 0;

        # Remove file invalidation tasks for completed file invalidations
        ($stmt, $nrow) = &dbexec ($dbh, qq{
            delete from t_xfer_invalidate xi
             where exists ( select 1 from t_dps_file_invalidate fi
                             where xi.node = fi.node and xi.fileid = fi.fileid
                             and fi.time_complete is not null )
         });
	$self->Logmsg ("$nrow file replica invalidation tasks cleaned up") if $nrow > 0;

        # Log what we just finished deleting
        my $q_done = &dbexec($dbh, qq{
            select n.name, f.logical_name
              from t_dps_file_invalidate fi
              join t_adm_node n on n.id = fi.node
              join t_xfer_file f on f.id = fi.fileid
             where fi.time_complete = :now
         }, ':now' => $now);

        while (my ($node, $block) = $q_done->fetchrow()) {
            $self->Logmsg("deletion of $block at $node finished");
        }

    	$dbh->commit();
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();

    $self->doStop() if $$self{ONCE};
}

1;
