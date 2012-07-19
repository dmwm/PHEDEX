package PHEDEX::Monitoring::PerfMonitor::Agent;
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
    my $compact = time() + 3600;		# Delay compact at start-up
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My TMDB node name
	          WAITTIME => 60,		# Agent activity cycle
		  NEXT_RUN => 0,		# Next time to run
		  NEXT_COMPACT => $compact,	# Next time to compact old entries
		  ME => 'PerfMonitor',
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Update database.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    eval
    {
	$dbh = $self->connectAgent();

	# Use 5-minute binning.
	my $now = &mytimeofday();
	my $timewidth = 300;
	my $timebin = int($now/$timewidth)*$timewidth;

	# Don't run until we need to.
	return if $now < $$self{NEXT_RUN};
	$$self{NEXT_RUN} = $timebin + $timewidth + 60;

	# PART I

	# Summarise various system aspects into stats tables.  This
	# covers only elements not already maintained by some other
	# agent: to avoid data trashing we usually have the agent
	# in charge of the data also maintaining the stats.
	#   - FilePump updates t_status_task
	#   - FileRouter updates t_status_request and t_status_path
	#   - This agent maintains the rest, but could rationalise
	#     in particular with BlockMonitor and BlockAllocate

	my @rv;
	my @log;

	# Summarise block destination status.
	# FIXME: block destination -> subscriptions!?
	&dbexec($dbh, qq{delete from t_status_block_dest});
	@rv = &dbexec($dbh, qq{
	    insert into t_status_block_dest
	    (time_update, destination, state, files, bytes, is_custodial)
	    select :now, bd.destination, bd.state,
	           count(f.id), nvl(sum(f.filesize),0), bd.is_custodial
	    from t_dps_block_dest bd
	      join t_dps_file f on f.inblock = bd.block
	    group by :now, bd.destination, bd.state, bd.is_custodial},
	    ":now" => $now);
	push @log, [$rv[1]+0, "status_block_dest"];

	# Summarise file origins.
	&dbexec($dbh, qq{delete from t_status_file});
	@rv = &dbexec($dbh, qq{
	    insert into t_status_file
	    (time_update, node, files, bytes)
	    select :now, br.node,
	           nvl(sum(br.src_files),0),
	           nvl(sum(br.src_bytes),0)
	    from t_dps_block_replica br
	    group by :now, br.node},
	    ":now" => $now);
	push @log, [$rv[1]+0, "status_file"];

	# Summarise node replicas
	&dbexec($dbh, qq{delete from t_status_replica});
	@rv = &dbexec($dbh, qq{
	    insert into t_status_replica
	    (time_update, node, state, files, bytes, is_custodial)
	    select :now, br.node, 0,
	           nvl(sum (br.node_files), 0), nvl(sum (br.node_bytes), 0), br.is_custodial
	    from t_dps_block_replica br
	    group by br.node, br.is_custodial },
	    ":now" => $now);
	push @log, [$rv[1]+0, "status_replica"];

	# Summarise missing files.  We cannot simply use
	# t_status_block_dest - t_status_replica because information
	# about which data is subscribed is lost
	&dbexec($dbh, qq{delete from t_status_missing});
	@rv = &dbexec($dbh, qq{
	    insert into t_status_missing
	    (time_update, node, files, bytes, is_custodial)
	    select :now, br.node,
	           nvl(sum (br.dest_files - br.node_files), 0),
	           nvl(sum (br.dest_bytes - br.node_bytes), 0),
	           br.is_custodial
	      from t_dps_block_replica br
	     where br.dest_files is not null and br.dest_files != 0
	     group by br.node, br.is_custodial },
	    ":now" => $now);
	push @log, [$rv[1]+0, "status_missing"];

	# Sumarize groups
	# We only count data with a subscription to the node
	# (dest_files not null), because that is the only data which
	# could be allocated to a group
	&dbexec($dbh, qq{delete from t_status_group});
	@rv = &dbexec($dbh, qq{
	    insert into t_status_group
	    (time_update, node, user_group,
	     dest_files, dest_bytes, node_files, node_bytes)
	    select :now, br.node, br.user_group,
                   nvl(sum (br.dest_files), 0), nvl(sum (br.dest_bytes), 0),
                   nvl(sum (br.node_files), 0), nvl(sum (br.node_bytes), 0)
	    from t_dps_block_replica br
	    where br.dest_files is not null and br.dest_files != 0
	    group by br.node, br.user_group },
	    ":now" => $now);
	push @log, [$rv[1]+0, "status_group"];

	# PART II

	# Update statistics from the stats tables into the history.
	# These are heart beat routines where we don't want to miss
	# a bin in the time series histogram.
	@rv = &dbexec($dbh, qq{
	    merge into t_history_link_stats h using
	      (select :timebin timebin, :timewidth timewidth,
	      	      from_node, to_node, priority,
	              sum(files) pend_files,
		      sum(bytes) pend_bytes,
	              sum(decode(state,0,files)) wait_files,
	              sum(decode(state,0,bytes)) wait_bytes,
	              sum(decode(state,1,files)) ready_files,
	              sum(decode(state,1,bytes)) ready_bytes,
	              sum(decode(state,2,files)) xfer_files,
	              sum(decode(state,2,bytes)) xfer_bytes
		from t_status_task
		group by :timebin, :timewidth, from_node, to_node, priority) v
	    on (h.timebin = v.timebin and
	        h.from_node = v.from_node and
		h.to_node = v.to_node and
		h.priority = v.priority)
	    when matched then
	      update set
	        h.pend_files = v.pend_files, h.pend_bytes = v.pend_bytes,
	        h.wait_files = v.wait_files, h.wait_bytes = v.wait_bytes,
	        h.ready_files = v.ready_files, h.ready_bytes = v.ready_bytes,
	        h.xfer_files = v.xfer_files, h.xfer_bytes = v.xfer_bytes
	    when not matched then
	      insert (timebin, timewidth, from_node, to_node, priority,
	              pend_files, pend_bytes, wait_files, wait_bytes,
		      ready_files, ready_bytes, xfer_files, xfer_bytes)
	      values (v.timebin, v.timewidth, v.from_node, v.to_node, v.priority,
	              v.pend_files, v.pend_bytes, v.wait_files, v.wait_bytes,
		      v.ready_files, v.ready_bytes, v.xfer_files, v.xfer_bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_link_stats (tasks)"];

	# Routing statistics.
	@rv = &dbexec($dbh, qq{
	    merge into t_history_link_stats h using
	      (select :timebin timebin, :timewidth timewidth,
	      	      from_node, to_node, priority, files, bytes
		from t_status_path where is_valid = 1) v
	    on (h.timebin = v.timebin and
	        h.from_node = v.from_node and
		h.to_node = v.to_node and
		h.priority = v.priority)
	    when matched then
	      update set
	        h.confirm_files = v.files,
		h.confirm_bytes = v.bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.from_node, h.to_node,
		      h.priority, h.confirm_files, h.confirm_bytes)
	      values (v.timebin, v.timewidth, v.from_node, v.to_node,
		      v.priority, v.files, v.bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_link_stats (paths)"];

	# Now "close" the link statistics.  This ensures at least one
	# row of nulls for links which have previously had stats, and
	# makes the link parameter calculation below pick up correct
	# "empty" final state.
	@rv = &dbexec($dbh, qq{
            insert into t_history_link_stats
            (timebin, timewidth, from_node, to_node, priority)
            select :timebin, :timewidth, h.from_node, h.to_node, h.priority
            from 
            (
              -- a view representing the latest timebin before now
              (select from_node, to_node, priority, max(timebin) timebin
                 from t_history_link_stats
                where timebin < :timebin
                group by from_node, to_node, priority
              ) prevbin
              -- joined again with the history table in order to get the pend_bytes value
              join t_history_link_stats h
                   on  h.from_node = prevbin.from_node
                   and h.to_node = prevbin.to_node
                   and h.priority = prevbin.priority
                   and h.timebin = prevbin.timebin
              -- optionally joined with the current timebin
              left join
              (select from_node, to_node, priority, 1 testcol
                 from t_history_link_stats
                where timebin = :timebin
                group by from_node, to_node, priority
              ) currbin
              on  prevbin.from_node = currbin.from_node
              and prevbin.to_node = currbin.to_node
              and prevbin.priority = currbin.priority
            )
            -- only those rows which had pend_bytes but do not have a current row
            where h.pend_bytes > 0 and currbin.testcol is null }, 
		":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_link_stats (closed)"];

	# PART III: Node statistics.
	@rv = &dbexec($dbh, qq{
	    merge into t_history_dest h using
	      (select :timebin timebin, :timewidth timewidth, destination,
	              sum(files) files, sum(bytes) bytes,
	              sum(decode(is_custodial,'y',files,0)) cust_dest_files,
	              sum(decode(is_custodial,'y',bytes,0)) cust_dest_bytes
	       from t_status_block_dest
	       group by :timebin, :timewidth, destination) v
	    on (h.timebin = v.timebin and h.node = v.destination)
	    when matched then
	      update set h.dest_files = v.files, h.dest_bytes = v.bytes,
	                 h.cust_dest_files = v.cust_dest_files,
	                 h.cust_dest_bytes = v.cust_dest_bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.node, h.dest_files, h.dest_bytes, h.cust_dest_files, h.cust_dest_bytes)
	      values (v.timebin, v.timewidth, v.destination, v.files, v.bytes, v.cust_dest_files, v.cust_dest_bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_dest (dest)"];

	@rv = &dbexec($dbh, qq{
	    merge into t_history_dest h using
	      (select :timebin timebin, :timewidth timewidth, node, files, bytes
	       from t_status_file) v
	    on (h.timebin = v.timebin and h.node = v.node)
	    when matched then
	      update set h.src_files = v.files, h.src_bytes = v.bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.node, h.src_files, h.src_bytes)
	      values (v.timebin, v.timewidth, v.node, v.files, v.bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_dest (src)"];

	@rv = &dbexec($dbh, qq{
	    merge into t_history_dest h using
	      (select :timebin timebin, :timewidth timewidth, node,
	              sum(files) files, sum(bytes) bytes,
	              sum(decode(is_custodial,'y',files,0)) cust_node_files,
	              sum(decode(is_custodial,'y',bytes,0)) cust_node_bytes
	       from t_status_replica
	       group by :timebin, :timewidth, node) v
	    on (h.timebin = v.timebin and h.node = v.node)
	    when matched then
	      update set
	        h.node_files = v.files, h.node_bytes = v.bytes,
	        h.cust_node_files = v.cust_node_files,
	        h.cust_node_bytes = v.cust_node_bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.node, h.node_files, h.node_bytes, h.cust_node_files, h.cust_node_bytes)
	      values (v.timebin, v.timewidth, v.node, v.files, v.bytes, v.cust_node_files, v.cust_node_bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_dest (node)"];

	@rv = &dbexec($dbh, qq{
	    merge into t_history_dest h using
	      (select :timebin timebin, :timewidth timewidth, node,
	              sum(files) files, sum(bytes) bytes,
	              sum(decode(is_custodial,'y',files,0)) cust_miss_files,
	              sum(decode(is_custodial,'y',bytes,0)) cust_miss_bytes
	       from t_status_missing
	       group by :timebin, :timewidth, node) v
	    on (h.timebin = v.timebin and h.node = v.node)
	    when matched then
	      update set
	        h.miss_files = v.files, h.miss_bytes = v.bytes,
	        h.cust_miss_files = v.cust_miss_files,
	        h.cust_miss_bytes = v.cust_miss_bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.node, h.miss_files, h.miss_bytes, h.cust_miss_files, h.cust_miss_bytes)
	      values (v.timebin, v.timewidth, v.node, v.files, v.bytes, v.cust_miss_files, v.cust_miss_bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_dest (miss)"];

	# Update request statistics.  state = 0 is an active request.
	# Any other state is an inactive request, and therefore the
	# data is "idle"
	@rv = &dbexec($dbh, qq{
	    merge into t_history_dest h
	    using
	      (select :timebin timebin, :timewidth timewidth, destination,
	              sum(files) request_files, sum(bytes) request_bytes,
		      sum(decode(state,0,0,files)) idle_files,
	              sum(decode(state,0,0,bytes)) idle_bytes
		from t_status_request
		group by :timebin, :timewidth, destination) v
	    on (h.timebin = v.timebin and h.node = v.destination)
	    when matched then
	      update set
	        h.request_files = v.request_files, h.request_bytes = v.request_bytes,
	        h.idle_files = v.idle_files, h.idle_bytes = v.idle_bytes
	    when not matched then
	      insert (h.timebin, h.timewidth, h.node,
	              h.request_files, h.request_bytes,
	              h.idle_files, h.idle_bytes)
	      values (v.timebin, v.timewidth, v.destination,
	      	      v.request_files, v.request_bytes,
	      	      v.idle_files, v.idle_bytes)},
	    ":timebin" => $timebin, ":timewidth" => $timewidth);
	push @log, [$rv[1]+0, "history_dest (request)"];

	# Part V: Update link parameters.
	# For each of three time periods, 2 hours, 12 hours, and 2
	# days, this massive query creates or updates link parameters
	# based on recent history in that time period. A 30 min offset is
	# applied to give enough time to all relevant agents to update the stats
	# The following conditions apply:
	#
	# If there is no link parameter information for a given link,
	# the row is created with statistics from the time period:
	#   pend_bytes = the last timebin from t_history_link_stats.pend_bytes
	#   done_bytes = the sum of t_history_link_events.done_bytes
	#   try_bytes  = the sum of t_history_link_events.try_bytes
	#   time_span  = the sum of the bin width from the history tables
	#                for bins that have some data (pend_bytes, done_bytes, 
	#                or try_bytes)
	# If there is a row for a link (i.e., there were more recent
	# statistics available) then the row is updated according to
	# the above if the existing row had:
	#   time_span of null or 0
	#   or null try_bytes or done_bytes
	#
	# In other words, the row is updated to use statistics from a
	# longer time window if there was no queue or transfer
	# information in a smaller time window, or the data was only
	# for queued transfers, and not completed transfers.
       
	&dbexec($dbh, qq{delete from t_adm_link_param});
	my $offset = 1800;
        foreach my $span (2*3600, 12*3600, 2*86400)
	{
	    @rv = &dbexec($dbh, qq{
                merge into t_adm_link_param p using
		  (select
                       from_node, to_node,
                       nvl(sum(pend_bytes) keep (dense_rank last order by timebin asc),0) pend_bytes,
                       sum(done_bytes) done_bytes,
                       sum(try_bytes) try_bytes,
		       sum(decode(has_data,1,timewidth,0)) time_span
                   from (select nvl(hs.from_node,he.from_node) from_node,
                                nvl(hs.to_node,he.to_node) to_node,
                                nvl(hs.timebin,he.timebin) timebin,
                                nvl(hs.timewidth,he.timewidth) timewidth,
                                sum(hs.pend_bytes) pend_bytes, sum(he.done_bytes) done_bytes, sum(he.try_bytes) try_bytes,
                                sign(sum(nvl(hs.pend_bytes,0)) +
                                     sum(nvl(he.done_bytes,0)) +
                                     sum(nvl(he.try_bytes,0))) has_data
                         from t_history_link_stats hs
                           full join t_history_link_events he
                             on he.timebin = hs.timebin
                             and he.from_node = hs.from_node
                             and he.to_node = hs.to_node
                             and he.priority = hs.priority
                         where (hs.timebin is not null and hs.timebin > :period - :offset and hs.timebin <= :now - :offset)
                           or (he.timebin is not null and he.timebin > :period - :offset and he.timebin <= :now - :offset)
		         group by nvl(hs.from_node,he.from_node), nvl(hs.to_node,he.to_node),
			   nvl(hs.timebin,he.timebin), nvl(hs.timewidth,he.timewidth)
                        ) group by from_node, to_node) n
                on (p.from_node = n.from_node and p.to_node = n.to_node)
		when matched then
		  update set p.pend_bytes = n.pend_bytes,
                             p.done_bytes = n.done_bytes,
                             p.try_bytes = n.try_bytes,
                             p.time_span = n.time_span,
			     p.time_update = :now
                  where (p.time_span is null or p.time_span = 0)
                     or (p.done_bytes is null or p.try_bytes is null)
                when not matched then
                  insert (p.from_node, p.to_node, p.pend_bytes, p.done_bytes,
			  p.try_bytes, p.time_span, p.time_update)
		  values (n.from_node, n.to_node, n.pend_bytes, n.done_bytes,
			  n.try_bytes, n.time_span, :now)},
	        ":period" => $timebin - $span, ":now" => $timebin, ":offset" => $offset);
	    push @log, [$rv[1]+0, "link_param (span=$span)"];
	}

	# Now we add blank rows for any link which had no history in
	# the time periods above.  This allows queires on
	# t_adm_link_param to observe all existing links, but links
	# with no recent activity will have all NULL values.

	@rv = &dbexec($dbh, qq{
	    merge into t_adm_link_param p using
	      (select from_node, to_node from t_adm_link) n
	    on (p.from_node = n.from_node and p.to_node = n.to_node)
	    when not matched then
	      insert (from_node, to_node, time_update)
	      values (n.from_node, n.to_node, :now)},
	    ":now" => $timebin);
	push @log, [$rv[1]+0, "link_param (blanks)"];

	# Compute the rate and latency for every link which has some
	# recent activity.  The rate is the transfer rate over the
	# most recent time period with activity (see above).  The
	# latency is the time it would take to complete the current
	# transfer queue.  It is determined as follows:
	#
	# xfer_rate = NULL if no data was queued over this link for 
	#             the time_span period (pend_bytes = 0) and
	#             nothing was transferred (done_bytes = 0)
	#           = done_bytes / time_span if some data was 
	#             transfered for the time_span period 
	#             (done_bytes != 0)
	#           = 0 if no data was transferred over the time_span 
	#             period (done_bytes is NULL)
	# xfer_latency = 0 when no data has been queued over the 
	#                time_span period (pend_bytes = 0)
	#              = pend_bytes / xfer_rate (above) if the rate is
	#                non-zero and it is less than one week
	#              = one week if the xfer_rate is 0 or NULL, or the 
	#                calculated rate is more than one week
	#
	# In short, 0 really means zero, and NULL means the value
	# could not be computed.
	#
	# We require to have at least 1 hour of statistics (time_span
	# >= 3600) or a transfer attempt before making this
	# calculation.  This is to give the site agents a reasonable
	# amount of time to find and attempt any pending tasks.
	@rv = &dbexec($dbh, qq{
	    update (select
	    	      pend_bytes, xfer_rate, xfer_latency,
		      case
		        when nvl(pend_bytes,0) = 0 and nvl(done_bytes,0) = 0 then null
		        when time_span > 0 then
		          nvl(done_bytes,0)/time_span
			else 0
		      end rate
	            from t_adm_link_param
		    where time_span is not null 
                      and (time_span >= 3600 or try_bytes is not null))
	    set xfer_rate = rate,
	        xfer_latency =
		   case
		     when pend_bytes = 0
		       then 0
		     when rate > 0
		       then least(pend_bytes/rate,7*86400)
		     else 7*86400
		   end});
	push @log, [$rv[1]+0, "link_param (rate)"];

	# Log the history of the rate and latency we just calculated.
        @rv = &dbexec($dbh, qq{
	    update t_history_link_stats h
	    set (param_rate, param_latency) =
	      (select xfer_rate, xfer_latency
	       from t_adm_link_param p
	       where p.from_node = h.from_node
	         and p.to_node = h.to_node)
	    where timebin = :timebin},
 	    ":timebin" => $timebin);
	push @log, [$rv[1]+0, "history_link_stats (rate)"];

	$dbh->commit();
	$self->Logmsg("updated: ".join(", ", map { "$$_[0] $$_[1]" } @log));

	# Part VI: Compact old time series data to be in per-hour instead
	# of per-5-minute bins.  We do this only rarely to avoid loading
	# the database servers excessively.  We read the old data stats
	# in memory, merge, and write back.  This is mainly because some
	# of the data is accumulated, some not, and sql makes it awkward
	# to handle both.
	return if ($timebin < $$self{NEXT_COMPACT});
        my $limit = int($timebin/86400)*86400 - 86400;
	$self->compactLinkData($dbh, $limit, "events");
	$self->compactLinkData($dbh, $limit, "stats");
	$self->compactDestData($dbh, $limit);
	$dbh->commit();
	$$self{NEXT_COMPACT} = $timebin + 2*86400; # Every two days
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

sub compactUpdate
{
    my ($self, $dbh, $limit, $table, $stats, $primary) = @_;
    my (@rv, @log);
    @rv = &dbexec($dbh, qq{
	delete from $table
	where timebin < :old and timewidth = 300},
	":old" => $limit);
    push @log, [$rv[1]+0, "deleted"];

    my $i = undef;
    my $rv_total = 0;
    foreach my $data (values %$stats)
    {
	if (! defined $i)
	{
	    my @keys = keys %$data;
	    my %primarykeys = map { $_ => 1 } @$primary;
	    my @valuekeys = grep(! $primarykeys{$_}, @keys);
	    my $sql = "merge into $table t using "
		      . "(select "
		      . join(",", map { ":$_ $_" } @keys)
		      . " from dual) e on ("
		      . join(" and ", map { "t.$_ = e.$_" } @$primary)
		      . ") when matched then update set "
		      . join(", ", map { "t.$_ = nvl(t.$_, 0) + nvl(e.$_, 0)" } @valuekeys)
		      . " when not matched then insert ("
		      . join(",", @keys) . ") values ("
		      . join(",", map { "e.$_" } @keys) . ")";
	    $i = &dbprep($dbh, $sql);
	}
	$rv_total += &dbbindexec($i, map { (":$_" => $$data{$_}) } keys %$data);
    }
    push @log, [$rv_total, "merged"];
    $self->Logmsg("compacted $table: ".join(", ", map { "$$_[0] $$_[1]" } @log));
}

sub compactLinkData
{
    my ($self, $dbh, $limit, $suffix) = @_;
    my %stats;
    my @primary = ('TIMEBIN', 'TO_NODE', 'FROM_NODE', 'PRIORITY');
    my $q = &dbexec($dbh, qq{
	select * from t_history_link_$suffix
	where timebin < :old and timewidth = 300
	order by timebin asc, from_node, to_node, priority},
    	":old" => $limit);
    while (my $row = $q->fetchrow_hashref())
    {
	my $bin = int($$row{TIMEBIN}/3600)*3600;
	my $key = "$bin $$row{FROM_NODE} $$row{TO_NODE} $$row{PRIORITY}";
	if (! exists $stats{$key})
	{
	    $stats{$key} = $row;
	    $$row{TIMETOT} = $$row{TIMEWIDTH};
	}
	else
	{
	    my $s = $stats{$key};
	    $$s{$_} = ($$row{$_} || 0)
		for grep(/^(PEND|WAIT|COOL|READY|XFER|CONFIRM)_/, keys %$row);
	    $$s{$_} = ($$s{$_} || 0) + ($$row{$_} || 0)
		for grep(/^(AVAIL|DONE|TRY|FAIL|EXPIRE)_/, keys %$row);
	    $$s{$_} = ($$s{$_} || 0) + ($$row{$_} || 0)*$$row{TIMEWIDTH}
		for grep(/^(PARAM)_/, keys %$row);
	    $$s{TIMETOT} += $$row{TIMEWIDTH};
	}
	$$row{TIMEBIN} = $bin;
	$$row{TIMEWIDTH} = 3600;
    }

    foreach my $s (values %stats)
    {
	if ($suffix ne 'events')
	{
	    if ($$s{TIMETOT})
	    {
	        $$s{PARAM_RATE} = ($$s{PARAM_RATE} || 0) / $$s{TIMETOT};
	        $$s{PARAM_LATENCY} = ($$s{PARAM_LATENCY} || 0) / $$s{TIMETOT};
	    }
	    else
	    {
	        $$s{PARAM_RATE} = 0;
	        $$s{PARAM_LATENCY} = 0;
            }
	}
	delete $$s{TIMETOT};
    }

    $self->compactUpdate ($dbh, $limit, "t_history_link_$suffix",
			  \%stats, \@primary);
}

sub compactDestData
{
    my ($self, $dbh, $limit) = @_;
    my %stats;
    my @primary = ('TIMEBIN', 'NODE');
    my $q = &dbexec($dbh, qq{
	select * from t_history_dest
	where timebin < :old and timewidth = 300
	order by timebin asc, node},
    	":old" => $limit);
    while (my $row = $q->fetchrow_hashref())
    {
	my $bin = int($$row{TIMEBIN}/3600)*3600;
	my $key = "$bin $$row{NODE}";
	$$row{TIMEBIN} = $bin;
	$$row{TIMEWIDTH} = 3600;
	if (! exists $stats{$key})
	{
	    $stats{$key} = $row;
	}
	else
	{
	    my $s = $stats{$key};
	    $$s{$_} = ($$row{$_} || 0)
		for grep(/^(DEST|NODE|REQUEST|IDLE)_/, keys %$row);
	}
    }

    $self->compactUpdate ($dbh, $limit, "t_history_dest",
			  \%stats, \@primary);
}

1;

=pod

=head1 NAME

PerfMonitor - maintain transfer performance statistics

=head1 DESCRIPTION

The PerfMonitor agent is responsible for maintaining a large number of
transfer and transfer queue statistics, including a number system
snapshot statistics and historical statistics.

System snapshot statistics describe some aspect of the system at a
single point in time.  These statistics aappear in C<t_status_*>
tables and are usually maintained by the agent responsible for the
detailed data.
(e.g. L<FilePump|PHEDEX::Infrastructure::FilePump::Agent> maintains
C<t_status_task>, because FilePump is responsible for tasks).
However, for status tables that don't fit into this pattern
PerfMonitor maintains the status snapshot.

PerfMonitor maintains queue-type history statistics.  History
statistics are those that are valid for a given timestamp, and kept
for all of time.  PerfMonitor writes historical statistics into
C<t_history_*> tables in a "heartbeat" fashion.  This means that it
samples the current system statistcs at regular time intervals and
writes them to the history table.  Because it works in this fashion it
is important that the agent finishes its cycle in a time less than the
desired sampling frequency.  The agent currently samples system
statistics every 5 minutes, so it must complete its cycle in under 5
minutes.

Finally, PerfMonitor is responsible for compacting historical
statistics.  Statistics are sampled every 5 minutes normally, but
older statistics are compacted into time bins 1 hour wide in order to
reduce the amount of data stored in the database, improving query
performance.  This operation is done infrequently to reduce datbase
load.

=head1 TABLES USED

=over

=item L<t_status_block_dest|Schema::OracleCoreStatus/t_status_block_dest>

Per-node file/byte counts of block destinations go into this table. 

=item L<t_status_file|Schema::OracleCoreStatus/t_status_file>

Per-node file/byte counts of file creation/generation go into this table.

=item L<t_status_replica|Schema::OracleCoreStatus/t_status_replica>

Per-node file/byte counts about replicas go into this table.

=item L<t_status_missing|Schema::OracleCoreStatus/t_status_missing>

Per-node file/byte counts about files remaining to be transferred go
into this table.

=item L<t_status_group|Schema::OracleCoreStatus/t_status_group>

Per-node, per-group file/byte counts of destined and resident files go
into this table.

=item L<t_history_link_stats|Schema::OracleCoreStatus/t_history_link_stats>

Per-link transfer queue type statistics are written into this table,
based on the current C<t_status_*> values.  Quantities are written in a
"heartbeat" fashion every 5 minutes.

=item L<t_history_link_dest|Schema::OracleCoreStatus/t_history_link_dest>

Per-node destined (subscribed), resident, and missing file/byte counts
are written into this table based on the current C<t_status_*> values.
Quantities are written in a "heartbeat" fashion every 5 minutes.

=item L<t_history_link_events|Schema::OracleCoreStatus/t_history_link_events>

PerfMonitor uses transfer event data to calculate transfer rates which
feed into the C<t_adm_link_param> table.  PerfMonitor does I<not>
write transfer event history into this table;
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent> does.

=item L<t_adm_link_param|Schema::OracleCoreTopo/t_adm_link_param>

PerfMonitor writes the recent per-link transfer rate and queue
information into this table, which is used by
L<FileRouter|PHEDEX::Core::Infrastructure::FileRouter> to make routing decisions.

=back

=head1 COOPERATING AGENTS

PerfMonitor deals with the statistics of the entire PhEDEx system, so
the list of cooperating agents would include nearly all of them.  Such
a list is therefore ommitted.

However, the relationship with 
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>
deserves special mention.  PerfMonitor is responsible for maintaining
the L<link parameters|Schema::OracleCoreTopo/t_adm_link_param> that
are used in file routing decisions.  It does this by observing the
per-link transfer performance of the recent past and writing this
summary to C<t_adm_link_param>, which is used by FileRouter.  Without
PerfMonitor, the FileRouter would not work properly.

=head1 STATISTICS

All tables PerfMonitor deals with are about statistics.  
See L<TABLES USED> above.  This agent does not keep statistics about
keeping statistics.

=head1 SEE ALSO

=over

=item L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>

=back

=cut
