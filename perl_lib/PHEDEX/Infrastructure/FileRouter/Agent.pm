package PHEDEX::Infrastructure::FileRouter::Agent;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging', 'PHEDEX::BlockArrive::SQL';

use strict;
use warnings;

use List::Util qw(max);
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use POE;
use Data::Dumper;

use constant TERABYTE => 1000**4;
use constant GIGABYTE => 1000**3;
use constant MEGABYTE => 1000**2;
use constant KILOBYTE => 1000;
use constant BYTE     => 1;

# package globals to avoid using $$self{X} so often
our $WINDOW_SIZE;
our $MIN_REQ_EXPIRE;
our $EXPIRE_JITTER;
our $LATENCY_THRESHOLD;
our $PROBE_CHANCE;
our $DEACTIV_ATTEMPTS;
our $DEACTIV_TIME;
our $NOMINAL_RATE;
our $N_SLOW_VALIDATE;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My node name
		  WAITTIME => 60 + rand(10),	# Agent activity cycle
		  FLUSH_MARKER => undef,	# Current slow flush marker
		  FLUSH_PERIOD => 1800,		# Frequency of slow flush
		  NEXT_STATS => 0,		# Next time to refresh stats
		  NEXT_SLOW_FLUSH => 0,	        # Next time to flush
		  WINDOW_SIZE => 10,            # Size of priority windows in TB
		  REQUEST_ALLOC => 'BY_AGE',    # Method to use when allocating file requests
		  MIN_REQ_EXPIRE => 7,          # Minimum time (hours) to expire a request/paths
		  EXPIRE_JITTER => 3,           # Duration (hours) which to randomize expiration on requests/paths
		  LATENCY_THRESHOLD => 3,       # Maximum estimated latency in days to determine if a path is valid
		  PROBE_CHANCE => 0.02,         # Probability to force routing on failure
		  DEACTIV_ATTEMPTS => 5,        # Mininum number of request attempts before other blocks are considered
		  DEACTIV_TIME => 30,           # Minimum age (days) of requests before a block is deactivated
		  NOMINAL_RATE => 0.5,          # Rate assumed for links with unknown performance.
		  N_SLOW_VALIDATE => 3,         # Number of invalid paths to validate in the slow flush.
                  EXTERNAL_RATE_FILE => undef,  # External source for rate estimate in routeCost
                  EXTERNAL_RATE_WAIT => 60,     # Freq. for updating rate from external source
                  EXTERNAL_RATE_DATA => undef,  # Actual external rate data container
		  ME	=> 'FileRouter',
		  );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    if ($$self{REQUEST_ALLOC} eq 'BY_AGE') {
	$$self{REQUEST_ALLOC_SUBREF} = \&getDestinedBlocks_ByAge;
    } elsif ($$self{REQUEST_ALLOC} eq 'DATASET_BALANCE') {
	$$self{REQUEST_ALLOC_SUBREF} = \&getDestinedBlocks_DatasetBalance;
    } else {
	die "Request allocation method '$$self{REQUEST_ALLOC}' not known, use -h for help.\n";
    }
   
    if ($$self{PROBE_CHANCE} < 0 or $$self{PROBE_CHANCE} > 1) {
	die "Probe probability '$$self{PROBE_CHANCE}' is not valid.  Must be from 0 to 1.\n";
    }

    # Set package globals (and set their units)
    $WINDOW_SIZE       = $$self{WINDOW_SIZE} * TERABYTE;
    $MIN_REQ_EXPIRE    = $$self{MIN_REQ_EXPIRE}*3600;
    $EXPIRE_JITTER     = $$self{EXPIRE_JITTER}*3600;
    $LATENCY_THRESHOLD = $$self{LATENCY_THRESHOLD}*24*3600;
    $PROBE_CHANCE      = $$self{PROBE_CHANCE};
    $DEACTIV_ATTEMPTS  = $$self{DEACTIV_ATTEMPTS};
    $DEACTIV_TIME      = $$self{DEACTIV_TIME}*24*3600;
    $NOMINAL_RATE      = $$self{NOMINAL_RATE} * MEGABYTE;
    $N_SLOW_VALIDATE   = $$self{N_SLOW_VALIDATE};

    map { $self->{EXTERNAL_RATE_AGE}{$_} = -1 } @{$self->{EXTERNAL_RATE_FILE}};

    bless $self, $class;
    return $self;
}

sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    my @nodes;

    eval
    {
	$$self{NODES} = [ '%' ];
	$dbh = $self->connectAgent();
	@nodes = $self->expandNodes();

	# Report configuration (once only)
	$self->report_config();

	# Run general flush.
	$self->flush($dbh);

	# Route files.
	$self->route($dbh);

	# Perhaps update statistics.
	$self->stats($dbh);
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database and reset flush marker
    $self->disconnectAgent();
    $$self{FLUSH_MARKER} = undef;
}

# Report the configuration parameters to the log file.
sub report_config
{
    my $self = shift;
    if (!$self->{REPORTED_CONFIG}) {
	$self->{REPORTED_CONFIG} = 1;
	$self->Logmsg("router configuration: ", 
		      sprintf(join(", ",
				   'WINDOW_SIZE=%0.2f TB',
				   'REQUEST_ALLOC=%s',
				   'MIN_REQ_EXPIRE=%0.2f hours',
				   'EXPIRE_JITTER=%0.2f hours',
				   'LATENCY_THRESHOLD=%0.2f days',
				   'PROBE_CHANCE=%0.2f',
				   'DEACTIV_ATTEMPTS=%i',
				   'DEACTIV_TIME=%0.2f days',
				   'NOMINAL_RATE=%0.2f MB/s',
				   'N_SLOW_VALIDATE=%i paths'),
			      $WINDOW_SIZE/TERABYTE,
			      $self->{REQUEST_ALLOC},
			      $MIN_REQ_EXPIRE/3600,
			      $EXPIRE_JITTER/3600,
			      $LATENCY_THRESHOLD/(24*3600),
			      $PROBE_CHANCE,
			      $DEACTIV_ATTEMPTS,
			      $DEACTIV_TIME/(24*3600),
			      $NOMINAL_RATE/MEGABYTE,
			      $N_SLOW_VALIDATE,
			      ));
    }
}

