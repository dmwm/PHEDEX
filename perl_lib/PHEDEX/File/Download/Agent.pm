package PHEDEX::File::Download::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use List::Util qw(min max sum);
use File::Path qw(mkpath rmtree);
use Data::Dumper;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use POSIX;
use POE;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  NODES => undef,		# Nodes to operate for
	  	  IGNORE_NODES => [],		# TMDB nodes to ignore
	  	  ACCEPT_NODES => [],		# TMDB nodes to accept

		  VALIDATE_COMMAND => undef,	# pre/post download validation command
		  DELETE_COMMAND => undef,	# pre/post download deletion command
		  PREVALIDATE => 1,             # flag to prevalidate files with VALIDATE_COMMAND
		  PREDELETE => 1,               # flag to predelete files with DELETE_COMMAND
		  PREPARE_JOBS => 200,          # max number of jobs to start for preparation tasks

		  TIMEOUT => 600,		# Maximum execution time
		  NJOBS => 10,			# Max number of utility processes
		  WAITTIME => 15,		# Nap length between cycles

		  BACKEND_TYPE => undef,	# Backend type
		  BACKEND_ARGS => undef,	# Options to the backend

		  NODE => {},			# Node bandwidth parameters
		  LINKS => {},			# Per-link transfer parameters
		  FILES => {},			# Files to transfer

		  FIRST_ACTION => undef,	# Time of first action
		  ACTIONS => [],		# Future actions

		  PREPAREDIR => "$$self{DROPDIR}/prepare", # Tasks being prepared
		  TASKDIR => "$$self{DROPDIR}/tasks",      # Tasks to do
		  ARCHIVEDIR => "$$self{DROPDIR}/archive", # Jobs done
		  STATS => [],			# Historical stats.

		  LAST_SYNC => 0,		# Last time to synchronise
		  LAST_CONNECT => 0,		# Last time connected and made known
		  LAST_WORK => time(),		# Last time we saw work
		  LAST_COMPLETED => 0,		# Last completed a task
		  NEXT_CLEAR => time(),		# Next time to clear job archive
		  NEXT_SYNC => 0,		# Next time to synchronise
		  NEXT_PURGE => 0,		# Next time to purge bad data
		  DBH_LAST_USE => 0,		# Last use of the database

		  BATCH_ID => 0,		# Number of batches created
		  BOOTTIME => time(),		# Time this agent started
		);
    my %args = (@_);
    $$self{$_} = $args{$_} || $params{$_} for keys %params;
    eval ("use PHEDEX::Transfer::$args{BACKEND_TYPE}");
    do { chomp ($@); die "Failed to load backend: $@\n" } if $@;
    $self->{BACKEND} = eval("new PHEDEX::Transfer::$args{BACKEND_TYPE}(\$self)");
    do { chomp ($@); die "Failed to create backend: $@\n" } if $@;
    -d $$self{PREPAREDIR} || mkdir($$self{PREPAREDIR}) || -d $$self{PREPAREDIR}
        || die "$$self{PREPAREDIR}: cannot create: $!\n";
    -d $$self{TASKDIR} || mkdir($$self{TASKDIR}) || -d $$self{TASKDIR}
        || die "$$self{TASKDIR}: cannot create: $!\n";
    -d $$self{ARCHIVEDIR} || mkdir($$self{ARCHIVEDIR}) || -d $$self{ARCHIVEDIR}
        || die "$$self{ARCHIVEDIR}: cannot create: $!\n";

    bless $self, $class;
    return $self;
}

# If stopped, tell backend to stop, then wait for all the pending
# utility jobs to complete.  All backends just abandon the jobs, and
# we try to pick up on the transfer again if the agent is restarted.
# Utility jobs usually run quickly so we let them run to completion.
sub stop
{
    my ($self) = @_;

    # Wait for utility processes to finish.
    if (@{$$self{JOBS}})
    {
        $self->Logmsg ("waiting pending jobs to finish...");
        while (@{$$self{JOBS}})
        {
            $self->pumpJobs();
	    select(undef, undef, undef, .1);
        }
        $self->Logmsg ("all pending jobs finished, ready to exit");
    }
    else
    {
        $self->Logmsg ("no pending jobs, ready to exit");
    }

    # Clear to exit.
}

sub evalinfo
{
    my ($file) = @_;
    no strict 'vars';
    return eval (&input($file) || '');
}

# Reconnect the agent to the database.  If the database connection
# has been shut, create a new connection.  Update agent status.  Set
# $$self{DBH} to database handle and $$self{NODES_ID} to hash of the
# (node name, id) pairs.
sub reconnect
{
    my ($self) = @_;
    my $now = &mytimeofday();
    
    # Now connect.
    my $dbh = $self->connectAgent();
    my @nodes = $self->expandNodes();
    unless (@nodes) { die("Cannot find nodes in database for '@{$$self{NODES}}'") };
    
    # Indicate to file router which links are "live."
    my ($dest, %dest_args) = $self->myNodeFilter ("l.to_node");
    my ($src, %src_args) = $self->otherNodeFilter ("l.from_node");
    my @protos = $$self{BACKEND}->protocols();

    &dbexec($dbh, qq{
	delete from t_xfer_sink l where $dest $src},
	%dest_args, %src_args);
    &dbexec($dbh, qq{
	insert into t_xfer_sink (from_node, to_node, protocols, time_update)
	select l.from_node, l.to_node, :protos, :now from t_adm_link l
	where $dest $src},
	":protos" => "@protos", ":now" => $now, %dest_args, %src_args);

    $$self{DBH_LAST_USE} = $now;
    $$self{LAST_CONNECT} = $now;
}

