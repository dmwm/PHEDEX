package PHEDEX::Core::DB;

=head1 NAME

PHEDEX::Core::DB - a drop-in replacement for Toolkit/UtilsDB

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(parseDatabaseInfo connectToDatabase disconnectFromDatabase
		 expandNodesAndConnect myNodeFilter otherNodeFilter
		 dbsql dbexec dbprep dbbindexec);
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Net;
use DBI;
use Cwd;

# Parse database connection arguments.
sub parseDatabaseInfo
{
    my ($self) = @_;

    $$self{DBH_LIFE} = 86400;
    $$self{DBH_AGE} = 0;
    if ($$self{DBCONFIG} =~ /(.*):(.*)/)
    {
	$$self{DBCONFIG} = $1;
	$$self{DBSECTION} = $2;
    }

    my $insection = $$self{DBSECTION} ? 0 : 1;
    open (DBCONF, "< $$self{DBCONFIG}")
	or die "$$self{DBCONFIG}: $!\n";

    while (<DBCONF>)
    {
	chomp; s/#.*//; s/^\s+//; s/\s+$//; s/\s+/ /g; next if /^$/;
	if (/^Section (\S+)$/) {
	    $insection = ($1 eq $$self{DBSECTION});
	} elsif (/^Interface (\S+)$/) {
	    $$self{DBH_DBITYPE} = $1 if $insection;
	} elsif (/^Database (\S+)$/) {
	    $$self{DBH_DBNAME} = $1 if $insection;
	} elsif (/^AuthDBUsername (\S+)$/) {
	    $$self{DBH_DBUSER} = $1 if $insection;
	} elsif (/^AuthDBPassword (\S+)$/) {
	    $$self{DBH_DBPASS} = $1 if $insection;
	} elsif (/^AuthRole (\S+)$/) {
	    $$self{DBH_DBROLE} = $1 if $insection;
	} elsif (/^AuthRolePassword (\S+)$/) {
	    $$self{DBH_DBROLE_PASS} = $1 if $insection;
	} elsif (/^ConnectionLife (\d+)$/) {
	    $$self{DBH_LIFE} = $1 if $insection;
	    $$self{DBH_CACHE} = 0 if $insection && $1 == 0;
	} elsif (/^LogConnection (on|off)$/) {
	    $$self{DBH_LOGGING} = ($1 eq 'on') if $insection;
	} elsif (/^LogSQL (on|off)$/) {
	    $ENV{PHEDEX_LOG_SQL} = ($1 eq 'on') if $insection;
	} elsif (/^SessionSQL (.*)$/) {
	    push(@{$$self{DBH_SESSION_SQL}}, $1);
	} elsif (/^SchemaPrefix (.*)$/) {
	    push(@{$$self{DBH_SCHEMA_PREFIX}}, $1);
	} else {
	    die "$$self{DBCONFIG}: $.: Unrecognised line\n";
	}
    }
    close (DBCONF);

    die "$$self{DBCONFIG}: database parameters not found\n"
	if (! $$self{DBH_DBITYPE} || ! $$self{DBH_DBNAME}
	    || ! $$self{DBH_DBUSER} || ! $$self{DBH_DBPASS});

    die "$$self{DBCONFIG}: role specified without username or password\n"
	if ($$self{DBH_DBROLE} && ! $$self{DBH_DBROLE_PASS});
}