# Run general system flush.  This is generally for table clean-up
# actions that don't need to be executed too often or would be
# prohibitively expensive to the database if they were executed too
# often.
sub flush
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    return if $now < $$self{NEXT_SLOW_FLUSH};

    # Get the current value of marker from file pump.
    my $markerval = (defined $$self{FLUSH_MARKER} ? "currval" : "nextval");
    ($$self{FLUSH_MARKER}) = &dbexec($dbh, qq{
	select seq_xfer_done.$markerval from dual})
	->fetchrow();

    my @stats;

    # De-activate and suspend block destinations when there
    # have been too many retries for all requests in a block
    # "too many" means at least 50 attempts for every request
    # and the newest request created 30 days ago
    # The blocks will be suspended for 15 days.
    my ($stmt, $rows) = &dbexec ($dbh, qq{
	update t_dps_block_dest 
           set state = 4, time_suspend_until = :now + $DEACTIV_TIME/2
         where (destination, block) in (
        select xq.destination, xq.inblock 
          from t_xfer_request xq 
         group by xq.destination, xq.inblock
        having min(xq.attempt) > $DEACTIV_ATTEMPTS*10
           and :now - max(xq.time_create) > $DEACTIV_TIME
	     )}, ':now' => $now);
    push @stats, ['stuck blocks suspended', $rows];

    # Clear requests for files no longer wanted.
    ($stmt, $rows) = &dbexec($dbh, qq{
	delete from t_xfer_request xq where not exists
	  (select 1 from t_dps_block_dest bd
	   where bd.destination = xq.destination
	     and bd.block = xq.inblock
	     and bd.state = 1)});
    push @stats, ['unwanted requests deleted', $rows];

    my $ndel = 0;
    # Clear requests where replica exists.  This is required
    # because the request activation from block destination
    # creates requests for files for which replica may exist.
    ($stmt, $rows) = &dbexec($dbh, qq{
	delete from t_xfer_request xq
	 where exists
	   (select 1 from t_xfer_replica xr
	     where xr.fileid = xq.fileid
	    and xr.node = xq.destination)});
    push @stats, ['deleted requests with replica', $rows];
    do { $dbh->commit(); $ndel = 0 } if (($ndel += $rows) >= 10_000);

    # Update priority on existing requests.
    #
    # This used to be a 'update where (select...) statement, but that does not
    # work with restricted column access. You can only use that syntax if you
    # have full update rights on the tables in the 'select' clause.
    #
    # Using a 'merge into' like this gets round that problem.
    ($stmt, $rows) = &dbexec ($dbh, qq{
      merge into t_xfer_request xr using
        (select xq.rowid id,
                bd.priority cur_priority
           from t_xfer_request xq
           join t_dps_block_dest bd
             on bd.block = xq.inblock and bd.destination = xq.destination
          where xq.priority != bd.priority) src
             on (xr.rowid = src.id)
           when matched then update set xr.priority = src.cur_priority});
    push @stats, ['request priority updated', $rows];

    # Create file requests for any active blocks where one does not
    # exist.  Note: we have triggers for this, but it is possible
    # (though rare) that some requests are missed if the injections
    # and activations happen at the same time.
    ($stmt, $rows) = &dbexec($dbh, qq{
	insert into t_xfer_request
        (fileid, inblock, destination, priority, is_custodial,
         state, attempt, time_create, time_expire)
         select xf.id, xf.inblock, bd.destination, bd.priority, bd.is_custodial, 
	        -1 state, 0 attempt, :now, :now
           from t_dps_block_dest bd
           join t_xfer_file xf on xf.inblock = bd.block
      left join t_xfer_request xq
                on xq.fileid = xf.id
                and xq.destination = bd.destination
      left join t_xfer_replica xr
                on xr.fileid = xf.id
                and xr.node = bd.destination
          where bd.state = 1
            and xq.fileid is null
            and xr.fileid is null }, ":now" => $now);
    push @stats, ['stray requests added', $rows];
           
    # For every source/destination pair, make some (default 3) random
    # invalid paths valid, if they have not yet expired. This ensures
    # a kind of low-rate "heartbeat" of transfer attempts for very poor links.
    ($stmt, $rows) = &dbexec($dbh, qq{
	update t_xfer_path 
           set is_valid = 1
	 where (src_node, destination, fileid) in 
         (select src_node, destination, fileid
            from (select xp.src_node, xp.destination, xp.fileid,
                         rank() over (partition by xp.src_node, xp.destination 
                                      order by dbms_random.value) n
                    from t_xfer_path xp
		   where xp.is_valid = 0 and xp.time_expire >= :now)
	  where n <= $N_SLOW_VALIDATE)}, ":now" => $now);
    push @stats, ['invalid paths validated', $rows];

    # If transfers path are about to expire on links which have
    # reasonable recent transfer rate (better than the nominal rate,
    # default 0.5 MB/s), and the calculated latency is still within
    # limits (better than the allowed latency, default 3 days),
    # and the transfer request is still valid, then
    # give a bit more grace time.  Be sure to extend the entire path
    # from src_node to destination so that paths are not broken on
    # cleanup.  Ignore local links so that fast local links do not
    # result in slow WAN links on the same path from being unduly
    # extended.
    my %extend;
    my $qextend = &dbexec($dbh, qq{
	select xp.fileid, xp.destination, xp.from_node, xp.to_node
	from t_xfer_path xp
	join t_xfer_request xq on xq.fileid = xp.fileid
	                      and xq.destination = xp.destination
        join t_adm_link l on l.to_node = xp.to_node
                         and l.from_node = xp.from_node
        join t_adm_link_param lp on lp.to_node = l.to_node
                                and lp.from_node = l.from_node
	where xp.time_expire >= :now
	  and xp.time_expire < :now + 2*3600
	  and xp.is_valid = 1
	  and xq.state = 0
          and l.is_local = 'n'
	  and lp.xfer_rate >= $NOMINAL_RATE
	  and lp.xfer_latency <= $LATENCY_THRESHOLD
     },	":now" => $now);

    while (my ($file, $dest, $from, $to) = $qextend->fetchrow())
    {
	push(@{$extend{':time_expire'}}, $now + $MIN_REQ_EXPIRE + rand($EXPIRE_JITTER));
	push(@{$extend{':to'}}, $to);
	push(@{$extend{':dest'}}, $dest);
	push(@{$extend{':fileid'}}, $file);
    }

    if (%extend)
    {
	# Array binds can't handle named parameters
	my %by_dest = (1 => $extend{':time_expire'},
		       2 => $extend{':dest'},
		       3 => $extend{':fileid'});
	my %by_to   = (1 => $extend{':time_expire'},
		       2 => $extend{':to'},
		       3 => $extend{':fileid'});
	($stmt, $rows) = &dbexec($dbh, qq{
	    update t_xfer_path set time_expire = ?
	    where destination = ? and fileid = ?},
	    %by_dest);
	push @stats, ['path expire extended', $rows];
	($stmt, $rows) = &dbexec($dbh, qq{
	    update t_xfer_task set time_expire = ?
	    where to_node = ? and fileid = ?},
	    %by_to);
	push @stats, ['task expire extended', $rows];
	($stmt, $rows) = &dbexec($dbh, qq{
	    update t_xfer_request set time_expire = ?
	    where destination = ? and fileid = ?},
	    %by_dest);
	push @stats, ['request expire extended', $rows];
    }

    # Deactivate requests which reached their expire time limit.
    ($stmt, $rows) = &dbexec($dbh, qq{
	update t_xfer_request
	set state = 2
	where state = 0 and :now >= time_expire},
	":now" => $now);
    push @stats, ['expired requests deactivated', $rows];

    # Clear old paths and those missing an active request.
    # Clear invalid expired paths.
    # Clear valid paths, that expired more than 8 hours ago.
    # Ensure paths are not broken in the proccess.
    ($stmt, $rows) = &dbexec($dbh, qq{
	    delete from t_xfer_path xp where (xp.fileid, xp.src_node, xp.destination) in (
	      select fileid, src_node, destination from (
		select ixp.fileid, ixp.src_node, ixp.destination,
		       count(*) total,
		  sum (case
		       when xq.fileid is null or xq.state != 0 then 1 --request is invalid
		       when ixp.is_valid = 1
			    and :now > ixp.time_expire + 8*3600 then 1 --valid path expired 8+ hours ago
		       when ixp.is_valid = 0 and :now >= ixp.time_expire then 1 -- invalid path expired
		       else 0
		       end) delete_path
		from t_xfer_path ixp
		left join t_xfer_request xq
		     on xq.fileid = ixp.fileid and xq.destination = ixp.destination
	       group by ixp.fileid, ixp.src_node, ixp.destination
	      ) where delete_path != 0 -- any path segment invalid, delete
	    ) }, ":now" => $now, ":now" => $now);
    push @stats, ['invalid paths deleted', $rows];
    do { $dbh->commit(); $ndel = 0 } if (($ndel += $rows) >= 10_000);

    # Set the path go again for issuer.
    ($stmt, $rows) = &dbexec($dbh, qq{ delete from t_xfer_exclude });
    push @stats, ['exclusions deleted', $rows];

    # Commit the lot above.
    $dbh->commit();

    # Log flush statistics
    $self->Logmsg('executed flush:  '.join(', ', map { $$_[1] + 0 .' '.$$_[0] } @stats));

    # Schedule the next flush
    $$self{NEXT_SLOW_FLUSH} = $now + $$self{FLUSH_PERIOD};
}