######################################################################
# Mark a task completed.  Brings the next synchronisation into next
# fifteen minutes, and updates statistics for the current period.
sub taskDone
{
    my ($self, $task) = @_;

    # Save it.
    return 0 if ! $self->saveTask($task);

    # If next synchronisation is too far away, pull it forward.
    my $now = &mytimeofday();
    my $sync = $now + 900;
    $$self{NEXT_SYNC} = $sync if $sync < $$self{NEXT_SYNC};
    $$self{LAST_COMPLETED} = $now;

    # Update statistics for the current period.
    my ($from, $to, $code) = @$task{"FROM_NODE", "TO_NODE", "REPORT_CODE"};
    my $s = $$self{STATS_CURRENT}{LINKS}{$to}{$from}
        ||= { DONE => 0, USED => 0, ERRORS => 0 };
    $$s{ERRORS}++ if $code > 0;
    $$s{DONE}++ if $code == 0;

    # Report but simplify download detail/validate logs.
    my $detail = $$task{LOG_DETAIL} || '';
    my $validate = $$task{LOG_VALIDATE} || '';
    foreach my $log (\$detail, \$validate)
    {
	$$log =~ s/^[-\d: ]*//gm;
	$$log =~ s/^[A-Za-z]+(\[\d+\]|\(\d+\)): //gm;
	$$log =~ s/\n+/ ~~ /gs;
	$$log =~ s/\s+/ /gs;
    }

    $self->Logmsg("xstats:"
	    . " task=$$task{TASKID}"
	    . " file=$$task{FILEID}"
	    . " from=$$task{FROM_NODE}"
	    . " to=$$task{TO_NODE}"
	    . " priority=$$task{PRIORITY}"
	    . " report-code=$$task{REPORT_CODE}"
	    . " xfer-code=$$task{XFER_CODE}"
	    . " size=$$task{FILESIZE}"
	    . " t-expire=$$task{TIME_EXPIRE}"
	    . " t-assign=$$task{TIME_ASSIGN}"
	    . " t-export=$$task{TIME_EXPORT}"
	    . " t-inxfer=$$task{TIME_INXFER}"
	    . " t-xfer=$$task{TIME_XFER}"
	    . " t-done=$$task{TIME_UPDATE}"
	    . " lfn=$$task{LOGICAL_NAME}"
	    . " from-pfn=$$task{FROM_PFN}"
	    . " to-pfn=$$task{TO_PFN}"
	    . " detail=($detail)"
	    . " validate=($validate)"
	    . " job-log=@{[$$task{JOBLOG} || '(no job)']}") 
	unless ($$task{REPORT_CODE} == -1); # unless expired

    # Indicate success.
    return 1;
}

# Save a task after change of status.
sub saveTask
{
    my ($self, $task) = @_;
    return &output("$$self{TASKDIR}/$$task{TASKID}", Dumper($task));
}

######################################################################
# Start a new statistics period.  If we have more than the desired
# amount of statistics periods, remove old ones.
sub statsNewPeriod
{
    my ($self, $jobs, $tasks) = @_;
    my $now = &mytimeofday();

    # Prune recent history.
    $$self{STATS} = [ grep($now - $$_{TIME} <= 3600, @{$$self{STATS}}) ];

    # Add new period.
    my $current = $$self{STATS_CURRENT} = { TIME => $now, LINKS => {} };
    push(@{$$self{STATS}}, $current);

    # Add statistics on transfer slots used.
    foreach my $t (values %$tasks)
    {
	# Skip if the transfer task was completed or hasn't started.
	next if defined $$t{REPORT_CODE};
	next if ! grep(exists $$_{TASKS}{$$t{TASKID}}, values %$jobs);

	# It's using up a transfer slot, add to time slot link stats.
	my ($from, $to) = @$t{"FROM_NODE", "TO_NODE"};
	$$current{LINKS}{$to}{$from} ||= { DONE => 0, USED => 0, ERRORS => 0 };
	$$current{LINKS}{$to}{$from}{USED}++;
    }
}

######################################################################
# Compare local transfer pool with database and reset everything one
# or the other doesn't know about.  We assume this is the only agent
# managing transfers for the links it's given.  If database has a
# locally unknown transfer, we mark the database one lost.  If we
# have a local transfer unknown to the database, we trash the local.
sub purgeLostTransfers
{
    my ($self, $jobs, $tasks) = @_;
    my (%inlocal, %indb) = ();

    # Get the local transfer pool.  All we need is the task ids.
    $inlocal{$_} = 1 for keys %$tasks;

    # Get the database transfer pool.  Again, just task ids.
    my ($dest, %dest_args) = $self->myNodeFilter ("xt.to_node");
    my ($src, %src_args) = $self->otherNodeFilter ("xt.from_node");
    my $qpending = &dbexec($$self{DBH}, qq{
      select xti.task
      from t_xfer_task_inxfer xti
        join t_xfer_task xt on xt.id = xti.task
        left join t_xfer_task_done xtd on xtd.task = xti.task
      where xtd.task is null and $dest $src},
      %dest_args, %src_args);
    while (my ($taskid) =  $qpending->fetchrow())
    {
	$indb{$taskid} = 1;
    }

    # Calculate differences.
    my @lostdb = grep(! $indb{$_}, keys %inlocal);
    my @lostlocal = grep(! $inlocal{$_}, keys %indb);


    if ( @lostlocal )
    {
      $self->Alert("resetting database tasks lost locally: @{[sort @lostlocal]}"
	   . " (locally known: @{[sort keys %inlocal]})");
      # Mark locally unknown tasks as lost in database.
      my @now = (&mytimeofday()) x scalar @lostlocal;
      my $qlost = &dbprep($$self{DBH}, qq{
        insert into t_xfer_task_done
          (task, report_code, xfer_code, time_xfer, time_update)
	  values (?, -2, -2, -1, ?)});
      &dbbindexec($qlost, 1 => \@lostlocal, 2 => \@now);
      $$self{DBH}->commit();
    }

    # Remove locally known tasks forgotten by database.
    $self->Alert("resetting local tasks lost in database: @{[sort @lostdb]}"
	   . " (database known: @{[sort keys %indb]})")
	if @lostdb;
    foreach (@lostdb)
    {
	delete $$tasks{$_};
	unlink("$$self{TASKDIR}/$_");
    }
}