# Create a connection to the transfer database.  Updates the agent's
# last contact, inserting the agent entries if necessary.  Takes one
# argument, the reference to the agent, which must have the standard
# database-related data members DBITYPE, DBNAME, DBUSER, DBPASS, and
# the TMDB node MYNODE.  The automatic identification is suppressed
# if a second optional argument is given and it's value is zero.
# Database connections are cached into $$self{DBH}.
sub connectToDatabase
{
    my ($self, $identify) = @_;

    # If we have database configuration file, read it
    &parseDatabaseInfo ($self) if ($$self{DBCONFIG} && ! $$self{DBH_DBNAME});

    # Use cached connection if it's still alive and the handle
    # isn't too old, otherwise create new one.
    my $dbh = $$self{DBH};
    if (! $$self{DBH}
	|| $$self{DBH}{private_phedex_invalid}
	|| time() - $$self{DBH_AGE} > $$self{DBH_LIFE}
	|| (! eval { $$self{DBH}->ping() } || $@)
	|| (! eval { $dbh->do("select sysdate from dual") } || $@))
    {
	$$self{DBH_LOGGING} = 1 if $ENV{PHEDEX_LOG_DB_CONNECTIONS};
	&logmsg ("(re)connecting to database") if $$self{DBH_LOGGING};

	# Clear previous connection.
	eval { &disconnectFromDatabase ($self, $$self{DBH}, 1) } if $$self{DBH};
	undef $$self{DBH};

        # Start a new connection.
	$$self{DBH_ID_HOST} = &getfullhostname();
	$$self{DBH_ID_MODULE} = $0; $$self{DBH_ID_MODULE} =~ s!.*/!!;
	$$self{DBH_ID_LABEL} = $$self{LOGFILE} || ""; $$self{DBH_ID_LABEL} =~ s!.*/!!;
	$$self{DBH_ID_LABEL} = " ($$self{DBH_ID_LABEL})" if $$self{DBH_ID_LABEL};
	$$self{DBH_ID} = "$$self{DBH_ID_MODULE}\@$$self{DBH_ID_HOST}$$self{DBH_ID_LABEL}";
        $dbh = DBI->connect ("DBI:$$self{DBH_DBITYPE}:$$self{DBH_DBNAME}",
	    		     $$self{DBH_DBUSER}, $$self{DBH_DBPASS},
			     { RaiseError => 1,
			       AutoCommit => 0,
			       PrintError => 0,
			       ora_module_name => $$self{DBH_ID} });
        die "failed to connect to the database\n" if ! $dbh;

	# Acquire role if one was specified.  Do not use &dbexec() here
	# as it will expose the password used in the logs.
	if ($$self{DBH_DBROLE})
	{
	    eval { $dbh->do ("set role $$self{DBH_DBROLE} identified by"
		             . " $$self{DBH_DBROLE_PASS}") };
	    die "failed to authenticate to $$self{DBH_DBNAME} as"
	        . " $$self{DBH_DBUSER} using role $$self{DBH_DBROLE}\n"
		if $@;
	}

	# Execute session SQL statements.
	&dbexec($dbh, $_) for @{$$self{DBH_SESSION_SQL}};

	# Cache it.
	$$dbh{FetchHashKeyName} = "NAME_uc";
	$$dbh{LongReadLen} = 4096;
	$$dbh{RowCacheSize} = 10000;
	$$self{DBH_AGE} = time();
	$$self{DBH} = $dbh;
	$$dbh{private_phedex_invalid} = 0;
	$$dbh{private_phedex_prefix} = $$self{DBH_SCHEMA_PREFIX};
        $$dbh{private_phedex_newconn} = 1;
    }

    # Reset statement cache
    $$dbh{private_phedex_stmtcache} = {};

    # Was identification suppressed?
    return $dbh if defined $identify && $identify == 0;

    # Make myself known.  If this fails, the database is probably
    # so wedged that we can't do anything useful, so bail out.
    # The caller is in charge of committing or rolling back on
    # any errors raised.
    &updateAgentStatus ($self, $dbh);
    &identifyAgent ($self, $dbh);
    &checkAgentMessages ($self, $dbh);

    return $dbh;
}

# Disconnect from the database.  Normally this does nothing, as we
# cache the connection and try to keep it alive as long as we can
# without disturbing program robustness.  If $$self{DBH_CACHE} is
# defined and zero, connection caching is turned off.
sub disconnectFromDatabase
{
    my ($self, $dbh, $force) = @_;

    # Finish statements in the cache.
    $_->finish() for values %{$$dbh{private_phedex_stmtcache}};
    $$dbh{private_phedex_stmtcache} = {};

    # Actually disconnect if required.
    if ((exists $$self{DBH_CACHE} && ! $$self{DBH_CACHE}) || $force)
    {
	&logmsg ("disconnected from database") if $$self{DBH_LOGGING};
        eval { $dbh->disconnect() } if $dbh;
        undef $dbh;
        undef $$self{DBH};
        undef $$self{DBH_AGE};
    }
}

