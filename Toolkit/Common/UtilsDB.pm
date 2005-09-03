package UtilsDB; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(parseDatabaseInfo connectToDatabase disconnectFromDatabase
                 dbsql dbexec dbprep dbbindexec);
use UtilsLogging;
use UtilsTiming;
use DBI;

# Parse database connection arguments.
sub parseDatabaseInfo
{
    my ($self) = @_;

    $self->{DBH_LIFE} = 86400;
    $self->{DBH_AGE} = 0;
    if ($self->{DBCONFIG} =~ /(.*):(.*)/)
    {
	$self->{DBCONFIG} = $1;
	$self->{DBSECTION} = $2;
    }

    my $insection = $self->{DBSECTION} ? 0 : 1;
    open (DBCONF, "< $self->{DBCONFIG}")
	or die "$self->{DBCONFIG}: $!\n";

    while (<DBCONF>)
    {
	chomp; s/#.*//; s/^\s+//; s/\s+$//; s/\s+/ /g; next if /^$/;
	if (/^Section (\S+)$/) {
	    $insection = ($1 eq $self->{DBSECTION});
	} elsif (/^Interface (\S+)$/) {
	    $self->{DBH_DBITYPE} = $1 if $insection;
	} elsif (/^Database (\S+)$/) {
	    $self->{DBH_DBNAME} = $1 if $insection;
	} elsif (/^AuthDBUsername (\S+)$/) {
	    $self->{DBH_DBUSER} = $1 if $insection;
	} elsif (/^AuthDBPassword (\S+)$/) {
	    $self->{DBH_DBPASS} = $1 if $insection;
	} elsif (/^AuthRole (\S+)$/) {
	    $self->{DBH_DBROLE} = $1 if $insection;
	} elsif (/^AuthRolePassword (\S+)$/) {
	    $self->{DBH_DBROLE_PASS} = $1 if $insection;
	} elsif (/^ConnectionLife (\d+)$/) {
	    $self->{DBH_LIFE} = $1 if $insection;
	    $self->{DBH_CACHE} = 0 if $insection && $1 == 0;
	} elsif (/^LogConnection (on|off)$/) {
	    $self->{DBH_LOGGING} = ($1 eq 'on') if $insection;
	} elsif (/^LogSQL (on|off)$/) {
	    $ENV{PHEDEX_LOG_SQL} = ($1 eq 'on') if $insection;
	} else {
	    die "$self->{DBCONFIG}: $.: Unrecognised line\n";
	}
    }
    close (DBCONF);

    die "$self->{DBCONFIG}: database parameters not found\n"
	if (! $self->{DBH_DBITYPE} || ! $self->{DBH_DBNAME}
	    || ! $self->{DBH_DBUSER} || ! $self->{DBH_DBPASS});

    die "$self->{DBCONFIG}: role specified without username or password\n"
	if ($self->{DBH_DBROLE} && ! $self->{DBH_DBROLE_PASS});
}