# Choose destinations which need file routing, iterate through them
# activating blocks and routing files.
#
# In the case of multi-hop routing, the execution order for the phases
# is important in that it balances progress for this node
# (destination) and requests by other nodes (relaying).  Some of the
# steps feed to the next one.
sub route
{
    my ($self, $dbh) = @_;

    # Read links and their parameters.  Only consider links which
    # are "alive", i.e. have a live download agent at destination
    # and an export agent at the source.  Ignore deactivated links.
    my $links = {};
    my $q = &dbexec($dbh, qq{
	select l.from_node, l.to_node, l.distance, l.is_local, l.is_active,
	       p.xfer_rate, p.xfer_latency,
	       xso.protocols, xsi.protocols
	from t_adm_link l
	  join t_adm_node ns on ns.id = l.from_node
	  join t_adm_node nd on nd.id = l.to_node
	  left join t_adm_link_param p
	    on p.from_node = l.from_node
	    and p.to_node = l.to_node
	  left join t_xfer_source xso
	    on xso.from_node = ns.id
	    and xso.to_node = nd.id
	    and xso.time_update >= :recent
	  left join t_xfer_sink xsi
	    on xsi.from_node = ns.id
	    and xsi.to_node = nd.id
	    and xsi.time_update >= :recent
	where l.is_active = 'y'
	  and ((ns.kind = 'MSS' and nd.kind = 'Buffer')
	   or (ns.kind = 'Buffer' and nd.kind = 'MSS'
	       and xsi.from_node is not null)
	   or (xso.from_node is not null
	       and xsi.from_node is not null))},
	":recent" => &mytimeofday() - 5400);

    my %active_nodes;  # hash for uniqueness
    while (my ($from, $to, $hops, $local, $is_active, $rate, $latency,
	       $src_protos, $dest_protos) = $q->fetchrow())
    {
	$active_nodes{$to} = 1;
	$$links{$from}{$to} = { HOPS => $hops,
				IS_ACTIVE => $is_active,
				IS_LOCAL => $local eq 'y' ? 1 : 0,
				XFER_RATE => $rate,
				XFER_LATENCY => $latency,
				FROM_PROTOS => $src_protos,
				TO_PROTOS => $dest_protos };
    }
    my @active_nodes = sort keys %active_nodes;

    # Now route for the nodes
    my %node_names = reverse %{$$self{NODES_ID}};
    my $active_node_list = join ' ', sort @node_names{@active_nodes};

    my @inactive_nodes;
    foreach ( keys %node_names ) {
	push @inactive_nodes, $_ if not exists $active_nodes{$_};
    }

    # Set all block destinations to inactive for inactive nodes
    $self->markInactive ($dbh, $_) for (@inactive_nodes);

    # Prepare new requests for all destination nodes
    $self->prepare ($dbh, $_) for (@active_nodes);

    # Route files for active requests
    $self->routeFiles ($dbh, $links, @active_nodes)
	|| $self->Logmsg ("no files to route to $active_node_list");
}

# Phase 0: Set state = -2 for block destinations that will not be
# activated for routing because there are no "alive" links to the destination
# node. This is for monitoring only - on the next FileRouter cycle,
# if the destination node is "alive", the block destinations will be routed
# normally. Do this only for blocks that are still waiting for routing activation
# (state <=0); if the block is already routed, it should stay in the queue.

sub markInactive
{
    my ($self, $dbh, $node) = @_;
    my $sql = qq{ update t_dps_block_dest
		      set state = -2
		      where state <= 0
		      and destination = :node };
    my @r = &dbexec($dbh, $sql, ":node" => $node);
    $self->Warn("Unable to activate $r[1] blocks for routing to node $node: no active incoming links")
	if $r[1] && $r[1]>0;
}



