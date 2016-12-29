package PHEDEX::Infrastructure::FilePump::Agent;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging','PHEDEX::BlockLatency::SQL';

use strict;
use warnings;

use List::Util qw(max);
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use PHEDEX::Error::Constants;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My node name
		  WAITTIME => 15 + rand(5),	# Agent activity cycle
		  NEXT_STATS => 0,		# Next time to run stats
		  ME	=> 'FilePump',
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Pick up work
# assignments from the database here and pass them to slaves.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    my @nodes;

    eval
    {
	$$self{NODES} = [ '%' ];
	$dbh = $self->connectAgent();
	@nodes = $self->expandNodes({ "FileDownload" => 5400, "FileExport" => 5400 });

        # Auto-export/-transfer files for nodes.
	$self->transfer($dbh);

	# Expire tasks
	$self->expire($dbh);
	
	# Handle completed transfer tasks, create replicas on success
	$self->receive($dbh);

	# Delete logical replicas which were physically deleted
	$self->delete($dbh);

	# Delete logical replicas which were logically invalidated
	$self->invalidate($dbh);

	# Update stats if necessary.
	$self->stats($dbh);
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

# Auto-export/-transfer files for nodes.
sub transfer
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    # Auto-export for sites running exports without stage-in.
    # Export staged files for sites with stage-in.
    # Auto-export migrations to MSS for sites with stage-in.
    &dbexec($dbh, qq{
	merge into t_xfer_task_export xte using
	  (select xt.id
	   from t_xfer_task xt
	     join t_adm_node ns
	       on ns.id = xt.from_node
	     join t_adm_node nd
	       on nd.id = xt.to_node
	     join t_xfer_source xs
	       on xs.from_node = xt.from_node
	       and xs.to_node = xt.to_node
	     join t_xfer_replica xr
	       on xr.id = xt.from_replica
	   where ((ns.kind = 'Buffer' and (xr.state = 1 or nd.kind='MSS'))
		  or ns.kind = 'Disk')
	     and xs.time_update >= :now - 5400) xt
	on (xte.task = xt.id)
	when not matched then
	  insert (task, time_update)
	  values (xt.id, :now)},
        ":now" => $now);

    # Auto transfer for MSS -> Buffer transitions.
    &dbexec($dbh, qq{
	insert all
	  into t_xfer_task_export (task, time_update) values (id, :now)
	  into t_xfer_task_inxfer (task, time_update, from_pfn, to_pfn, space_token)
                           values (id, :now, '(fake)', '(fake)', '(fake)')
	  into t_xfer_task_done   (task, report_code, xfer_code, time_xfer, time_update)
			   values (id, 0, 0, :now, :now)
	select xt.id from t_xfer_task xt
	  join t_adm_node ns on ns.id = xt.from_node and ns.kind = 'MSS'
	  join t_adm_node nd on nd.id = xt.to_node and nd.kind = 'Buffer'
	where not exists
	  (select 1 from t_xfer_task_done xtd where xtd.task = xt.id)},
        ":now" => $now);

    # Commit the lot above.
    $dbh->commit();
}

sub expire
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    # Mark as expired tasks which didn't complete in time.
    &dbexec($dbh, qq{
	merge into t_xfer_task_done xtd using
	  (select id from t_xfer_task where :now >= time_expire) xt
	on (xtd.task = xt.id) when not matched then
	  insert (task, report_code, xfer_code, time_xfer, time_update)
	  values (xt.id, @{[ PHEDEX_RC_EXPIRED ]}, @{[ PHEDEX_XC_NOXFER ]}, -1, :now)},
	":now" => $now);
}