# Fetch new tasks from the database.
sub fetchNewTasks
{
    my ($self, $jobs, $tasks) = @_;
    my ($dest, %dest_args) = $self->myNodeFilter ("xt.to_node");
    my ($src, %src_args) = $self->otherNodeFilter ("xt.from_node");
    my $now = &mytimeofday();
    my (%pending, %busy);

    # Propagate extended expire time to local task copies.
    my $qupdate = &dbexec($$self{DBH}, qq{
	select xt.id taskid, xt.time_expire
	from t_xfer_task xt
	  join t_xfer_task_inxfer xti on xti.task = xt.id
	  left join t_xfer_task_done xtd on xtd.task = xt.id
	where xtd.task is null and $dest $src},
        %dest_args, %src_args);
    while (my $row = $qupdate->fetchrow_hashref())
    {
	next if ! exists $$tasks{$$row{TASKID}};
	my $existing = $$tasks{$$row{TASKID}};
	next if $$existing{TIME_EXPIRE} >= $$row{TIME_EXPIRE};
	$self->Logmsg("task=$$existing{TASKID} expire time extended from "
		. join(" to ",
		       map { strftime('%Y-%m-%d %H:%M:%S', gmtime($_)) }
		       $$existing{TIME_EXPIRE}, $$row{TIME_EXPIRE}))
	    if $$self{VERBOSE};
	$$existing{TIME_EXPIRE} = $$row{TIME_EXPIRE};
	&output("$$self{TASKDIR}/$$existing{TASKID}", Dumper($existing));
    }

    # If we have just too much work, leave.
    return if scalar keys %$tasks >= 5_000;

    # Find out how many we have pending per link so we can throttle.
    ($pending{"$$_{FROM_NODE} -> $$_{TO_NODE}"} ||= 0)++
	for grep(! exists $$_{REPORT_CODE}, values %$tasks);

    # Fetch new tasks.
    my $i = &dbprep($$self{DBH}, qq{
	insert into t_xfer_task_inxfer (task, time_update, from_pfn, to_pfn, space_token)
	values (:task, :now, :from_pfn, :to_pfn, :space_token)});

     my $q = &dbexec($$self{DBH}, qq{
	select
	    xt.id taskid, xt.fileid, xt.rank, xt.priority, xt.is_custodial,
	    f.logical_name, f.filesize, f.checksum,
	    xt.from_node from_node_id, ns.name from_node,
	    xt.to_node to_node_id, nd.name to_node,
	    xti.from_pfn, xti.to_pfn,
	    xt.time_assign, xt.time_expire,
	    xte.time_update time_export
	from t_xfer_task xt
	   join t_xfer_task_export xte on xte.task = xt.id
	   left join t_xfer_task_inxfer xti on xti.task = xt.id
	   left join t_xfer_task_done xtd on xtd.task = xt.id
	   join t_adm_node ns on ns.id = xt.from_node
	   join t_adm_node nd on nd.id = xt.to_node
	   join t_xfer_file f on f.id = xt.fileid
	where xti.task is null
	   and xtd.task is null
	   and xt.time_expire > :limit
	   and $dest $src
	order by time_assign asc, rank asc},
        ":limit" => $now + 3600, %dest_args, %src_args);
    while (my $row = $q->fetchrow_hashref())
    {
	# If we have just too much work, leave.
	last if scalar keys %$tasks >= 15_000;

	# If we have too many on this link, skip.
	my $linkkey = "$$row{FROM_NODE} -> $$row{TO_NODE}";
	if (($pending{$linkkey} || 0) >= 1000)
	{
            $self->Logmsg("link $linkkey already has $pending{$linkkey} pending"
		    . " tasks, not fetching more from the database")
		if ! $busy{$linkkey} && $$self{VERBOSE};
	    $busy{$linkkey} = 1;
	    next;
	}

	# Mark used in database.

        $row->{FROM_PROTOS} = [@{$self->{BACKEND}{PROTOCOLS}}];
        $row->{TO_PROTOS}   = [@{$self->{BACKEND}{PROTOCOLS}}];
	my $h = makeTransferTask(
				  $self,
				  $row,
				  $self->{BACKEND}->{CATALOGUES}
				);
#	A sanity check, should not be needed but who knows...
	foreach ( qw / FROM_PFN TO_PFN FROM_NODE TO_NODE / )
	{
	  if ( !defined($h->{$_}) )
	  {
	    $self->Alert('No $_ in task: ',join(', ',map { "$_=$row->{$_}" } sort keys %{$row}));
	  }
	}
        map { $row->{$_} = $h->{$_} } keys %{$h};
	$row->{SPACE_TOKEN} = $h->{TO_TOKEN};
	&dbbindexec($i, ":task" => $$row{TASKID}, ":now" => $now,
			":from_pfn" => $$row{FROM_PFN},
			":to_pfn" => $$row{TO_PFN},
		        ":space_token" => $$row{SPACE_TOKEN}
		    );
	$$row{TIME_INXFER} = $now;
        ($pending{$linkkey} ||= 0)++;
	
	# Generate a local task descriptor.  It doesn't really matter
	# if things go badly wrong here, we'll clean it up in purge.
	return if ! &output("$$self{TASKDIR}/$$row{TASKID}", Dumper($row));
	$$tasks{$$row{TASKID}} = $row;
    }
    $q->finish(); # In case we left before going through all the results
}