# Phase 1: Issue file requests for blocks requiring transfer.
#
# In this phase, we create file requests and implement the first
# step of the priority model.  In this model we have N windows of
# priority each of which can be filled up to WINDOW_SIZE bytes of
# requests.  The requests are allocated by block, so it is
# important that block sizes are typically much less than the
# WINDOW_SIZE.  The order in which blocks are activated into file
# requests is determined by a command-line argument.  See the
# getDestinedBlocks_* functions below to see what the options are.
sub prepare
{
    my ($self, $dbh, $node) = @_;


    # Get current level of through traffic
    my $now = &mytimeofday();
    my $q_not_for_me = &dbexec($dbh, qq{
	select nvl(sum(xf.filesize),0)
	  from t_xfer_path xp
	  join t_xfer_file xf
	       on xf.id = xp.fileid
	  left join t_xfer_request xq
	       on xq.fileid = xp.fileid
	       and xq.destination = xp.to_node
	 where xp.to_node = :node
	   and xq.fileid is null },
       ":node" => $node);
    my ($not_for_me) = $q_not_for_me->fetchrow() || 0;

    # Get current level of requests by priority.  We count "current
    # level" in requests with state = 0 or with less than a certain
    # number of attempts done on them (default 5).  This is to give
    # requests a fair shot at transferring in the correct
    # priority-order before we start to give up on them and look for
    # other requests.
    my %priority_windows = map { ($_ => 0) } 0..100;  # 100 levels of priority available
    my $q_current_requests = &dbexec($dbh, qq{
	select xq.priority, sum(xf.filesize)
          from t_xfer_request xq 
          join t_xfer_file xf on xf.id = xq.fileid
	 where xq.destination = :node
           and (xq.state = 0 or xq.attempt <= $DEACTIV_ATTEMPTS)
         group by xq.priority },
     ":node" => $node);

    while (my ($priority, $bytes) = $q_current_requests->fetchrow())
    {
	$priority_windows{$priority} += $bytes;
    }

    # Fill priority windows up to WINDOW_SIZE each if through traffic
    # is not more than WINDOW_SIZE
    if ($not_for_me <= $WINDOW_SIZE)
    {
	# First, re-activate requests from already-activated blocks which
	# either expired or failed to be routed.
	# (new injections to open blocks are also allocated here)
	my $q = &dbexec($dbh, qq{
	    select xq.destination, xq.fileid, xq.priority, f.filesize bytes
	      from t_xfer_request xq
	      join t_xfer_file f on f.id = xq.fileid
	     where xq.destination = :node
	       and :now >= xq.time_expire
	       and xq.state != 0
	     order by xq.priority asc, xq.time_create asc, xq.attempt asc
	   }, ':node' => $node, ':now' => $now);
	
	my $reactiv_u = &dbprep($dbh, qq{
		update t_xfer_request
	           set state = 0,
	               attempt = attempt+1,
	               time_expire = ?
                 where destination = ? and fileid = ?
	     });

	my %reactiv_reqs;
	my $n_reactiv = 0;
	my $bytes_reactiv = 0;
	my %warn_overflow;
	while (my $r = $q->fetchrow_hashref()) {
	    if (($priority_windows{$$r{PRIORITY}} += $$r{BYTES}) > $WINDOW_SIZE) {
		$warn_overflow{$$r{PRIORITY}} = $priority_windows{$$r{PRIORITY}} - $WINDOW_SIZE;
	    }
	    my $n = 1;
	    push(@{$reactiv_reqs{$n++}}, $now + $MIN_REQ_EXPIRE + rand($EXPIRE_JITTER));
	    push(@{$reactiv_reqs{$n++}}, $$r{DESTINATION});
	    push(@{$reactiv_reqs{$n++}}, $$r{FILEID});
	    $n_reactiv++;
	    $bytes_reactiv += $$r{BYTES};
	}
	&dbbindexec($reactiv_u, %reactiv_reqs) if %reactiv_reqs;
	undef %reactiv_reqs; # no longer needed
	foreach my $prio (sort keys %warn_overflow) {
	    $self->Warn(sprintf("node=%i priority %i window overflowed %0.1f GB", 
				$node, $prio, ($warn_overflow{$prio}/GIGABYTE)));
	}

	# Find block destinations we can activate, requiring that
	# the block fit into the priority window.  Note that open
	# blocks can grow beyond the window limits if new files
	# are added.  New file additions are added to the
	# t_xfer_request table via a trigger. We keep adding blocks
	# until the priority window is full or we are out of
	# wanted blocks.

	# Get blocks to activate according to the allocation model we are using
	my $blocks_to_activate = &{ $$self{REQUEST_ALLOC_SUBREF} }($dbh, $node);

	# Activate blocks up to the WINDOW_SIZE limit
	# Activated blocks are set to state=1;
	# blocks skipped due to WINDOW_SIZE limit are set to state=-1
	my $u = &dbprep($dbh, qq{
	    update t_dps_block_dest
	       set state = :state, time_active = :now
	     where block = :block 
               and destination = :node});
	my @activated_blocks;
	my $bytes_activ = 0;
	my $state;
	foreach my $b (@{ $blocks_to_activate })
	{
	    $state = ( ($priority_windows{$$b{PRIORITY}} += $$b{BYTES}) > $WINDOW_SIZE ) ? -1 : 1;
	    if ( $b->{BYTES} > $WINDOW_SIZE ) {
		$self->Alert("Block $b->{BLOCK} exceeds window allocation! ($b->{BYTES} > $WINDOW_SIZE)\n");
		$state = 1;
	    }
	    &dbbindexec($u,
			":block" => $$b{BLOCK},
			":node" => $node,
			":now" => $now,
			":state" => $state);
	    next if $state == -1;
	    push(@activated_blocks, $b);
	    $bytes_activ += $$b{BYTES};
	}
	undef $blocks_to_activate; # no longer needed

	# Create file requests for the activated blocks.  The
	# expiration time is randomized to prevent massive loads of
	# work in one cycle later.
	my $i = &dbprep($dbh, qq{
	    insert into t_xfer_request
	    (fileid, inblock, destination, priority, is_custodial,
	     state, attempt, time_create, time_expire)
	    select xf.id, bd.block, bd.destination, bd.priority, bd.is_custodial,
	           0 state, 1 attempt, :now, :time_expire
	      from t_xfer_file xf
              join t_dps_block_dest bd 
                   on xf.inblock = bd.block
	     where xf.inblock = :block
               and bd.destination = :node});
		
	my $nreqs = 0;
	foreach my $b (@activated_blocks)
	{
	    $nreqs += &dbbindexec($i,
				  ":block" => $$b{BLOCK},
				  ":node" => $node,
				  ":now" => $now,
				  ":time_expire" => $now + $MIN_REQ_EXPIRE + rand($EXPIRE_JITTER)
				  );
	}
	
	# Note: assuming 30 TB windows and 2 GB files, the maximum
	# rows we commit here is around 15k, which is acceptable.
	$dbh->commit();

	my $nblocks = scalar @activated_blocks;
	$self->Logmsg(sprintf("re-activated %i requests (%0.1f GB), ".
			      "activated %i blocks with %i files (%0.1f GB) for node=%i",
			      $n_reactiv, ($bytes_reactiv/GIGABYTE),
			      $nblocks, $nreqs, ($bytes_activ/GIGABYTE), $node)) 
	    if ($n_reactiv > 0 || $nblocks > 0);	    
    } else {
	# Lots of through traffic - don't allocate
	# Check how many blocks there are waiting
	my ($nblocks) = &dbexec($dbh, qq{
	    select count(*) from t_dps_block_dest where destination = :node and state = 0
	    }, ":node" => $node)->fetchrow();
	$self->Warn("through-traffic limit reached for node=$node, ",
		    "no new block destinations activated out of $nblocks")
	    if $nblocks;
    }
}

# Get a list of blocks destined for a node in order of request age
sub getDestinedBlocks_ByAge
{
    my ($dbh, $node) = @_;
    my $blocks = [];

    my $q = &dbexec($dbh, qq{
	select bd.dataset, bd.block, bd.priority, b.bytes
         from t_dps_block_dest bd
	 join t_dps_block b on b.id = bd.block
        where bd.destination = :node
          and bd.state <= 0
          and exists (select 1 from t_dps_block_replica br
   		       where br.block = bd.block and br.is_active = 'y')
	  order by bd.time_create asc},
		    ":node" => $node);

    while (my $b = $q->fetchrow_hashref() ) {
	push @{$blocks}, $b;
    }
    
    return $blocks;
}



# Get a list of blocks destined for a node by load-balancing datasets.
# This attempts to allocate blocks from all requested datasets evenly 
sub getDestinedBlocks_DatasetBalance
{
    my ($dbh, $node) = @_;
    my $blocks = [];
    
    # Get current requests by dataset
    my $q_current = &dbexec($dbh, qq{
	select bd.dataset, sum(nvl(xf.filesize,0)) bytes
	  from t_dps_block_dest bd
	  left join t_xfer_request xq on xq.inblock = bd.block and xq.destination = bd.destination
	  left join t_xfer_file xf on xf.id = xq.fileid
	 where bd.state <= 1 and bd.destination = :node
         group by bd.dataset },
		    ':node' => $node);

    # Creates a hashref like $$allocation{ $dataset } = { BYTES => $bytes }
    my $allocation = $q_current->fetchall_hashref('DATASET');
    
    # Get destined blocks (with dataset information)
    my $q_destined = &dbexec($dbh, qq{
	select bd.dataset, bd.block, bd.priority, b.bytes
	  from t_dps_block_dest bd
	  join t_dps_block b on b.id = bd.block
         where bd.destination = :node
           and bd.state <= 0
           and exists (select 1 from t_dps_block_replica br
		       where br.block = bd.block and br.is_active = 'y') },
			     ":node" => $node);

    # Creates a hashref like $$destined{ $dataset }{ $block } = { PRIORITY => $priority, BYTES => $bytes }
    my $destined = $q_destined->fetchall_hashref(['DATASET', 'BLOCK']);
   
    # Initialize unallocated datasets
    foreach my $dataset (keys %{$destined}) {
	$$allocation{$dataset}{BYTES} ||= 0;
    }

    # Build ordered list of blocks by load-balancing based on dataset bytes
  DATASET:  while ( scalar keys %{$destined} ) {
      my ($min_dataset, $next_smallest) = 
	  sort {$$allocation{$a}{BYTES} <=> $$allocation{$b}{BYTES}} keys %{$allocation};
      my $fill_to = $next_smallest ? $$allocation{$next_smallest}{BYTES} : 10**38;

      my @min_dataset_blocks = values %{ $$destined{$min_dataset} };
      while ( $$allocation{$min_dataset}{BYTES} <= $fill_to) {
	  if  ( ! @min_dataset_blocks ) {
	      # No more blocks - stop trying to fill it
	      delete $$allocation{$min_dataset};
	      delete $$destined{$min_dataset};
	      next DATASET;
	  }
	  my $b = shift @min_dataset_blocks;
	  push @{$blocks}, $b;
	  $$allocation{$min_dataset}{BYTES} += $$b{BYTES};
	  delete $$destined{$$b{DATASET}}{$$b{BLOCK}};
      }
  } 
    return $blocks;
}