# Harvest completed transfers.
sub receive
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    # First select rows we want to read in.  Use a temporary
    # index table to mark what we saw so that we will not see
    # phantom new rows while calculating statistics to update.
    &dbexec($dbh, qq{
	merge into t_xfer_task_harvest xth using
	  (select task from t_xfer_task_done) xtd
	on (xth.task = xtd.task)
	when not matched then insert (task) values (xtd.task)});

    # Now create history bins for time values we care about.  We
    # don't care that phantom reads may introduce more rows here
    # than we will eventually read back below, all we need is rows
    # we do read are covered.
    foreach my $t (qw(export:update inxfer:update done:xfer done:update))
    {
	my ($table, $column) = split(':', $t);
	my $bin = 300;
        &dbexec($dbh, qq{
	    merge into t_history_link_events h using
              (select distinct
	         trunc(xtx.time_$column/$bin)*$bin timebin,
	         xt.from_node, xt.to_node, xt.priority
	       from t_xfer_task_$table xtx
	         join t_xfer_task xt on xt.id = xtx.task) v
	    on (h.timebin = v.timebin and
	        h.from_node = v.from_node and
	        h.to_node = v.to_node and
	        h.priority = v.priority)
	    when not matched then
	      insert (timebin, timewidth, from_node, to_node, priority)
	      values (v.timebin, $bin, v.from_node, v.to_node, v.priority)});
    }

    # Now read in rows and create various update bundles.
    my %history = ();
    my ($n, $ngood, $nbad) = (0) x 3;
    my $q = &dbexec($dbh, qq{
	select
	    xth.task, xt.fileid, xtd.report_code, xtd.xfer_code,
	    xt.from_node, ns.name from_node_name, xti.from_pfn,
	    xt.to_node, nd.name to_node_name, xti.to_pfn,
	    xt.priority, f.filesize, f.logical_name,
	    xr.id dest_replica,
	    xt.time_assign time_assign,
	    xt.time_expire time_expire,
	    xte.time_update time_export,
	    xti.time_update time_inxfer,
	    xtd.time_xfer   time_xfer,
	    xtd.time_update time_done,
	    xti.space_token
	from t_xfer_task_harvest xth
	  join t_xfer_task xt on xt.id = xth.task
	  join t_xfer_file f on f.id = xt.fileid
	  join t_adm_node ns on ns.id = xt.from_node
	  join t_adm_node nd on nd.id = xt.to_node
	  join t_xfer_task_done xtd on xtd.task = xth.task
	  left join t_xfer_task_export xte on xte.task = xth.task
	  left join t_xfer_task_inxfer xti on xti.task = xth.task
	  left join t_xfer_replica xr
	    on xr.node = xt.to_node and xr.fileid = xt.fileid});
    while (my $task = $q->fetchrow_hashref())
    {
	$n++;

	$task->{FROM_PFN} ||= ''; # null when task is expired
	$task->{TO_PFN} ||= '';   # null when task is expired
	$task->{SPACE_TOKEN} ||= ''; # often null

	# First update the statistics.  Create a time bin for the
	# period when the transfer ended if one doesn't exist, then
	# update the statistics according to result.
	my %stats = (TIME_EXPORT => "avail", TIME_XFER => "try",
		     TIME_DONE => ($$task{REPORT_CODE} == 0 ? "done"
				  : $$task{REPORT_CODE} == PHEDEX_RC_EXPIRED ? "expire"
				  : "fail"));
	while (my ($t, $stat) = each %stats)
	{
	    next if ! defined $$task{$t} || $$task{$t} <= 0;
	    my $statbin = int($$task{$t}/300)*300;
            my $key = "$statbin $$task{FROM_NODE} $$task{TO_NODE} $$task{PRIORITY}";
	    $history{$key}{"${stat}_files"} ||= 0;
	    $history{$key}{"${stat}_bytes"} ||= 0;
	    $history{$key}{"${stat}_files"}++;
	    $history{$key}{"${stat}_bytes"} += $$task{FILESIZE};
	}

	# If the transfer was successful, create destination replica.
	# Otherwise if this was a transfer to the destination, put the
	# request into cool-off.
	my $msg = "xstats:";
	if ($$task{REPORT_CODE} == 0)
	{
	    $ngood++;
	    if ($$task{DEST_REPLICA})
	    {
	        # Destination replica exists, discard transfer.
		# Keep the stats since the agent thought it did.
		$msg = "warning: destination replica exists, discarding:";
	    }
	}
	elsif ($$task{REPORT_CODE} > 0)
	{
	    $nbad++;
	}

        # Log the outcome.
	$self->Logmsg($msg
		. " task=$$task{TASK}"
		. " file=$$task{FILEID}"
		. " from=$$task{FROM_NODE_NAME}"
		. " to=$$task{TO_NODE_NAME}"
		. " priority=$$task{PRIORITY}"
		. " report-code=$$task{REPORT_CODE}"
		. " xfer-code=$$task{XFER_CODE}"
		. " size=$$task{FILESIZE}"
		. ($$task{TIME_EXPIRE} ? " t-expire=$$task{TIME_EXPIRE}" : "")
		. ($$task{TIME_ASSIGN} ? " t-assign=$$task{TIME_ASSIGN}" : "")
		. ($$task{TIME_EXPORT} ? " t-export=$$task{TIME_EXPORT}" : "")
		. ($$task{TIME_INXFER} ? " t-inxfer=$$task{TIME_INXFER}" : "")
		. ($$task{TIME_XFER}   ? " t-xfer=$$task{TIME_XFER}" : "")
		. ($$task{TIME_DONE}   ? " t-done=$$task{TIME_DONE}" : "")
		. " t-harvest=$now"
		. " lfn=$$task{LOGICAL_NAME}"
		. " from_pfn=$$task{FROM_PFN}"
		. " to_pfn=$$task{TO_PFN}"
		. " space_token=$$task{SPACE_TOKEN}");
    }

    # Update link history.
    foreach my $key (keys %history)
    {
	my ($bin, $from, $to, $priority) = split(/\s+/, $key);
	my $join = "";
	my $sql = "update t_history_link_events set";
	foreach my $stat (qw(avail try done fail expire))
	{
	    next if ! exists $history{$key}{"${stat}_files"};
	    $sql .= $join;
	    $sql .= " ${stat}_files = nvl(${stat}_files,0) + :${stat}_files";
	    $sql .= ", ${stat}_bytes = nvl(${stat}_bytes,0) + :${stat}_bytes";
	    $join = ",";
	}
	$sql .= " where timebin = :timebin";
	$sql .= "   and from_node = :from_node";
	$sql .= "   and to_node = :to_node";
	$sql .= "   and priority = :priority";

	my ($stmt, $rows) = &dbexec($dbh, $sql,
				    ":timebin" => $bin,
				    ":from_node" => $from,
				    ":to_node" => $to,
				    ":priority" => $priority,
				    map { (":$_" => $history{$key}{$_}) }
				    sort keys %{$history{$key}});
	die "link history updated $rows, expected to update 1\n" if $rows != 1;
    }

    # Create destination replicas or put request into cool-off
    # depending on the transfer outcome.  For unsuccessful transfers
    # put the file on an exclusion list to prevent file issuer from
    # re-issuing the transfer until the file router has had a chance
    # to do the "slow flush" and put the request into cool-off.
    &dbexec($dbh, qq{
	merge into t_xfer_replica xr using
	  (select xt.to_node, xt.fileid, xtd.time_update, fn.kind
           from t_xfer_task_harvest xth
	     join t_xfer_task xt on xt.id = xth.task
	     join t_xfer_task_done xtd on xtd.task = xth.task
             join t_adm_node fn on fn.id = xt.from_node
	   where xtd.report_code = 0) new
	on (xr.node = new.to_node and xr.fileid = new.fileid)
	when not matched then
	  insert (id, node, fileid, state, time_create, time_state)
	  values (seq_xfer_replica.nextval, new.to_node, new.fileid,
		  case when new.kind = 'MSS' then 0 else 1 end,
		  new.time_update, new.time_update)});

    # Deactivate the request for transfers that just failed (to be
    # re-activated in 40 - 90 minutes.  This is the minimum retry time)
    &dbexec($dbh, qq{
	update t_xfer_request xq
	    set xq.state = 1, xq.time_expire = :now + dbms_random.value(2700,5400)
	    where (xq.destination, xq.fileid) in
	      (select distinct xp.destination, xp.fileid
	       from t_xfer_task_harvest xth
	         join t_xfer_task xt on xt.id = xth.task
	         join t_xfer_task_done xtd on xtd.task = xth.task
	         join t_xfer_path xp on xp.fileid = xt.fileid and xp.to_node = xt.to_node
	       where xtd.report_code != 0)},
	":now" => $now);

    # Exclude from the transfer queue transfers that just failed
    &dbexec($dbh, qq{
	insert into t_xfer_exclude (from_node, to_node, fileid, time_request)
        select xt.from_node, xt.to_node, xt.fileid, :now
	from t_xfer_task_harvest xth
	  join t_xfer_task xt on xt.id = xth.task
	  join t_xfer_task_done xtd on xtd.task = xth.task
        where xtd.report_code != 0},
	":now" => $now);

    # Record file-level latency information
    my @fileLatencyStats=$self->mergeXferFileLatency();
    $self->Dbgmsg("Merged file-level latency information: "
		  .join(', ', map { $_->[1] + 0 .' '.$_->[0] } @fileLatencyStats));

    # Finally remove all we've processed.
    &dbexec($dbh, qq{
	delete from t_xfer_task xt where id in
	       (select task from t_xfer_task_harvest)});

    # Give file router a signal to proceed with request clean-up
    # if we completed transfers.  This will allow an idle router
    # to bring forward the 'close out' transfers quicker.
    &dbexec($dbh, qq{select seq_xfer_done.nextval from dual})->fetchrow()
	if $ngood;

    # Presto, we are done.
    $dbh->commit();

    # Tell summary of what happened.
    $self->Logmsg("$n transfer tasks received, $ngood successful,"
	    . " $nbad failed, @{[$n - $ngood - $nbad]} other")
	if $n;
}