# Upload final task status to the database.
sub updateTaskStatus
{
    my ($self, $tasks) = @_;
    my $rows = 0;
    my (%dargs, %eargs);
    my $dstmt = &dbprep($$self{DBH}, qq{
	insert into t_xfer_task_done
	(task, report_code, xfer_code, time_xfer, time_update)
	values (?, ?, ?, ?, ?)});
    my $estmt = &dbprep($$self{DBH}, qq{
	insert into t_xfer_error
	(to_node, from_node, fileid, priority, is_custodial,
	 time_assign, time_expire, time_export, time_inxfer, time_xfer,
         time_done, report_code, xfer_code, from_pfn, to_pfn, space_token,
	 log_xfer, log_detail, log_validate)
	values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)});
    foreach my $task (keys %$tasks)
    {
	next if ! exists $$tasks{$task}{REPORT_CODE};

        $self->Logmsg("uploading status of task=$task") if $$self{VERBOSE};

	my $arg = 1;
	push(@{$dargs{$arg++}}, $$tasks{$task}{TASKID});
	push(@{$dargs{$arg++}}, $$tasks{$task}{REPORT_CODE});
	push(@{$dargs{$arg++}}, $$tasks{$task}{XFER_CODE});
	push(@{$dargs{$arg++}}, $$tasks{$task}{TIME_XFER});
	push(@{$dargs{$arg++}}, $$tasks{$task}{TIME_UPDATE});

	if ($$tasks{$task}{REPORT_CODE} != 0)
	{
	    my $arg = 1;
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TO_NODE_ID});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{FROM_NODE_ID});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{FILEID});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{PRIORITY});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{IS_CUSTODIAL});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_ASSIGN});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_EXPIRE});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_EXPORT});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_INXFER});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_XFER});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TIME_UPDATE});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{REPORT_CODE});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{XFER_CODE});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{FROM_PFN});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{TO_PFN});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{SPACE_TOKEN});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{LOG_XFER});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{LOG_DETAIL});
	    push(@{$eargs{$arg++}}, $$tasks{$task}{LOG_VALIDATE});
	}

        unlink("$$self{TASKDIR}/$task");
        delete $$tasks{$task};
	if ((++$rows % 100) == 0)
	{
	    &dbbindexec($dstmt, %dargs);
	    &dbbindexec($estmt, %eargs) if %eargs;
	    $$self{DBH}->commit();
	    %dargs = ();
	    %eargs = ();
	}
    }

    if (%dargs)
    {
	&dbbindexec($dstmt, %dargs);
	&dbbindexec($estmt, %eargs) if %eargs;
        $$self{DBH}->commit();
    }
}

# Push status of completed to the database and pull more tasks.
sub doSync
{
    my ($self, $jobs, $tasks) = @_;

    # Upload status for completed tasks.
    $self->updateTaskStatus($tasks);

    # Fetch new tasks where necessary.
    $self->fetchNewTasks($jobs, $tasks)
	if ! -f "$$self{DROPDIR}/drain";
    $$self{DBH}->commit();
}

# Prepare tasks for transfer
sub prepare
{
    my ($self, $tasks) = @_;

    my $now = &mytimeofday();
    my $n_add = 0;

    # Perhaps stop.
    $self->maybeStop();

    # Iterate through all the tasks and add jobs for pre-validation
    # and pre-deletion if necessary
    foreach my $task (keys %$tasks)
    {
	my $taskinfo = $$tasks{$task};

	next if $$taskinfo{PREPARED};
	last if $n_add >= $$self{PREPARE_JOBS};

	my $do_preval = ($$self{VALIDATE_COMMAND} && $$self{PREVALIDATE}) ? 1 : 0;
	my $do_predel = ($$self{DELETE_COMMAND} && $$self{PREDELETE}) ? 1 : 0;

	# Note on order: pre-validation is done before pre-deletion,
	# but we queue the pre-deletion tasks first in order to get
	# more tasks in the PREPARED state

	# Pre-deletion (only if pre-validation is completed and unsuccessful)
	if ($do_predel && !$$taskinfo{PREDELETE_DONE}
	    && (!$do_preval || ($do_preval 
				&& $$taskinfo{PREVALIDATE_DONE} 
				&& $$taskinfo{PREVALIDATE_STATUS} != 0
				&& $$taskinfo{PREVALIDATE_STATUS} != 86))
	    ) {
	    $$taskinfo{PREDELETE_DONE} = 0;
	    $n_add++;
	    $self->addJob (
               sub { $$taskinfo{PREDELETE_DONE} = 1;
                     $$taskinfo{PREDELETE_STATUS} = $_[0]{STATUS};
		     return if ! $self->saveTask($taskinfo);
		 },
		{ TIMEOUT => $self->{TIMEOUT}, LOGPREFIX => 1 },
		@{$self->{DELETE_COMMAND}}, "pre",
	        @$taskinfo{ qw(TO_PFN) });
	}

	# Pre-validation
	my $fvstatus = "$$self{PREPAREDIR}/T${task}V";
	my $fvlog    = "$$self{PREPAREDIR}/T${task}L";
	my $vstatus;
	my $done = 0;

	if (-s $fvstatus && (! ($vstatus = &evalinfo($fvstatus)) || $@))
	{
	    $vstatus = { START => $now, END => $now, STATUS => -3,
		         LOG => "agent lost the file pre-validation result" };
	    return if ! &output($fvstatus, Dumper($vstatus));
	}

	if ($do_preval && !$vstatus) 
	{
	    return if ! &output($fvstatus, "");
	    $$taskinfo{PREVALIDATE_DONE} = 0;
	    $n_add++;
	    $self->addJob(sub {
		&output($fvstatus, Dumper ({
		    START => $now, END => &mytimeofday(),
		    STATUS => $_[0]{STATUS}, LOG => &input($fvlog) }));
	    },
	    { TIMEOUT => $$self{TIMEOUT}, LOGFILE => $fvlog },
	    @{$$self{VALIDATE_COMMAND}}, "pre",
	    @$taskinfo{qw(TO_PFN FILESIZE CHECKSUM)});
	} elsif ( $vstatus ) {
	    # if the pre-validation returned success, this file is already there.  mark success
	    if ($$vstatus{STATUS} == 0) 
	    {
		$$taskinfo{REPORT_CODE} = 0;
		$$taskinfo{XFER_CODE} = -2;
		$$taskinfo{LOG_DETAIL} = 'file validated before transfer attempt';
		$$taskinfo{LOG_XFER} = 'no transfer was attempted';
		$$taskinfo{LOG_VALIDATE} = $$vstatus{LOG};
		$$taskinfo{TIME_UPDATE} = $$vstatus{END};
		$$taskinfo{TIME_XFER} = -1;
		$done = 1;
	    } 
	    # if the pre-validation returned 86, the transfer is vetoed, throw this task away
	    # see http://www.urbandictionary.com/define.php?term=eighty-six
	    # or google "eighty-sixed"
	    elsif ($$vstatus{STATUS} == 86) 
	    {
		$$taskinfo{REPORT_CODE} = -2;
		$$taskinfo{XFER_CODE} = -2;
		$$taskinfo{LOG_DETAIL} = 'file pre-validation vetoed the transfer';
		$$taskinfo{LOG_XFER} = 'no transfer was attempted';
		$$taskinfo{LOG_VALIDATE} = $$vstatus{LOG};
		$$taskinfo{TIME_UPDATE} = $$vstatus{END};
		$$taskinfo{TIME_XFER} = -1;
		$done = 1;
	    }
	    # FIXME:  archive prevalidation state/log?
	    unlink $fvstatus;
	    unlink $fvlog;
	    $$taskinfo{PREVALIDATE_DONE} = 1;
	    $$taskinfo{PREVALIDATE_STATUS} = $$vstatus{STATUS};
	}

	# Are we prepared?
	if ( (!$do_preval || $$taskinfo{PREVALIDATE_DONE}) &&
	     (!$do_predel || $$taskinfo{PREDELETE_DONE}) ) {
	    $$taskinfo{PREPARED} = 1;
	} else {
	    $$taskinfo{PREPARED} = 0;
	}

	if ($done) {
	    $$taskinfo{PREPARED} = 1;
	    return if ! $self->taskDone($taskinfo);
	    delete $$tasks{$task};
	} else {
	    return if ! $self->saveTask($taskinfo);
	}
    }

    # Figure out how much work we have left to do
    my $n_tasks = scalar keys %$tasks;
    my $n_prepared = scalar grep(exists $$_{PREPARED} && $$_{PREPARED} == 1, values %$tasks);
    
    $self->Logmsg("started $n_add prepare jobs:  $n_prepared of $n_tasks tasks prepared for transfer") 
	if $$self{VERBOSE} && $n_tasks;

    # return true if all tasks are prepared
    return ($n_prepared == $n_tasks) ? 0 : 1;
}