######################################################################
# Utilities used during agent login.  These really belong somewhere
# else (PHEDEX::Core::Agent?), not in the core database logic.

# Identify the version of the code packages running in this agent.
# Scan all the perl modules imported into this process, and identify
# each significant piece of code.  We collect following information:
# relative file name, file size in bytes, MD5 sum of the file contents,
# PhEDEx distribution version, the CVS revision and tag of the file.
sub identifyAgent
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();

    # If we have a new database connection, log agent start-up and/or
    # new database connection into the logging table.
    if ($$dbh{private_phedex_newconn})
    {
	my ($ident) = qx(ps -p $$ wwwwuh 2>/dev/null);
	chomp($ident) if $ident;
	&dbexec($dbh, qq{
	    insert into t_agent_log
	    (time_update, reason, host_name, user_name, process_id,
	     working_directory, state_directory, message)
	    values
	    (:now, :reason, :host_name, :user_name, :process_id,
	     :working_dir, :state_dir, :message)},
	    ":now" => $now,
	    ":reason" => ($$self{DBH_AGENT_IDENTIFIED}{$$self{MYNODE}}
			  ? "AGENT RECONNECTED" : "AGENT STARTED"),
	    ":host_name" => $$self{DBH_ID_HOST},
	    ":user_name" => scalar getpwuid($<),
	    ":process_id" => $$,
	    ":working_dir" => &getcwd(),
	    ":state_dir" => $$self{DROPDIR},
	    ":message" => $ident);
	$$dbh{private_phedex_newconn} = 0;
	$dbh->commit();
    }

    # Avoid re-identifying ourselves further if already done.
    return if $$self{DBH_AGENT_IDENTIFIED}{$$self{MYNODE}};

    # Get PhEDEx distribution version.
    my $distribution = undef;
    my $versionfile = $INC{'PHEDEX/Core/DB.pm'};
    $versionfile =~ s|/perl_lib/.*|/VERSION|;
    if (open (DBHVERSION, "< $versionfile"))
    {
	chomp ($distribution = <DBHVERSION>);
	close (DBHVERSION);
    }

    # Get all interesting modules loaded into this process.
    my @files = ($0, grep (m!(^|/)(PHEDEX|Toolkit|Utilities|Custom)/!, values %INC));
    return if ! @files;

    # Get the file data for each module: size, checksum, CVS info.
    my %fileinfo = ();
    my %cvsinfo = ();
    foreach my $file (@files)
    {
	my ($path, $fname) = ($file =~ m!(.*)/(.*)!);
	$fname = $file if ! defined $fname;
	next if exists $fileinfo{$fname};

	if (defined $path)
	{
	    if (-d $path && ! exists $cvsinfo{$path} && open (DBHCVS, "< $path/CVS/Entries"))
	    {
		while (<DBHCVS>)
		{
		    chomp;
		    my ($type, $cvsfile, $rev, $date, $flags, $sticky) = split("/", $_);
		    next if ! $cvsfile || ! $rev;
		    $cvsinfo{$path}{$cvsfile} = {
			REVISION => $rev,
			REVDATE => $date,
			FLAGS => $flags,
			STICKY => $sticky
		    };
		}
		close (DBHCVS);
	    }

	    $fileinfo{$fname} = $cvsinfo{$path}{$fname}
	        if exists $cvsinfo{$path}{$fname};
	}

	if (-f $file)
	{
	    if (my $cksum = qx(md5sum $file 2>/dev/null))
	    {
		chomp ($cksum);
		my ($sum, $f) = split(/\s+/, $cksum);
		$fileinfo{$fname}{CHECKSUM} = "MD5:$sum";
	    }

	    $fileinfo{$fname}{SIZE} = -s $file;
	    $fileinfo{$fname}{DISTRIBUTION} = $distribution;
	}
    }

    # Update the database
    my $stmt = &dbprep ($dbh, qq{
	insert into t_agent_version
	(node, agent, time_update,
	 filename, filesize, checksum,
	 release, revision, tag)
	values
	(:node, :agent, :now,
	 :filename, :filesize, :checksum,
	 :release, :revision, :tag)});
	
    &dbexec ($dbh, qq{
	delete from t_agent_version
	where node = :node and agent = :me},
	":node" => $$self{ID_MYNODE},
	":me" => $$self{ID_AGENT});

    foreach my $fname (keys %fileinfo)
    {
	&dbbindexec ($stmt,
		     ":now" => $now,
		     ":node" => $$self{ID_MYNODE},
		     ":agent" => $$self{ID_AGENT},
		     ":filename" => $fname,
		     ":filesize" => $fileinfo{$fname}{SIZE},
		     ":checksum" => $fileinfo{$fname}{CHECKSUM},
		     ":release" => $fileinfo{$fname}{DISTRIBUTION},
		     ":revision" => $fileinfo{$fname}{REVISION},
		     ":tag" => $fileinfo{$fname}{STICKY});
    }

    $dbh->commit ();
    $$self{DBH_AGENT_IDENTIFIED}{$$self{MYNODE}} = 1;
}