# Remove replicas for completed deletions
sub delete
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    my ($sth, $n, $nbuf);

    # Remove logical replica for completed deletions
    ($sth, $n) = &dbexec($dbh, qq{
	delete from t_xfer_replica
	 where (node, fileid) in
         (select xr.node, xr.fileid
            from t_xfer_delete xd
            join t_xfer_replica xr
	         on xr.node = xd.node and xr.fileid = xd.fileid
           where xd.time_complete is not null
             and xd.time_complete >= xr.time_create)
     });

    # Remove logical replica at Buffer nodes attached to MSS nodes
    # with completed deletions
    ($sth, $nbuf) = &dbexec($dbh, qq{
	delete from t_xfer_replica
	 where (node, fileid) in
         (select xr.node, xr.fileid
            from t_xfer_delete xd
            join t_adm_link l on l.from_node = xd.node
            join t_adm_node fn on fn.id = l.from_node
            join t_adm_node tn on tn.id = l.to_node
            join t_xfer_replica xr
	         on xr.node = tn.id and xr.fileid = xd.fileid
           where l.is_local = 'y'
             and fn.kind = 'MSS'
             and tn.kind = 'Buffer'
             and xd.time_complete is not null
             and xd.time_complete >= xr.time_create)
     });

    $dbh->commit();

    $self->Logmsg("$n replicas removed due to deletions (+$nbuf from buffers)") if ($n + $nbuf);
}