sub routeFiles
{
    my ($self, $dbh, $links, @nodes) = @_;

    ######################################################################
    # Phase 2: Expand file requests into transfer paths through the
    # network.  For each request we build a minimum cost path from
    # available replicas using a routing table of network links and
    # current traffic conditions.  The transfer paths are refreshed
    # regularly to account for changes in network conditions.
    #
    # In other words, each destination node decides the entire path
    # for each file, using network configuration information it
    # obtains from other nodes.  For correctness it is important that
    # the entire route is built by one node using a consistent network
    # snapshot, building routes piecewise at each node using only
    # local information does not produce correct results.
    #
    # We begin with file replicas for each active file request and
    # current network conditions.  We calculate a least-cost transfer
    # path for each file.  We then update the database.

    # Read requests and replicas for requests without paths
    my $now = &mytimeofday();
    my $costs = {};
    my $ndone = 0;
    my $finished = 0;
    my $saved = undef;
    my $q = &dbexec($dbh, qq{
	select
	    xq.destination, xq.fileid, f.filesize,
	    xq.priority, xq.time_create, xq.time_expire,
	    xr.node, xr.state
	from t_xfer_request xq
	  join t_xfer_file f
	    on f.id = xq.fileid
	  join t_xfer_replica xr
	    on xr.fileid = xq.fileid
	where xq.state = 0
	  and xq.time_expire > :now
	  and not exists (select 1 from t_xfer_path xp
			  where xp.to_node = xq.destination
			    and xp.fileid = xq.fileid)
	order by destination, fileid},
	":now" => $now);
    while (! $finished)
    {
	$finished = 1;
	my %requests;
	my ($nreqs, $nfail) = (0, 0);
	my ($discarded, $existing) = (0, 0);
	my ($nhops, $nvalid) = (0, 0);
	my ($inserted, $updated) = (0, 0);
	while (my $row = $saved || $q->fetchrow_hashref())
	{
	    $saved = undef;
	    my $dest = $$row{DESTINATION};
	    next unless grep $dest == $_, @nodes;

	    my $file = $$row{FILEID};
	    my $size = $$row{FILESIZE};
	    
	    # Round size of file to the nearest 500 of the unit below its scale
	    my $unit;
	    if    ($size > TERABYTE) { $unit = GIGABYTE; }
	    elsif ($size > GIGABYTE) { $unit = MEGABYTE; }
	    elsif ($size > MEGABYTE) { $unit = KILOBYTE; }
	    else                     { $unit = BYTE;     }
	    my $sizebin = (int($size / (500*$unit))+1)*(500*$unit);

	    if (! exists $requests{$dest}{$file})
	    {
		if ($nreqs >= 50_000)
		{
		    $finished = 0;
		    $saved = $row;
		    last;
		}
		$nreqs++;
	    }

	    $requests{$dest}{$file} ||= { DESTINATION => $dest,
					  FILEID => $file,
					  FILESIZE => $size,
					  SIZEBIN => $sizebin,
					  PRIORITY => $$row{PRIORITY},
					  TIME_CREATE => $$row{TIME_CREATE},
					  TIME_EXPIRE => $$row{TIME_EXPIRE} };
	    $requests{$dest}{$file}{REPLICAS}{$$row{NODE}} = $$row{STATE};
	    $self->routeCost($links, $costs, $$row{NODE}, $$row{STATE}, $sizebin, 0);
	}

	# Build collection of all the hops and failed routing attempts
	my @allreqs = map { values %$_ } values %requests;
	my %allhops;
	my @failedreqs;
	my $probecosts = {};
	foreach my $req (@allreqs)
	{
	    # Build optimal file path
	    my $ok = $self->routeFile($now, $links, $costs, $probecosts, $req);
	    if ($ok) 
	    {
		foreach my $hop (@{$$req{PATH}})
		{
		    $allhops{$$hop{TO_NODE}}{$$req{FILEID}} ||= $hop;
		}
	    }
	    else { push @failedreqs, $req; }
	}

	# Compare with what is already in the database.  Keep new and better.
	# TODO: reduce memory:  possible to restrict this by destinations?
	my $qpath = &dbexec($dbh, qq{
	    select to_node, fileid, is_valid, is_local, total_cost
	    from t_xfer_path});
	while (my ($to, $file, $valid, $local, $cost) = $qpath->fetchrow())
	{
	    $existing++;

	    # If we are not considering replacement, skip this.
	    next if ! exists $allhops{$to}{$file};

	    # If the replacement is not better, skip this.
	    my $p = $allhops{$to}{$file};
	    if (! ($$p{IS_LOCAL} > $local
		   || ($$p{IS_LOCAL} == $local
		       && ($$p{IS_VALID} > $valid
			   || ($$p{IS_VALID} == $valid
			       && ($$p{TOTAL_LATENCY} || 0) < $cost)))))
	    {
		$$p{UPDATE} = 0;
		$discarded++;
		next;
	    }

	    # The replacement is better, replace this one.
	    $$p{UPDATE} = 1;
	}

	# Build arrays for database operation.
	my (%iargs, %uargs, %destnodes);
	foreach my $to (keys %allhops)
	{
	    foreach my $file (keys %{$allhops{$to}})
	    {
		my $hop = $allhops{$to}{$file};
		$nhops++;

		# Skip if we decided this wasn't worth looking at.
		next if exists $$hop{UPDATE} && ! $$hop{UPDATE};

		# Fill insert or update structure as appropriate.
		my $n = 1;
		my $args = $$hop{UPDATE} ? \%uargs : \%iargs;
		push(@{$$args{$n++}}, $$hop{DESTINATION});  # xp.destination
		push(@{$$args{$n++}}, $$hop{INDEX});  # xp.hop
		push(@{$$args{$n++}}, $$hop{SRC_NODE}); # xp.src_node
		push(@{$$args{$n++}}, $$hop{FROM_NODE}); # xp.from_node
		push(@{$$args{$n++}}, $$hop{PRIORITY}); # xp.priority
		push(@{$$args{$n++}}, $$hop{IS_LOCAL}); # xp.is_local
		push(@{$$args{$n++}}, $$hop{IS_VALID}); # xp.is_valid
		push(@{$$args{$n++}}, ($$hop{LINK_LATENCY} || 0) + ($$hop{XFER_LATENCY} || 0)); # xp.cost
		push(@{$$args{$n++}}, ($$hop{TOTAL_LATENCY} || 0)); # xp.total_cost
		push(@{$$args{$n++}}, ($$hop{LINK_RATE} || 0)); # xp.penalty
		push(@{$$args{$n++}}, $$hop{TIME_REQUEST}); # xp.time_request
		push(@{$$args{$n++}}, $now); # xp.time_confirm
		push(@{$$args{$n++}}, $$hop{TIME_EXPIRE}); # xp.time_expire
		push(@{$$args{$n++}}, $file); # xp.fileid
		push(@{$$args{$n++}}, $to); # xp.to_node
		$destnodes{$$hop{DESTINATION}} = 1;
		$nvalid++ if $$hop{IS_VALID};
	    }
	}

	# Insert and update paths as appropriate.
	&dbexec($dbh, qq{
	    insert into t_xfer_path
	    (destination, hop, src_node, from_node, priority, is_local,
	     is_valid, cost, total_cost, penalty, time_request,
	     time_confirm, time_expire, fileid, to_node)
	    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)},
	    %iargs) if %iargs;

	&dbexec($dbh, qq{
	    update t_xfer_path
	    set destination = ?, hop = ?, src_node = ?, from_node = ?,
		priority = ?, is_local = ?, is_valid = ?, cost = ?,
		total_cost = ?, penalty = ?, time_request = ?,
		time_confirm = ?, time_expire = ?
	    where fileid = ? and to_node = ?},
	    %uargs) if %uargs;
	
	# Get requests which have no source replicas, so that we take
	# them out of the active state and throw a warning about them
	my $q_nosrc = &dbexec($dbh, qq{
	    select xq.destination, xq.fileid
	      from t_xfer_request xq
	     where xq.state = 0
	       and xq.time_expire > :now
	       and not exists (select 1 from t_xfer_replica xr
			        where xr.fileid = xq.fileid)
	   }, ":now" => $now);

	while (my $row = $q_nosrc->fetchrow_hashref()) {
	    push @failedreqs, $row;
	}

	# Mark requests which could not be routed invalid
	my %fargs;
	my %fstats;
	foreach my $req (@failedreqs) {
	    # state 3='no path to destination', use shorter expiration time (2 to 5 hours default) 
	    # state 4='no source replicas', use standard expiration time (7 to 10 hours default)
	    my ($state, $texpire);
	    my $dest = $$req{DESTINATION};
	    my $file = $$req{FILEID};
	    if (defined $$req{REPLICAS} && keys %{$$req{REPLICAS}}) {
		$fstats{$dest}{'no path to destination'}++;
		$state = 3;
		$texpire = $now + $MIN_REQ_EXPIRE/3.5 + rand($EXPIRE_JITTER);
	    } else {
		$fstats{$dest}{'no source replicas'}++;
		$state = 4;
		$texpire = $now + $MIN_REQ_EXPIRE + rand($EXPIRE_JITTER);
	    }
	    my $n = 1;
	    push(@{$fargs{$n++}}, $state);
	    push(@{$fargs{$n++}}, $texpire);
	    push(@{$fargs{$n++}}, $dest);
	    push(@{$fargs{$n++}}, $file);
	}
	
	&dbexec($dbh, qq{
	    update t_xfer_request
	       set state = ?, time_expire = ?
	     where destination = ? and fileid = ?}, %fargs) if %fargs;

	$dbh->commit();

	# Report routing statistics
	if (%fstats && $$self{VERBOSE}) {
	    foreach my $dest (sort keys %fstats) {
		foreach my $reason (sort keys %{$fstats{$dest}}) {
		    $self->Warn("failed to route ",
				$fstats{$dest}{$reason},
				" files to node=$dest:  $reason");
		}
	    }
	}
    
	$inserted = %iargs ? scalar @{$iargs{1}} : 0;
	$updated = %uargs ? scalar @{$uargs{1}} : 0;
	$ndone += $inserted + $updated;
	$nfail = scalar @failedreqs;

	my %node_names = reverse %{$$self{NODES_ID}};
	my $destnode_list = join ' ', sort @node_names{keys %destnodes};
	$self->Logmsg("routed files:  $existing existed, $updated updated, $inserted new,"
		. " $nvalid valid, $discarded discarded of $nhops paths with $nfail failures"
		. " computed for $nreqs requests for the destinations"
		. " $destnode_list")
	    if $nreqs;

	# Now would be a great time to go for a long holiday :-)
	$self->maybeStop();
    }

    # Bring next slow synchornisation forward if we didn't route any
    # files and the file pump agent has given us a hint to restart
    # and next slow flush would be relatively far away.
    if (! $ndone)
    {
	my $markerval = (defined $$self{FLUSH_MARKER}
			 ? "currval" : "nextval");
	my ($marker) = &dbexec($dbh, qq{
	    select seq_xfer_done.$markerval from dual})
	    ->fetchrow();

	$$self{NEXT_SLOW_FLUSH} = $now
	    if ($marker > ($$self{FLUSH_MARKER} || -1)
		&& $$self{NEXT_SLOW_FLUSH} > $now + $$self{FLUSH_PERIOD}/4);

	$dbh->commit();
    }

    # Return how much we did.
    return $ndone;
}