# Check how a copy job is doing.
sub check
{
    my ($self, $jobname, $jobs, $tasks) = @_;

    # Perhaps stop.
    $self->maybeStop();

    # First ask backend to have a look.
    $$self{BACKEND}->check($jobname, $jobs, $tasks);

    # Prepare some useful shortcuts.  "$live" indicates whether the
    # job is still live.  If not, below we will force tasks complete.
    my $now = &mytimeofday();
    my $jobpath = "$$self{WORKDIR}/$jobname";
    my $jobinfo = $$jobs{$jobname};

    my $live = ($now - ((stat("$jobpath/live"))[9] || 0) > 600 ? 0 : 1);
    my $done = 1;

    # Check all the tasks in the job.
    foreach my $task (keys %{$$jobinfo{TASKS}})
    {
	# Prepare useful shortcuts.
	my $fxstatus = "$jobpath/T${task}X";
	my $fvstatus = "$jobpath/T${task}V";
	my $fvlog    = "$jobpath/T${task}L";
	my $taskinfo = $$tasks{$task};

	# If we lost this task, ignore the entry.
	next if ! $taskinfo;

	# Find task details.  Ignore lost tasks.
	my ($xstatus, $vstatus);
	if ((! -f $fxstatus && ! $live)
	    || (-f _ && (! ($xstatus = &evalinfo($fxstatus)) || $@)))
	{
	    $xstatus = { START => $now, END => $now, STATUS => -3,
		         DETAIL => "agent lost the transfer", LOG => "" };
	    return if ! &output($fxstatus, Dumper($xstatus));
	}

	if (-s $fvstatus && (! ($vstatus = &evalinfo($fvstatus)) || $@))
	{
	    $vstatus = { START => $now, END => $now, STATUS => -3,
		         LOG => "agent lost the file validation result" };
	    return if ! &output($fvstatus, Dumper($vstatus));
	}

	# Start verifying if transfer completed.
	if ($xstatus && ! $vstatus)
	{
	    if ($$self{VALIDATE_COMMAND})
	    {
		return if ! &output($fvstatus, "");
		$self->addJob(sub {
		        &output($fvstatus, Dumper ({
		            START => $now, END => &mytimeofday(),
		            STATUS => $_[0]{STATUS}, LOG => &input($fvlog) }));
		        $$jobinfo{RECHECK} = 1; },
	            { TIMEOUT => $$self{TIMEOUT}, LOGFILE => $fvlog },
	            @{$$self{VALIDATE_COMMAND}}, $$xstatus{STATUS},
	            @$taskinfo{qw(TO_PFN FILESIZE CHECKSUM)});
	    }
	    else
	    {
	        &output($fvstatus, Dumper({
		    START => $now, END => &mytimeofday(),
		    STATUS => $$xstatus{STATUS},
		    LOG => "validation bypassed" }));
		$$jobinfo{RECHECK} = 1;
	    }
	    $done = 0;
	}

        # Update task status for fully verified tasks.
	elsif ($vstatus && ! exists $$taskinfo{REPORT_CODE})
	{
	    # If the transfer failed, issue clean-up action without
	    # waiting it to return -- just go ahead with harvesting.
	    # The caller will in any case wait before proceeding.
	    $self->addJob(sub {}, { TIMEOUT => $$self{TIMEOUT} },
		@{$$self{DELETE_COMMAND}}, "post", $$taskinfo{TO_PFN})
		if $$vstatus{STATUS} && $$self{DELETE_COMMAND};

	    # FIXME: More elaborate transfer code reporting?
	    #  - validation: successful/terminated/timed out/error + detail + log
	    #      where detail specifies specific error (size mismatch, etc.)
	    #  - transfer: successful/terminated/timed out/error + detail + log
	    $$taskinfo{REPORT_CODE} =
		($$vstatus{STATUS} =~ /^-?\d+$/ ? $$vstatus{STATUS}
		 : 128 + ($$vstatus{STATUS} =~ /(\d+)/)[0]);
	    $$taskinfo{XFER_CODE} =
		($$xstatus{STATUS} =~ /^-?\d+$/ ? $$xstatus{STATUS}
		 : 128 + ($$xstatus{STATUS} =~ /(\d+)/)[0]);
	    $$taskinfo{LOG_DETAIL} = $$xstatus{DETAIL};
	    $$taskinfo{LOG_XFER} = $$xstatus{LOG};
	    $$taskinfo{LOG_VALIDATE} = $$vstatus{LOG};
	    $$taskinfo{TIME_UPDATE} = $$vstatus{END};
	    $$taskinfo{TIME_XFER} = $$xstatus{START};
	    $$taskinfo{JOBLOG} = "$$self{ARCHIVEDIR}/$jobname";
	    return if ! $self->taskDone($taskinfo);
	}

	# Otherwise we are still not done with this job.
	else
	{
	    $done = 0;
	}
    }

    # If we are done with the copy job, nuke it.
    if ($done)
    {
	$self->Logmsg("copy job $jobname completed") if $$self{VERBOSE};
	&mv($jobpath, "$$self{ARCHIVEDIR}/$jobname");
	delete $$jobs{$jobname};
    }
}