# Remove replicas for pending invalidations
sub invalidate
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    my ($sth, $n, $nbuf, $ntasks);

    # Remove logical replica for pending invalidations
    ($sth, $n) = &dbexec($dbh, qq{
        delete from t_xfer_replica
         where (node, fileid) in
         (select xi.node, xi.fileid
            from t_xfer_invalidate xi
            join t_xfer_replica xr
                 on xr.node = xi.node and xr.fileid = xi.fileid
           where xi.time_complete is null)
     });

    # Remove logical replica at Buffer nodes attached to MSS nodes
    # with pending invalidations
    ($sth, $nbuf) = &dbexec($dbh, qq{
        delete from t_xfer_replica
         where (node, fileid) in
         (select xr.node, xr.fileid
            from t_xfer_invalidate xi
            join t_adm_link l on l.from_node = xi.node
            join t_adm_node fn on fn.id = l.from_node
            join t_adm_node tn on tn.id = l.to_node
            join t_xfer_replica xr
                 on xr.node = tn.id and xr.fileid = xi.fileid
           where l.is_local = 'y'
             and fn.kind = 'MSS'
             and tn.kind = 'Buffer'
             and xi.time_complete is null)
       });

    # Mark as completed all invalidation tasks for which the target replica
    # doesn't exist anymore (on target node and locally linked Buffers).
    # This can be either because it was logically removed
    # here or because it was removed in delete () after a physically deletion
    
    ($sth, $ntasks) = &dbexec($dbh, qq{
        update t_xfer_invalidate
         set time_complete = :now
         where (node, fileid) in
          (select xi.node, xi.fileid
            from t_xfer_invalidate xi
            left join t_xfer_replica xr
              on xr.fileid=xi.fileid and xr.node=xi.node
            left join t_adm_link ln on ln.from_node=xi.node and ln.is_local='y'                                                                                                             
            left join t_adm_node ndbuf on ndbuf.id=ln.to_node and ndbuf.kind='Buffer'                                                                                                       
            left join t_xfer_replica xrb on xrb.fileid = xi.fileid and xrb.node = ndbuf.id
            where xi.time_complete is null
              and xr.fileid is null
              and xrb.fileid is null)
     }, ':now'=>$now);

    $dbh->commit();

    $self->Logmsg("$n replicas removed due to invalidations (+$nbuf from buffers)") if ($n + $nbuf);
    $self->Logmsg("$ntasks invalidation tasks completed") if $ntasks;

}