# Calculate prototype file transfer cost.  The only factor affecting
# the cost of a file in the network is its source node and whether
# the file is staged in; the rest is determined by link parameters.
# So there is no reason to calculate the full minimum-spanning tree
# algorithm for every file -- we just calculate prototype costs for
# "staged file at node n", and propagate those costs to the entire
# network.  The actual file routing then just picks cheapest paths.
sub routeCost
{
    my ($self, $links, $costs, $node, $state, $sizebin, $probe) = @_;

    # If we already have a cost for this prototype, return immediately
    return if (exists $$costs{$node}
	       && exists $$costs{$node}{$state}
	       && exists $$costs{$node}{$state}{$sizebin});

    # Initialise the starting point: instant access for staged file,
    # 0h30 for not staged.  We optimise the transfer cost as the
    # estimated time of arrival, i.e. minimise transfer time,
    # accounting for the link latency (existing transfer queue).
    my %todo = ($node => 1);
    my $latency = $state ? 0 : 1800;
    my $paths = $$costs{$node}{$state}{$sizebin} = {};
    $$paths{$node} = {
	SRC_NODE => $node,
	FROM_NODE => $node,
	TO_NODE => $node,
	LINK_LATENCY => 0,
	LINK_RATE => undef,
	XFER_LATENCY => $latency,
	TOTAL_LINK_LATENCY => 0,
	TOTAL_XFER_LATENCY => $latency,
	TOTAL_LATENCY => $latency,
	TOTAL_LOCAL => 1,
	IS_LOCAL => 1,
	HOPS => 0,
	REMOTE_HOPS => 0
    };

    # print Dumper($links);
    # Now use Dijkstra's algorithm to compute minimum spanning tree.
    while (%todo)
    {
	foreach my $from (keys %todo)
	{
	    # Remove from list of nodes to do.
	    delete $todo{$from};

	    # Compute cost at each neighbour.
	    foreach my $to (keys %{$$links{$from}})
	    {
		# The rate estimate we use is the link nominal rate if
		# we have no performance data, where the nominal rate
		# (default 0.5 MB/s) is divided by the database link distance.
		# If we have rate performance data and it shows the
		# link to be reasonably healthy, use that information.
		# If the link is unhealthy and we are probing after
		# failed routing, use the nominal rate.  Otherwise use
		# an "infinite" rate that will be cut-off by later
		# route validation.

                my $old_rate = $$links{$from}{$to}{XFER_RATE};
                my $new_rate = $self->get_xfer_rate($to,$from,$old_rate);
                $$links{$from}{$to}{XFER_RATE} = $new_rate; 
 
		my $nominal = $NOMINAL_RATE / $$links{$from}{$to}{HOPS};
		my $latency = ($probe ? 0 : ($$links{$from}{$to}{XFER_LATENCY} || 0));
                #my $rate = ((! defined $new_rate || ($probe && $new_rate < $nominal)) ? $nominal : $new_rate);

		my $rate = ((! defined $$links{$from}{$to}{XFER_RATE}
			     || ($probe && $$links{$from}{$to}{XFER_RATE} < $nominal))
			    ? $nominal : $$links{$from}{$to}{XFER_RATE});
		my $xfer = ($rate ? $sizebin / $rate : 7*86400);
		my $total = $$paths{$from}{TOTAL_LATENCY} + $latency + $xfer;

		# Separately keep track of this hop's locality and
		# whether the whole path so far is local
		my $thislocal = 0;
		$thislocal = 1 if (exists $$links{$from}
				   && exists $$links{$from}{$to}
				   && $$links{$from}{$to}{IS_LOCAL});
		my $local = ($thislocal && $$paths{$from}{TOTAL_LOCAL} ? 1 : 0);

		# If we would involve more than one WAN hop, incur penalty.
		# This value is larger than cut-off for valid paths later.
		if ($$paths{$from}{REMOTE_HOPS} && ! $thislocal)
		{
		    $xfer  += 100*$LATENCY_THRESHOLD;
		    $total += 100*$LATENCY_THRESHOLD;
		}

		# Update the path if there is none yet, if we have local
		# path and existing is not local, or if we now have a
		# better cost without changing local attribute.
		if (! exists $$paths{$to}
		    || ($local && ! $$paths{$to}{TOTAL_LOCAL})
		    || ($local == $$paths{$to}{TOTAL_LOCAL}
			&& $total < $$paths{$to}{TOTAL_LATENCY}))
		{
		    # No existing path or it's more expensive.
		    $$paths{$to} = { SRC_NODE => $$paths{$from}{SRC_NODE},
				     FROM_NODE => $from,
				     TO_NODE => $to,
				     LINK_LATENCY => $latency,
				     LINK_RATE => $rate,
				     XFER_LATENCY => $xfer,
				     TOTAL_LINK_LATENCY => $$paths{$from}{TOTAL_LINK_LATENCY} + $latency,
				     TOTAL_XFER_LATENCY => $$paths{$from}{TOTAL_XFER_LATENCY} + $xfer,
				     TOTAL_LATENCY => $total,
				     TOTAL_LOCAL => $local,
				     IS_LOCAL => $thislocal,
				     HOPS => $$paths{$from}{HOPS} + 1,
				     REMOTE_HOPS => $$paths{$from}{REMOTE_HOPS} + (1-$thislocal) };
		    $todo{$to} = 1;
		}
	    }
	}
    }
}