# Update the agent status in the database.  This identifies the
# agent as having connected recently and alive.
sub updateAgentStatus
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();
    return if ($$self{DBH_AGENT_UPDATE}{$$self{MYNODE}} || 0) > $now - 5*60;

    # Obtain my node id
    my $me = $$self{AGENTID} || $0; $me =~ s|.*/||;
    ($$self{ID_MYNODE}) = &dbexec($dbh, qq{
	select id from t_adm_node where name = :node},
	":node" => $$self{MYNODE})->fetchrow();
    die "node $$self{MYNODE} not known to the database\n"
        if ! defined $$self{ID_MYNODE};

    # Check whether agent and agent status rows exist already.
    ($$self{ID_AGENT}) = &dbexec($dbh, qq{
	select id from t_agent where name = :me},
	":me" => $me)->fetchrow();
    my ($state) = &dbexec($dbh, qq{
	select state from t_agent_status
	where node = :node and agent = :agent},
    	":node" => $$self{ID_MYNODE}, ":agent" => $$self{ID_AGENT})
    	->fetchrow();

    # Add agent if doesn't exist yet.
    if (! defined $$self{ID_AGENT})
    {
        eval
	{
	    &dbexec($dbh, qq{
	        insert into t_agent (id, name)
	        values (seq_agent.nextval, :me)},
	        ":me" => $me);
	};
	die $@ if $@ && $@ !~ /ORA-00001:/;
        ($$self{ID_AGENT}) = &dbexec($dbh, qq{
	    select id from t_agent where name = :me},
	    ":me" => $me)->fetchrow();
    }

    # Add agent status if doesn't exist yet.
    my ($ninbox, $npending, $nreceived, $ndone, $nbad, $noutbox) = (0) x 7;
    my $dir = $$self{DROPDIR}; $dir =~ s|/worker-\d+$||; $dir =~ s|/[^/]+$||;
    my $label = $$self{DROPDIR}; $label =~ s|/worker-\d+$||; $label =~ s|.*/||;
    my $wid = ($$self{DROPDIR} =~ /worker-(\d+)$/ ? "W$1" : "M");
    my $fqdn = $$self{DBH_ID_HOST};
    my $pid = $$;

    my $dirtmp = $$self{DROPDIR};
    foreach my $d (<$dirtmp/inbox/*>) {
	$ninbox++;
	$nreceived++ if -f "$d/go";
    }

    foreach my $d (<$dirtmp/work/*>) {
	$npending++;
	$nbad++ if -f "$d/bad";
	$ndone++ if -f "$d/done";
    }

    foreach my $d (<$dirtmp/outbox/*>) {
	$noutbox++;
    }

    &dbexec($dbh, qq{
	merge into t_agent_status ast
	using (select :node node, :agent agent, :label label, :wid worker_id,
	              :fqdn host_name, :dir directory_path, :pid process_id,
	              1 state, :npending queue_pending, :nreceived queue_received,
	              :nwork queue_work, :ncompleted queue_completed,
	              :nbad queue_bad, :noutgoing queue_outgoing, :now time_update
	       from dual) i
	on (ast.node = i.node and
	    ast.agent = i.agent and
	    ast.label = i.label and
	    ast.worker_id = i.worker_id)
	when matched then
	  update set
	    ast.host_name       = i.host_name,
	    ast.directory_path  = i.directory_path,
	    ast.process_id      = i.process_id,
	    ast.state           = i.state,
	    ast.queue_pending   = i.queue_pending,
	    ast.queue_received  = i.queue_received,
	    ast.queue_work      = i.queue_work,
	    ast.queue_completed = i.queue_completed,
	    ast.queue_bad       = i.queue_bad,
	    ast.queue_outgoing  = i.queue_outgoing,
	    ast.time_update     = i.time_update
	when not matched then
          insert (node, agent, label, worker_id, host_name, directory_path,
		  process_id, state, queue_pending, queue_received, queue_work,
		  queue_completed, queue_bad, queue_outgoing, time_update)
	  values (i.node, i.agent, i.label, i.worker_id, i.host_name, i.directory_path,
		  i.process_id, i.state, i.queue_pending, i.queue_received, i.queue_work,
		  i.queue_completed, i.queue_bad, i.queue_outgoing, i.time_update)},
       ":node"       => $$self{ID_MYNODE},
       ":agent"      => $$self{ID_AGENT},
       ":label"      => $label,
       ":wid"        => $wid,
       ":fqdn"       => $fqdn,
       ":dir"        => $dir,
       ":pid"        => $pid,
       ":npending"   => $ninbox - $nreceived,
       ":nreceived"  => $nreceived,
       ":nwork"      => $npending - $nbad - $ndone,
       ":ncompleted" => $ndone,
       ":nbad"       => $nbad,
       ":noutgoing"  => $noutbox,
       ":now"        => $now);

    $dbh->commit();
    $$self{DBH_AGENT_UPDATE}{$$self{MYNODE}} = $now;
}

# Now look for messages to me.  There may be many, so handle
# them in the order given, but only act on the final state.
# The possible messages are "STOP" (quit), "SUSPEND" (hold),
# "GOAWAY" (permanent stop), and "RESTART".  We can act on the
# first three commands, but not the last one, except if the
# latter has been superceded by a later message: if we see
# both STOP/SUSPEND/GOAWAY and then a RESTART, just ignore
# the messages before RESTART.
#
# When we see a RESTART or STOP, we "execute" it and delete all
# messages up to and including the message itself (a RESTART
# seen by the agent is likely indication that the manager did
# just that; it is not a message we as an agent can do anything
# about, an agent manager must act on it, so if we see it, it's
# an indicatioon the manager has done what was requested).
# SUSPENDs we leave in the database until we see a RESTART.
#
# Messages are only executed until my current time; there may
# be "scheduled intervention" messages for future.
sub checkAgentMessages
{
    my ($self, $dbh) = @_;

    while (1)
    {
	my $now = &mytimeofday ();
	my ($time, $action, $keep) = (undef, 'CONTINUE', 0);
	my $messages = &dbexec($dbh, qq{
	    select time_apply, message
	    from t_agent_message
	    where node = :node and agent = :me
	    order by time_apply asc},
	    ":node" => $$self{ID_MYNODE},
	    ":me" => $$self{ID_AGENT});
        while (my ($t, $msg) = $messages->fetchrow())
	{
	    # If it's a message for a future time, stop processing.
	    last if $t > $now;

	    if ($msg eq 'SUSPEND' && $action ne 'STOP')
	    {
		# Hold, keep this in the database.
		($time, $action, $keep) = ($t, $msg, 1);
		$keep = 1;
	    }
	    elsif ($msg eq 'STOP')
	    {
		# Quit.  Something to act on, and kill this message
		# and anything that preceded it.
		($time, $action, $keep) = ($t, $msg, 0);
	    }
	    elsif ($msg eq 'GOAWAY')
	    {
		# Permanent quit: quit, but leave the message in
		# the database to prevent restarts before 'RESTART'.
		($time, $action, $keep) = ($t, 'STOP', 1);
	    }
	    elsif ($msg eq 'RESTART')
	    {
		# Restart.  This is not something we can have done,
		# so the agent manager must have acted on it, or we
		# are processing historical sequence.  We can kill
		# this message and everything that preceded it, and
		# put us back into 'CONTINUE' state to override any
		# previous STOP/SUSPEND/GOAWAY.
		($time, $action, $keep) = (undef, 'CONTINUE', 0);
	    }
	    else
	    {
		# Keep anything we don't understand, but no action.
		$keep = 1;
	    }

	    &dbexec($dbh, qq{
		delete from t_agent_message
		where node = :node and agent = :me
		  and (time_apply < :t or (time_apply = :t and message = :msg))},
	      	":node" => $$self{ID_MYNODE},
		":me" => $$self{ID_AGENT},
		":t" => $t,
		":msg" => $msg)
	        if ! $keep;
	}

	# Apply our changes.
	$messages->finish();
	$dbh->commit();

	# Act on the final state.
	if ($action eq 'STOP')
	{
	    &logmsg ("agent stopped via control message at $time");
	    $self->doStop ();
	    exit(0); # Still running?
	}
	elsif ($action eq 'SUSPEND')
	{
	    # The message doesn't actually specify for how long, take
	    # a reasonable nap to avoid filling the log files.
	    &logmsg ("agent suspended via control message at $time");
	    $self->nap (90);
	    next;
	}
	else
	{
	    # Good to go.
	    last;
	}
    }
}

######################################################################
# Expand a list of node patterns into node names.  This function is
# called when we don't yet know our "node identity."  Also runs the
# usual agent identification process against the database.
sub expandNodesAndConnect
{
    my ($self, $require) = @_;
    my $dbh = &connectToDatabase ($self, 0);
    my $now = &mytimeofday();
    my @result = ($dbh);

    # Construct a query filter for required other agents to be active
    my (@filters, %args);
    foreach my $agent ($require ? keys %$require : ())
    {
	my $var = ":agent@{[scalar @filters]}";
	push(@filters, "(a.name like ${var}n and s.time_update >= ${var}t)");
	$args{"${var}t"} = $now - $$require{$agent};
	$args{"${var}n"} = $agent;
    }
    my $filter = "";
    $filter = ("and exists (select 1 from t_agent_status s"
	       . " join t_agent a on a.id = s.agent"
	       . " where s.node = n.id and ("
	       . join(" or ", @filters) . "))")
	if @filters;

    # Now expand to the list of nodes
    foreach my $pat (@{$$self{NODES}})
    {
	my $q = &dbexec($dbh, qq{
	    select id, name from t_adm_node n
	    where n.name like :pat $filter
	    order by name},
	    ":pat" => $pat, %args);
	while (my ($id, $name) = $q->fetchrow())
	{
	    $$self{NODES_ID}{$name} = $id;
	    push(@result, $name);

	    $$self{MYNODE} = $name;
	    &updateAgentStatus ($self, $dbh);
	    &identifyAgent ($self, $dbh);
	    &checkAgentMessages ($self, $dbh);
	    $$self{MYNODE} = undef;
	}
    }

    return @result;
}

# Construct a database query for destination node pattern
sub myNodeFilter
{
    my ($self, $idfield) = @_;
    my (@filter, %args);
    my $n = 1;
    foreach my $id (values %{$$self{NODES_ID}})
    {
	$args{":dest$n"} = $id;
	push(@filter, "$idfield = :dest$n");
	++$n;
    }

    my $filter =  "(" . join(" or ", @filter) . ")";
    return ($filter, %args);
}

# Construct database query parameters for ignore/accept filters.
sub otherNodeFilter
{
    my ($self, $idfield) = @_;
    my $now = &mytimeofday();
    if (($$self{IGNORE_NODES_IDS}{LAST_CHECK} || 0) < $now - 300)
    {
	my $q = &dbprep($$self{DBH}, qq{
	    select id from t_adm_node where name like :pat});

	my $index = 0;
	foreach my $pat (@{$$self{IGNORE_NODES}})
	{
	    &dbbindexec($q, ":pat" => $pat);
	    while (my ($id) = $q->fetchrow())
	    {
	        $$self{IGNORE_NODES_IDS}{MAP}{++$index} = $id;
	    }
        }

	$index = 0;
	foreach my $pat (@{$$self{ACCEPT_NODES}})
        {
	    &dbbindexec($q, ":pat" => $pat);
	    while (my ($id) = $q->fetchrow())
	    {
	        $$self{ACCEPT_NODES_IDS}{MAP}{++$index} = $id;
	    }
        }

	$$self{IGNORE_NODES_IDS}{LAST_CHECK} = $now;
    }

    my (@ifilter, @afilter, %args);
    while (my ($n, $id) = each %{$$self{IGNORE_NODES_IDS}{MAP}})
    {
	$args{":ignore$n"} = $id;
	push(@ifilter, "$idfield != :ignore$n");
    }
    while (my ($n, $id) = each %{$$self{ACCEPT_NODES_IDS}{MAP}})
    {
	$args{":accept$n"} = $id;
	push(@afilter, "$idfield = :accept$n");
    }

    my $ifilter = (@ifilter ? join(" and ", @ifilter) : "");
    my $afilter = (@afilter ? join(" or ", @afilter) : "");
    if (@ifilter && @afilter)
    {
	return ("and ($ifilter) and ($afilter)", %args);
    }
    elsif (@ifilter)
    {
	return ("and ($ifilter)", %args);
    }
    elsif (@afilter)
    {
	return ("and ($afilter)", %args);
    }
    return ("", ());
}

######################################################################
# Tidy up SQL statement
sub dbsql
{
    my ($sql) = @_;
    $sql =~ s/--.*//mg;
    $sql =~ s/^\s+//mg;
    $sql =~ s/\s+$//mg;
    $sql =~ s/\n/ /g;
    return $sql;
}