# Update transfer task statistics.
sub stats
{
    my ($self, $dbh) = @_;
    
    # If we updated stats recently, skip it.
    my $now = &mytimeofday();
    return if $now < $$self{NEXT_STATS};
    $$self{NEXT_STATS} = int($now/300) + 300;

    # Remove previous stats.
    &dbexec($dbh, qq{delete from t_status_task});

    # Insert new ones.
    &dbexec($dbh, qq{
	insert into t_status_task
	(time_update, from_node, to_node, priority, state, files, bytes, is_custodial)
	select :now, xt.from_node, xt.to_node, xt.priority,
	       (case
		  when xtd.task is not null then 3
		  when xti.task is not null then 2
		  when xte.task is not null then 1
		  else 0
		end) state,
	       count(xt.fileid), sum(f.filesize), xt.is_custodial
	from t_xfer_task xt
	  join t_xfer_file f on f.id = xt.fileid
	  left join t_xfer_task_export xte on xte.task = xt.id
	  left join t_xfer_task_inxfer xti on xti.task = xt.id
	  left join t_xfer_task_done   xtd on xtd.task = xt.id
        group by :now, xt.from_node, xt.to_node, xt.priority, xt.is_custodial,
	       (case
		  when xtd.task is not null then 3
		  when xti.task is not null then 2
		  when xte.task is not null then 1
		  else 0
		end)},
	":now" => $now);

    $dbh->commit();
}

1;

=pod

=head1 NAME

FilePump - harvest and process finished transfer tasks

=head1 DESCRIPTION

FilePump harvests completed transfer tasks, processes their result,
and keeps statistics.  Successful tasks result in a new replica;
unsuccessful tasks have their transfer request put into a "retry"
state which prevents new tasks from being created until a short
cool-off period has passed.  Besides completed tasks, un-attempted
tasks that have reached their expire time are collected by this agent
and removed.  For each harvested task, "event" statistics are
collected so that the precice number of transfer successes, failures,
and expirations are known.

This agent also executes some "fake" transfers that are needed to move
files along the transfer path where real transfer agents are not
expected to be running.  MSS->Buffer transfers fall into this
category, as well as "staging" for Disk-only nodes which do not need
staging.

Finally, FilePump manages file replicas for completed deletion tasks,
removing file replicas when a deletion task has completed.

=head1 TABLES USED

=over

=item L<t_xfer_task|Schema::OracleCoreTransfer/t_xfer_task>

The transfer task table.  This agent is responsible for processing
finished tasks.

=item L<t_xfer_task_done|Schema::OracleCoreTransfer/t_xfer_task_done>

Marks tasks in the "done" state, which this agent should act on.

=item L<t_xfer_task_harvest|Schema::OracleCoreTransfer/t_xfer_task_harvest>

A scratch table for marking tasks which are being harvested now.

=item L<t_xfer_task_exclude|Schema::OracleCoreTransfer/t_xfer_task_exclude>

Marks tasks in the "exclude" state, which are not to be re-issued by
L<FileIssue|PHEDEX::Infrastructure::FileIssue::Agent>.
until allowed to by
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>.

=item L<t_xfer_delete|Schema::OracleCoreTransfer/t_xfer_delete>

Represents a deletion task, this agent watches for completed deletions.

=item L<t_xfer_replica|Schema::OracleCoreTransfer/t_xfer_replica>

This agent creates replicas when transfer tasks are successful, and
removes then when deletion tasks are finished.

=item L<t_xfer_request|Schema::OracleCoreTransfer/t_xfer_request>

This agent puts requests into a "retry later" state when a task has
failed.

=back

=head1 COOPERATING AGENTS

=over

=item L<FileIssue|PHEDEX::Infrastructure::FileIssue::Agent>

FileIssue creates tasks.  Without tasks, there are no tasks to
complete.

=item L<FileDownload|PHEDEX::File::Download::Agent>

FileDownload completes tasks for FilePump to process.

=item L<FileMSSMigrate|PHEDEX::File::MSSMigrate::Agent>

Like FileDownload, but for Buffer->MSS transitions.

=item L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>

Failed tasks send the transfer request back to FileRouter for path
reconsideration.

=item L<BlockDelete|PHEDEX::BlockDelete::Agent>

Block delete creates file deletion tasks, for which FilePump will
remove the file replica.

=item L<FileRemove|PHEDEX::File::Remove::Agent>

FileRemove completes deletion tasks for FilePump to act on.

=back

=head1 STATISTICS

=over

=item L<t_status_task|Schema::OracleCoreStatus/t_status_task>

Contains current per-link file and byte sums for tasks, grouped by the state
of the task.  Manage by this agent.

=item L<t_history_link_events|Schema::OracleCoreStatus/t_history_link_events>

Contains a history of the times that tasks entered various states.
Manged by this agent.


=back

=head1 SEE ALSO

=over

=item L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>

=back

=cut