# Select best route for a file.
sub bestRoute
{
    my ($self, $costs, $request) = @_;
    my $dest = $$request{DESTINATION};

    # Use the precomupted replica path costs to pick the cheapest
    # available file we could transfer.
    my $best = undef;
    my $bestcost = undef;
    my $sizebin = $$request{SIZEBIN};
    foreach my $node (keys %{$$request{REPLICAS}})
    {
	my $state = $$request{REPLICAS}{$node};
	next if (! exists $$costs{$node}
		 || ! exists $$costs{$node}{$state}
		 || ! exists $$costs{$node}{$state}{$sizebin}
		 || ! exists $$costs{$node}{$state}{$sizebin}{$dest});
	my $this = $$costs{$node}{$state}{$sizebin};

	next if ($$this{$dest}{REMOTE_HOPS} > 1); # Multi-WAN-hop paths are never the best.

	# Randomly add a fraction of a picosecond to the cost.  This
	# is to randomize the choice of available source replicas if
	# all other factors are equal.
	my $thiscost = $$this{$dest}{TOTAL_LATENCY} + (rand(1) * 1e-12);

	if (! defined $best
	    || $$this{$dest}{TOTAL_LOCAL} > $$best{$dest}{TOTAL_LOCAL}
	    || ($$this{$dest}{TOTAL_LOCAL} == $$best{$dest}{TOTAL_LOCAL}
		&& $thiscost <= $bestcost))
	{
	    $best = $this;
	    $bestcost = $thiscost;
	}
    }

    return ($best, $bestcost);
}

# Computes the optimal route for the file.
sub routeFile
{
    my ($self, $now, $links, $costs, $probecosts, $request) = @_;
    my $dest = $$request{DESTINATION};

    # Select best route.  If it's not a valid one, force re-routing
    # at a reasonably low (2%) probability to create routing probes.
    my ($best, $bestcost) = $self->bestRoute ($costs, $request);
    if (defined $best && $bestcost >= $LATENCY_THRESHOLD && rand() < $PROBE_CHANCE)
    {
	$self->routeCost($links, $probecosts, $_, $$request{REPLICAS}{$_},
			 $$request{SIZEBIN}, 1)
	    for keys %{$$request{REPLICAS}};
	($best, $bestcost) = $self->bestRoute ($probecosts, $request);
	my $prettycost = int($bestcost);
	$self->Logmsg("probed file=$$request{FILEID} to destination=$dest: "
		. ($bestcost < $LATENCY_THRESHOLD
		   ? "new cost $prettycost from src_node=$$best{$dest}{SRC_NODE}"
		   : "did not improve the matters, cost is $prettycost"));
    }

    # Now record path to the cheapest replica found, if we found one.
    delete $$request{PATH};
    if (defined $best)
    {
	my $index = 0;
	my $node = $dest;
	my $valid = $bestcost < $LATENCY_THRESHOLD ? 1 : 0;
	while ($$best{$node}{FROM_NODE} != $$best{$node}{TO_NODE})
	{
	    my $from = $$best{$node}{FROM_NODE};
	    my $item = { %{$$best{$node}} };
	    $$item{INDEX} = $index++;
	    $$item{IS_VALID} = $valid;
	    $$item{DESTINATION} = $$request{DESTINATION};

	    # Reinterpret priority.  This makes local transfers a
	    # higher priority than WAN transfers.
	    $$item{PRIORITY} = 2*$$request{PRIORITY} + (1-$$item{IS_LOCAL});

	    $$item{TIME_REQUEST} = $$request{TIME_CREATE};
	    # Note: It is important to have a large spread of
	    # expiration times for invalid paths avoid
	    # herding effects.  If the path is re-created to soon, we
	    # expect the result will be the same anyway.
	    # Default: 0.7 to 3.7 hours
	    $$item{TIME_EXPIRE} = ($valid ? $$request{TIME_EXPIRE}
				   : $now + $MIN_REQ_EXPIRE/10 + rand($EXPIRE_JITTER));
	    push(@{$$request{PATH}}, $item);
	    $node = $from;
	}

	return 1;
    }
    else
    {
	return 0;
    }
}

# Update transfer request and path statistics.
sub stats
{
    my ($self, $dbh, $pathinfo) = @_;
    my $now = &mytimeofday();

    # Check if we need to update statistics.
    return if $now < $$self{NEXT_STATS};
    $$self{NEXT_STATS} = int($now/300) + 300;

    # Remove previous data and add new information.
    &dbexec($dbh, qq{delete from t_status_path});
    &dbexec($dbh, qq{
	insert into t_status_path
	(time_update, from_node, to_node, priority, is_valid, files, bytes)
	select :now, xp.from_node, xp.to_node, xp.priority, xp.is_valid,
	       count(xp.fileid), nvl(sum(f.filesize),0)
	from t_xfer_path xp join t_xfer_file f on f.id = xp.fileid
	group by :now, xp.from_node, xp.to_node, xp.priority, xp.is_valid},
	":now" => $now);

    &dbexec($dbh, qq{delete from t_status_request});
    &dbexec($dbh, qq{
	insert into t_status_request
	(time_update, destination, state, files, bytes, is_custodial, priority)
	select :now, xq.destination, xq.state,
	       count(xq.fileid), nvl(sum(f.filesize),0), xq.is_custodial,
	       xq.priority
	from t_xfer_request xq join t_xfer_file f on f.id = xq.fileid
	group by :now, xq.destination, xq.state, xq.is_custodial, xq.priority},
	":now" => $now);
    
    # Record path information aggregated by block. Priority is converted back to 
    # the 3-level priority used for block subscriptions, so that local and remote
    # hops on the same path are counted together
    &dbexec($dbh, qq{delete from t_status_block_path});
    &dbexec($dbh, qq{
	insert into t_status_block_path
	(time_update, destination, src_node, block, priority, is_valid,
	 route_files, route_bytes, xfer_attempts, time_request, time_arrive)
       select :now, path.destination, path.src_node, f.inblock, path.priority, path.is_valid,
              count(f.id), sum(f.filesize), sum(xq.attempt), min(xq.time_create), max(path.time_arrive)
         from (
	  select distinct xp.destination, xp.src_node, xp.fileid,
	   decode(xp.is_local, 1, xp.priority/2, 0, (xp.priority-1)/2) priority,
	   xp.is_valid, max(xp.time_confirm+xp.total_cost) time_arrive
	  from t_xfer_path xp
	  group by xp.destination, xp.src_node, xp.fileid,
	   decode(xp.is_local, 1, xp.priority/2, 0, (xp.priority-1)/2),
	   xp.is_valid
	       ) path
         join t_xfer_request xq on xq.destination = path.destination and xq.fileid = path.fileid
         join t_xfer_file f on f.id = xq.fileid
         group by path.destination, path.src_node, f.inblock, path.priority, path.is_valid},
	    ":now" => $now);
    
    &dbexec($dbh, qq{delete from t_status_block_request});
    &dbexec($dbh, qq{
	insert into t_status_block_request
	(time_update, destination, block, priority, is_custodial,
	 state, request_files, request_bytes, xfer_attempts, time_request)
	select :now, xq.destination, xq.inblock, xq.priority, xq.is_custodial,
	       xq.state, count(f.id), sum(f.filesize), sum(xq.attempt), min(xq.time_create)
	from t_xfer_request xq
	join t_xfer_file f on f.id = xq.fileid
	group by xq.destination, xq.inblock, xq.priority, xq.is_custodial, xq.state},
	    ":now" => $now);
    
    # Block arrival time prediction
    
    $self->mergeStatusBlockArrive();

    $dbh->commit();
    $self->Logmsg("updated statistics");
}