# Create a connection to the transfer database.  Updates the agent's
# last contact, inserting the agent entries if necessary.  Takes one
# argument, the reference to the agent, which must have the standard
# database-related data members DBITYPE, DBNAME, DBUSER, DBPASS, and
# the TMDB node MYNODE.  The automatic identification is suppressed
# if a second optional argument is given and it's value is zero.
# Database connections are cached into $self->{DBH}.
sub connectToDatabase
{
    my ($self, $identify) = @_;

    # If we have database configuration file, read it
    &parseDatabaseInfo ($self) if ($self->{DBCONFIG} && ! $self->{DBH_DBNAME});

    # Use cached connection if it's still alive and the handle
    # isn't too old, otherwise create new one.
    my $dbh = $self->{DBH};
    if (! $self->{DBH}
	|| time() - $self->{DBH_AGE} > $self->{DBH_LIFE}
	|| ! eval { $self->{DBH}->ping() }
	|| $@)
    {
	$self->{DBH_LOGGING} = 1 if $ENV{PHEDEX_LOG_DB_CONNECTIONS};
	&logmsg ("(re)connecting to database") if $self->{DBH_LOGGING};

	# Clear previous connection.
	eval { $self->{DBH}->disconnect() } if $self->{DBH};
	undef $self->{DBH};

        # Start a new connection.
        $dbh = DBI->connect ("DBI:$self->{DBH_DBITYPE}:$self->{DBH_DBNAME}",
	    		     $self->{DBH_DBUSER}, $self->{DBH_DBPASS},
			     { RaiseError => 1,
			       AutoCommit => 0,
			       PrintError => 0 });
        return undef if ! $dbh;

	# Acquire role if one was specified.  Do not use &dbexec() here
	# as it will expose the password used in the logs.
	if ($self->{DBH_DBROLE})
	{
	    eval { $dbh->do ("set role $self->{DBH_DBROLE} identified by"
		             . " $self->{DBH_DBROLE_PASS}") };
	    die "failed to authenticate to $self->{DBH_DBNAME} as"
	        . " $self->{DBH_DBUSER} using role $self->{DBH_DBROLE}\n"
		if $@;
	}

	# Cache it.
	$self->{DBH_AGE} = time();
	$self->{DBH} = $dbh;
    }

    # Was identification suppressed?
    return $dbh if defined $identify && $identify == 0;

    # Make myself known.  If this fails, the database is probably
    # so wedged that we can't do anything useful, so bail out.
    eval
    {
	my $now = time();
	my $mynode = $self->{MYNODE};
	my $me = $self->{AGENTID} || $0; $me =~ s|.*/||;
	my $agent = &dbexec($dbh, qq{
	    select count(*) from t_agent where name = :me},
	    ":me" => $me)->fetchrow_arrayref();
	my $status = &dbexec($dbh, qq{
	    select count(*) from t_agent_status
	    where node = :node and agent = :me},
    	    ":node" => $mynode, ":me" => $me)
    	    ->fetchrow_arrayref();

	&dbexec($dbh, qq{insert into t_agent values (:me)}, ":me" => $me)
	    if ! $agent || ! $agent->[0];

	&dbexec($dbh, qq{
	    insert into t_agent_status (timestamp, node, agent, state)
	    values (:now, :node, :me, 1)},
	    ":now" => &mytimeofday(), ":node" => $mynode, ":me" => $me)
	    if ! $status || ! $status->[0];

	&dbexec($dbh, qq{
	    update t_agent_status set state = 1, timestamp = :now
	    where node = :node and agent = :me},
	    ":now" => &mytimeofday(), ":node" => $mynode, ":me" => $me);
	$dbh->commit();

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
	while (1)
	{
	    my $now = &mytimeofday ();
	    my ($time, $action, $keep) = (undef, 'CONTINUE', 0);
	    my $messages = &dbexec($dbh, qq{
	       select timestamp, message
	       from t_agent_message
	       where node = :node and agent = :me
	       order by timestamp asc},
	       ":node" => $mynode, ":me" => $me);
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
		      and (timestamp < :t or (timestamp = :t and message = :msg))},
	      	    ":node" => $mynode, ":me" => $me, ":t" => $t, ":msg" => $msg)
	            if ! $keep;
	    }

	    # Apply our changes.
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
    };

    if ($@)
    {
	&alert ("failed to update agent status: $@");
	eval { $dbh->rollback() };
	&disconnectFromDatabase ($self, $dbh, 1);
	return undef;
    }

    return $dbh;
}

# Disconnect from the database.  Normally this does nothing, as we
# cache the connection and try to keep it alive as long as we can
# without disturbing program robustness.  If $self->{DBH_CACHE} is
# defined and zero, connection caching is turned off.
sub disconnectFromDatabase
{
    my ($self, $dbh, $force) = @_;
    if ((exists $self->{DBH_CACHE} && ! $self->{DBH_CACHE}) || $force)
    {
	&logmsg ("disconnected from database") if $self->{DBH_LOGGING};
        eval { $dbh->disconnect() } if $dbh;
        undef $dbh;
        undef $self->{DBH};
        undef $self->{DBH_AGE};
    }
}

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
    return $dbh->prepare (&dbsql ($sql));
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
        my $sql = $stmt->{Statement};
	$sql =~ s/\s+/ /g; $sql =~ s/^\s+//; $sql =~ s/\s+$//;
	my $bound = join (", ", map { "($_, $params{$_})" } sort keys %params);
        &logmsg ("executing statement `$sql' [$bound]");
    }

    while (my ($param, $val) = each %params) {
	$stmt->bind_param ($param, $val);
    }

    return $stmt->execute();
}