# Fill the backend with as many transfers as it can take.
# 
# The files are assigned to the link on a fair share basis.  Here the
# fairness means that we try to keep every link with transfers to its
# maximum capacity while spreading the number of available "transfer
# slots" as fairly as possible over the links which have transfers.
#
# The algorithm works by assigning each link weights as a ratio of
# successfully completed transfers vs. number of transfer slots used
# by the link, over the observation period (some hours).  The final
# probability assigned to each link is the fraction of its weight
# from the total weight over all links.  Every link always gets a
# probability greater than a small "epsilon" value, which guarantees
# every link eventually gets a chance to be tried.
#
# This algorithm tends to give more files to links which get through
# more files, but sharing the avaiable backend job slots fairly.  The
# weighting by consumsed transfer slots is a key factor as it permits
# the agent to detect which links benefit from being given more files.
sub fill
{
    my ($self, $jobs, $tasks) = @_;
    my (%stats, %todo, %sorted);
    my $now = &mytimeofday();
    my $nlinks = 0;

    # If the backend is busy, avoid doing heavy lifting.
    return if $$self{BACKEND}->isBusy($jobs, $tasks);

    # Determine links with pending transfers.
    foreach my $t (values %$tasks)
    {
	my $to = $$t{TO_NODE};
	my $from = $$t{FROM_NODE};

	next if ! $$t{PREPARED};
	next if exists $$t{REPORT_CODE};
	next if grep (exists $$_{TASKS}{$$t{TASKID}}, values %$jobs);

	# If the task is too near expiration, just mark it failed.
        # If it has already expired, just remove it.
	my $prettyhours = sprintf "%0.1fh ", ($now - $$t{TIME_ASSIGN})/3600;
	if ($now >= $$t{TIME_EXPIRE})
	{
	    $self->Logmsg("PhEDEx transfer task $$t{TASKID} has expired after $prettyhours, discarding");
	    unlink("$$self{TASKDIR}/$$t{TASKID}");
	    delete $$tasks{$$t{TASKID}};
	}
	elsif ($now >= $$t{TIME_EXPIRE} - 1200)
	{
	    $self->Logmsg("PhEDEx transfer task $$t{TASKID} was nearly expired after $prettyhours, discarding");
	    $$t{XFER_CODE} = -1;
	    $$t{REPORT_CODE} = -1;
	    $$t{LOG_DETAIL} = "transfer expired in the PhEDEx download agent queue after $prettyhours";
	    $$t{LOG_XFER} = "no transfer was attempted";
	    $$t{LOG_VALIDATE} = "no validation was attempted";
	    $$t{TIME_UPDATE} = $now;
	    $$t{TIME_XFER} = -1;
	    return if ! $self->taskDone($t);
	}

	# Consider this task.
	$nlinks++ if ! exists $todo{$to}{$from};
	push(@{$todo{$to}{$from}}, $t);
    }

    # Another quick exit if we have nothing to do.
    return if ! $nlinks;
    $self->Logmsg("balancing transfers on $nlinks links")
        if $$self{VERBOSE};

    # Determine link probability from recent usage.
    my $goodlinks = 0;
    foreach my $slot (@{$$self{STATS}})
    {
	foreach my $to (keys %{$$slot{LINKS}})
	{
	    foreach my $from (keys %{$$slot{LINKS}{$to}})
	    {
		my $s = $$slot{LINKS}{$to}{$from};
		# Add statistics based on link usage.
		$stats{$to}{$from} ||= { USED => 0, DONE => 0, ERRORS => 0 };
		$stats{$to}{$from}{DONE} += ($$s{DONE} || 0);
		$stats{$to}{$from}{USED} += ($$s{USED} || 0);
		$stats{$to}{$from}{ERRORS} += ($$s{ERRORS} || 0);

		# Count the "good" links: if something was accomplished and there weren't 100 errors
		if ($stats{$to}{$from}{DONE} && $stats{$to}{$from}{ERRORS} < 100) {
		    $goodlinks++;
		}
	    }
	}
    }

    my ($W, $wmin) = (0, 0.02 * $nlinks);
    my $skippedlinks = 0;
    foreach my $to (keys %todo)
    {
	foreach my $from (keys %{$todo{$to}})
	{
	    my $entry = $stats{$to}{$from} ||= {};

	    # Pass links with too many errors.
	    if (($$entry{ERRORS} || 0) > 100)
	    {
		$self->Logmsg("too many ($$entry{ERRORS}) recent errors on ",
			      "link $from -> $to, not allocating transfers")
		    if $$self{VERBOSE};
		delete $todo{$to}{$from};
		$skippedlinks++;
		next;
	    }

	    # Pass links which are busy
	    if ( $$self{BACKEND}->isBusy ($jobs, $tasks, $to, $from) ) {
		$self->Logmsg("link $from -> $to is busy at the moment, ",
			      "not allocating transfers")
		    if $$self{VERBOSE};
		delete $todo{$to}{$from};
		$skippedlinks++;
		next;
	    }

	    # Give links the weight of one if they have not been used.
	    if (! $$entry{USED})
	    {
		$$entry{W} = 1.0;
	    }

	    # Otherwise the weight is DONE/USED.
	    else
	    {
	        $$entry{W} = (1.0 * $$entry{DONE} / $$entry{USED});
	    }

	    # But if the weight is smaller than ~5 files/hour, clamp
	    # to that limit to guarantee minimum probability value.
	    $$entry{W} = $wmin if $$entry{W} < $wmin;

	    # Update total weight.
	    $W += $$entry{W};
	}
    }

    # If we have nothing to do because all the links were skipped,
    # check if there were any recent transfers on good links, and
    # sync faster if there was
    if ($skippedlinks == $nlinks && $goodlinks 
	&& $$self{NEXT_SYNC} - $now > 300 ) {
	$$self{NEXT_SYNC} = $now + 300;
	$self->Logmsg("all links were skipped, scheduling ",
		      "next synchronisation in five minutes")
	    if $$self{VERBOSE};
	return;
    }

    my @P;
    foreach my $to (sort keys %todo)
    {
	foreach my $from (sort keys %{$todo{$to}})
	{
	    # Compute final link probablity function.
	    my $low = (@P ? $P[$#P]{HIGH} : 0);
	    my $high = $low + $stats{$to}{$from}{W}/$W;
	    push(@P, { LOW => $low, HIGH => $high, TO => $to, FROM => $from });

            $self->Logmsg("link parameters for $from -> $to:"
		    . sprintf(' P=[%0.3f, %0.3f),', $P[$#P]{LOW}, $P[$#P]{HIGH})
		    . sprintf(' W=%0.3f,', $stats{$to}{$from}{W})
		    . " USED=@{[$stats{$to}{$from}{USED} || 0]},"
		    . " DONE=@{[$stats{$to}{$from}{DONE} || 0]},"
		    . " ERRORS=@{[$stats{$to}{$from}{ERRORS} || 0]}")
                if $$self{VERBOSE};
	}
    }


    # For each available job slot, determine which link should have
    # the transfers based on the probability function calculated from
    # the link statistics.  Then fill the job slot from the transfers
    # tasks on that link, in the order of task priority.
    my $exhausted = 0;
    while (! $$self{BACKEND}->isBusy($jobs, $tasks) && @P)
    {
	$self->maybeStop();

	# Select a link that merits to get the files.
	my ($i, $p) = (0, rand());
	$i++ while ($i < $#P && $p >= $P[$i]{HIGH});
	my $to = $P[$i]{TO};
	my $from = $P[$i]{FROM};

	# Get a sorted list of files for this link.
	if (! $sorted{$to}{$from})
	{
	    $todo{$to}{$from} =
	        [ sort { $$a{TIME_ASSIGN} <=> $$b{TIME_ASSIGN}
		         || $$a{RANK} <=> $$b{RANK} }
	          @{$todo{$to}{$from}} ];
	    $sorted{$to}{$from} = 1;
	}

	# Send files to transfer.
	my $id = $$self{BATCH_ID}++;
	my $jobname = "job.$$self{BOOTTIME}.$id";
	my $dir = "$$self{WORKDIR}/$jobname";
	&mkpath($dir);
	
	$$self{BACKEND}->startBatch ($jobs, $tasks, $dir, $jobname, $todo{$to}{$from});
	$self->Logmsg("copy job $jobname assigned to link $from -> $to with "
		      . sprintf('p=%0.3f and W=%0.3f and ', $p, $stats{$to}{$from}{W})
		      . scalar(@{$todo{$to}{$from}})
		      . " transfer tasks in queue")
	    if $$self{VERBOSE};

	my $linkbusy = $$self{BACKEND}->isBusy($jobs, $tasks, $to, $from);
	my $linkexhausted = @{$todo{$to}{$from}} ? 0 : 1;

	# If we exhausted the files on this link or the link is busy, remove the link's
	# share from P.  We have to recalculate P then also.
	if ( ($linkexhausted || $linkbusy) && ! $$self{BACKEND}->isBusy($jobs, $tasks))
	{
            $self->Logmsg("transfers on link $from -> $to exhausted, ",
			  "recalculating link probabilities")
	        if $linkexhausted && $$self{VERBOSE};

            $self->Logmsg("link $from -> $to is busy, ",
			  "recalculating link probabilities")
	        if $linkbusy && $$self{VERBOSE};
	    
	    splice(@P, $i, 1);
	    $W -= $stats{$to}{$from}{W};
	    for ($i = 0; $i <= $#P; ++$i)
	    {
                my $to = $P[$i]{TO};
                my $from = $P[$i]{FROM};
		$P[$i]{LOW} = ($i ? $P[$i-1]{HIGH} : 0);
		$P[$i]{HIGH} = $P[$i]{LOW} + $stats{$to}{$from}{W}/$W;

                $self->Logmsg("new link parameters for $from -> $to:"
		        . sprintf(' P=[%0.3f, %0.3f),',$P[$i]{LOW},$P[$i]{HIGH})
		        . sprintf(' W=%0.3f,', $stats{$to}{$from}{W})
			. " USED=@{[$stats{$to}{$from}{USED} || 0]},"
			. " DONE=@{[$stats{$to}{$from}{DONE} || 0]},"
			. " ERRORS=@{[$stats{$to}{$from}{ERRORS} || 0]}")
                    if $$self{VERBOSE};
	    }

	    if ($linkexhausted) {
		--$nlinks;
		++$exhausted;
	    }
        }
    }

    # If we exhausted all transfer tasks on a link, make sure the next
    # synchronisation will occur relatively soon.  If we exhausted
    # tasks on all links, synchronise immediately.  This applies only
    # on transition from having tasks to not having them (only), so we
    # are not forcing continuous unnecessary reconnects.
    if (! $nlinks && $$self{NEXT_SYNC} > $now)
    {
	$$self{NEXT_SYNC} = $now-1;
	$self->Logmsg("ran out of tasks, scheduling immediate synchronisation")
	    if $$self{VERBOSE};
    }
    elsif ($exhausted && $$self{NEXT_SYNC} - $now > 300)
    {
	$$self{NEXT_SYNC} = $now + 300;
	$self->Logmsg("ran out of tasks on $exhausted links, scheduling"
		. " next synchronisation in five minutes")
	    if $$self{VERBOSE};
    }
}

# Initialise agent.
sub init
{
    my ($self) = @_;
    $self->statsNewPeriod({}, {});
}

# Run agent main loop.
sub idle
{
    my ($self, @pending) = @_;

    eval
    {
	my (%tasks, %jobs);
	my $now = &mytimeofday();

	# Read in and verify all transfer tasks.
	my @tasknames;
	return if ! &getdir($$self{TASKDIR}, \@tasknames);

	foreach (@tasknames)
	{
	    my $info = &evalinfo("$$self{TASKDIR}/$_");
	    if (! $info || $@)
	    {
		$self->Alert("garbage collecting corrupted transfer task $_ ($info, $@)");
		unlink("$$self{TASKDIR}/$_");
		$$self{NEXT_PURGE} = 0;
		next;
	    }
	    $tasks{$_} = $info;
	}

	# Read in and verify all copy jobs.
	foreach (@pending)
	{
	    my $info = &evalinfo("$$self{WORKDIR}/$_/info");
	    if (! $info || $@)
	    {
		$self->Alert("garbage collecting corrupted copy job $_");
		&rmtree("$$self{WORKDIR}/$_");
		$$self{NEXT_PURGE} = 0;
		next;
	    }
	    $jobs{$_} = $info;
	}

	# Kill ghost transfers in the database and locally.
	if ($$self{NEXT_PURGE} <= $now)
	{
	    $self->reconnect() if ! $self->connectionValid();
	    $self->purgeLostTransfers(\%jobs, \%tasks);
	    $$self{NEXT_PURGE} = $now + 3600;
	    $$self{DBH_LAST_USE} = $now;
	}

	# prepare some tasks
	$self->prepare(\%tasks);
	while (@{$$self{JOBS}})
	{
	    $self->pumpJobs();
	    select(undef, undef, undef, .1);
	}

	# Rescan jobs for completed tasks and fill the backend a few
        # times each.  In between each round flush validation and
	# file removal processes to finalise job completion.  Fill
	# once more at the end in case @check is empty.
	my @check = grep (exists $jobs{$_}, @pending);
	for (my $i = 0; @check && $i < 5; ++$i)
	{
	    $self->check($_, \%jobs, \%tasks) for @check;
            $self->fill(\%jobs, \%tasks);

	    while (@{$$self{JOBS}})
	    {
	        $self->pumpJobs();
	        select(undef, undef, undef, .1);
	    }

	    @check = grep (exists $jobs{$_} && $jobs{$_}{RECHECK}, @pending);
    	    delete $$_{RECHECK} for values %jobs;
        }

        $self->fill(\%jobs, \%tasks);
	while (@{$$self{JOBS}})
	{
	    $self->pumpJobs();
	    select(undef, undef, undef, .1);
	}

	# Create new time period with current statistics.
        $self->statsNewPeriod(\%jobs, \%tasks);

	# Reconnect if we are due a database sync, but use a database
	# connection opportunistically if we happen to have one.
	$now = &mytimeofday();
	my $need_sync = ($$self{NEXT_SYNC} <= $now ? 1 : 0);
	my $need_advert = ($$self{LAST_CONNECT} <= $now - 2400 ? 1 : 0);
	my $report_sync = ($$self{LAST_COMPLETED} > $$self{LAST_SYNC} ? 1 : 0);
	my $recent_sync = ($$self{LAST_SYNC} >= $now - 120 ? 1 : 0);
	if (($need_sync || $need_advert || $$self{DBH})
	    && ($report_sync || ! $recent_sync))
	{
	    $self->reconnect() if ! $self->connectionValid() || $need_advert;
	    $self->doSync(\%jobs, \%tasks);
	    $$self{LAST_SYNC} = $now;
	    $$self{NEXT_SYNC} = $now + 1800;
	    $$self{DBH_LAST_USE} = $now if $need_sync;
	}

	# Remember current time if we are seeing work.
	$$self{LAST_WORK} = $now if %tasks;

	# Detach from the database if the connection wasn't used
	# recently (at least one minute) and if it looks the agent
	# has enough work for some time and next synchronisation
	# is not imminent.
	if (defined $$self{DBH}
	    && $$self{NEXT_SYNC} - $now > 600
	    && $now - $$self{DBH_LAST_USE} > 60
	    && ($$self{BACKEND}->isBusy(\%jobs, \%tasks)
		|| $now - $$self{LAST_WORK} > 4*3600))
	{
	    $self->Logmsg("disconnecting from database");
	    $self->disconnectAgent(1);
	}

	# Purge info about old jobs.
	if ($$self{NEXT_CLEAR} <= $now)
	{
	    my $archivedir = $$self{ARCHIVEDIR};
	    my @old = <$archivedir/*>;
	    &rmtree($_) for (scalar @old > 500 ? @old 
			     : grep((stat($_))[9] < $now - 86400, @old));
	    $$self{NEXT_CLEAR} = $now + 3600;
	}
    };
    do { chomp ($@); $self->Alert ($@); $$self{NEXT_PURGE} = 0;
	 eval { $$self{DBH}->rollback() } if $$self{DBH}; } if $@;

    # Clear zombie detached processes in the backend.
    $$self{BACKEND}->pumpJobs();
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  if ( $self->{BACKEND}->can('setup_callbacks') )
  { $self->{BACKEND}->setup_callbacks($kernel,$session) }
}

1;