# Simple utility to prepare a SQL statement
sub dbprep
{
    my ($dbh, $sql) = @_;
    if (my $stmt = $$dbh{private_phedex_stmtcache}{$sql})
    {
	$stmt->finish();
	return $stmt;
    }

    my $stmt = eval { return ($$dbh{private_phedex_stmtcache}{$sql}
			      = $dbh->prepare (&dbsql ($sql))) };
    return $stmt if ! $@;

    # Handle disconnected oracle handle, flag the handle bad
    $$dbh{private_phedex_invalid} = 1
        if ($@ =~ /ORA-(?:03114|03135|01031|01012):/
	    || $@ =~ /TNS:listener/);
    die $@;
}

# Simple utility to prepare, bind and execute a SQL statement.
sub dbexec
{
    my ($dbh, $sql, %params) = @_;
    my $stmt = &dbprep ($dbh, $sql);
    my $rv = &dbbindexec ($stmt, %params);
    return wantarray ? ($stmt, $rv) : $stmt;
}

# Simple bind and execute a SQL statement.
sub dbbindexec
{
    my ($stmt, %params) = @_;

    if ($ENV{PHEDEX_LOG_SQL})
    {
        my $sql = $$stmt{Statement};
	$sql =~ s/\s+/ /g; $sql =~ s/^\s+//; $sql =~ s/\s+$//;
	my $bound = join (", ", map { "($_, " . (defined $params{$_} ? $params{$_} : "undef") . ")" } sort keys %params);
        &logmsg ("executing statement `$sql' [$bound]");
    }

    my $isarray = 0;
    while (my ($param, $val) = each %params)
    {
	if (ref $val eq 'ARRAY')
	{
	    $stmt->bind_param_array ($param, $val);
	    $isarray++;
	}
	elsif (ref $val)
	{
	    $stmt->bind_param_inout ($param, $val, 4096);
	}
	else
	{
	    $stmt->bind_param ($param, $val);
	}
    }

    my $rv = eval {
	return $isarray
	    ? $stmt->execute_array({ ArrayTupleResult => [] })
	    : $stmt->execute();
    };
    return $rv if ! $@;

    # Flag handle bad on disconnected oracle handle
    $$stmt{Database}{private_phedex_invalid} = 1
        if ($@ =~ /ORA-(?:03114|03135|01031):/
	    || $@ =~ /TNS:listener/);
    die $@;
}