# Event to read external source for rate calculations
# Initialize all POE events this object handles
sub _poe_init
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  $kernel->state('load_external_source_rate', $self);
  $kernel->yield('load_external_source_rate'); # start event
}

# Load external source for rate calculation
sub load_external_source_rate 
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my ($age_file,$fh,$filename);
  $^T = time();   #making sure delta times are accurate

  $kernel->delay_set('load_external_source_rate', $self->{EXTERNAL_RATE_WAIT});  #come back again

  foreach $filename ( @{$self->{EXTERNAL_RATE_FILE}})
  { 
    if ( -e $filename  && -r $filename ) {
      $age_file = -M $filename;
      if ( $self->{EXTERNAL_RATE_AGE}{$filename} < 0 || $age_file < $self->{EXTERNAL_RATE_AGE}{$filename} ) { 
        $self->Logmsg("Loading external source file $filename");
        open $fh, '<', $filename  or die "error opening $filename: $!";
        $self->{EXTERNAL_RATE_DATA}{$filename} = eval do { local $/; <$fh> };
        print($@) if $@;        
        #print Dumper($self->{EXTERNAL_RATE_DATA}{$filename});
      } else {
        $self->Logmsg("External source file $filename has not changed, age of file $age_file");
      }
      $self->{EXTERNAL_RATE_AGE}{$filename} = $age_file; 
    } else {
      $self->{EXTERNAL_RATE_DATA}{$filename} = undef;
      $self->Alert("File $filename does not exist. Un-pluging external source for rate calculations") 
      if ( $self->{EXTERNAL_RATE_AGE}{$filename} > -2 );
      $self->{EXTERNAL_RATE_AGE}{$filename} = -2;
    }
  }

}

sub get_xfer_rate
{
    my $self = shift;
    my ($to,$from,$link_rate) = @_;

    my $avg_ext = 0;
    my $n_ext   = 0;

    foreach my $filename ( @{$self->{EXTERNAL_RATE_FILE}} )
    {
      my $ext_rate = $self->{EXTERNAL_RATE_DATA}{$filename}{$from}{$to}{XFER_RATE};
      if (defined $ext_rate) {
        $self->{EXTERNAL_RATE_DATA}{$filename}{$from}{$to}{XFER_RATE} = undef;
        $avg_ext += $ext_rate;
        $n_ext++; 
      }
    }
 
    my $avg_rate = ($n_ext > 0) ?  $avg_ext/$n_ext : $link_rate;    

    #$Data::Dumper::Indent = 0; 
    #print Dumper([$from,$to,$link_rate,$avg_ext,$avg_rate]), "\n";
    #$Data::Dumper::Indent = 3;
 
    return $avg_rate;
}

1;

=pod

=head1 NAME

PHEDEX::Infrastructure::FileRouter::Agent - the file routing agent.

=head1 DESCRIPTION

The file router agent is responsible for activating "destined blocks"
for transfer, creating file-level transfer requests, and then
calculating the optimal transfer path for these requests from the
available source replicas.

This agent is the first in line for determining file transfer order
and priority, and makes the important choice of which source node to
use for those transfers.  It also manages the expiration times of
transfers throughout the system, and determines how volitile the
transfer system is, where low volitility means sticking with the
choice of source replica for a long time, giving sites a chance to fix
problems in situ, and high volitility means giving up on failing
source nodes quickly and choosing another.

The agent activates a limited number of files per destination at a
time.  This is to reduce the work the agent has to do and the size of
the tables it manages to feasible levels.  It should activate files at
a rate well beyond the bandwidth limits of the destination nodes.  It
activates destinations and makes a transfer plan that is valid for
many hours, and which can be extended for days if the plan remains
good.

The routing is done by using Dijkstra's algorithm to calculate the
minimum cost path from available source replicas to requested
destinations.  Cost is calculated in terms of the estimated latency to
transfer a file over a path, which uses the recent transfer rates and
pending queue to predict how long an additional transfer would take
over that link.  This algorithm is capable of routing files over
multiple wide-area network hops, but this capability is currently
disabled due to lack of a buffer management mechanism for itermediate
hops.

=head1 TABLES USED

=over

=item L<t_dps_block_dest|Schema::OracleCoreBlock/t_dps_block_dest>

Activate blocks for transfer.

=item L<t_xfer_request|Schema::OracleCoreTransfer/t_xfer_request>

Represents a file request, a file which should be transferred to a
destination. Rows only exist for activated blocks.

=item L<t_xfer_path|Schema::OracleCoreTransfer/t_xfer_path>

Represents the transfer path.  Each row is one "hop", a
from_node,to_node pair for a given file.  The collection of hops for a
given fileid and destination is the whole transfer path.

=item L<t_adm_link_param|Schema::OracleCoreTopo/t_adm_link_param>

Read by this agent to determine what the rate and latency over a hop
is, which goes into the path cost calculation.

=back

=head1 COOPERATING AGENTS

=over

=item L<BlockAllocator|PHEDEX::BlockAllocator::Agent>

Before this agent can activate blocks for transfer, BlockAllocator
decides which blocks should be transferred to destination nodes.

=item L<PerfMonitor|PHEDEX::Monitoring::PerfMonitor::Agent>

Keeps track of recent link rate and latency (pending transfer queue /
rate), which are inputs to the routing algorithm.

=item L<FileIssue|PHEDEX::Infrastructure::FileIssue::Agent>

After this agent decides the transfer path, FileIssue creates transfer
tasks.

=item L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>

Creates file replicas, which complete the file request and end the
life of the transfer path.

=back

=head1 STATISTICS

=over

=item L<t_status_path|Schema::OracleCoreStatus::t_status_path>

Per-link sums of files/sizes for routed paths.

=item L<t_status_request|Schema::OracleCoreStatus::t_status_request>

Per-destination sums of files/sizes for requested files.

=item L<t_status_block_path|Schema::OracleCoreStatus::t_status_block_path>

Per-path, per-block sums of files/sizes of routed paths.

=item L<t_status_block_request|Schema::OracleCoreStatus::t_status_block_request>

Per-destination, per-block sums of files/sizes of requested files.

=item L<t_history_link_stats|Schema::OracleCoreStatus::t_history_link_stats>

confirm_files and confirm_bytes contain per-link sums of routed paths.
param_rate and param_latency contains the main inputs to the routing
algorithm.

=item L<t_history_dest|Schema::OracleCoreStatus::t_history_dest>

request_files and request_bytes contain the per-destination sum of
data activated for routing / transfer by this agent.  idle_files and
idle_bytes contain the amount of requests which are not in an active
state.

=back

=head1 SEE ALSO

=over

=item L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>

=back

=cut
