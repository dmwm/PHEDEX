package UtilsDB; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(connectToDatabase disconnectFromDatabase dbexec dbprep dbbindexec);
use UtilsLogging;
use UtilsTiming;
use DBI;

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

    # Use cached connection if it's still alive and the handle
    # isn't too old, otherwise create new one.
    my $dbh = $self->{DBH};
    if (! $self->{DBH}
	|| time() - ($self->{DBH_AGE} || 0) > 86400
	|| ! eval { $self->{DBH}->ping() }
	|| $@)
    {
	$self->{DBH_LOGGING} = 1 if $ENV{PHEDEX_LOG_DB_CONNECTIONS};
	&logmsg ("(re)connecting to database") if $self->{DBH_LOGGING};

	# Clear previous connection.
	eval { $self->{DBH}->disconnect() } if $self->{DBH};
	undef $self->{DBH};

        # Start a new connection.
        $dbh = DBI->connect ("DBI:$self->{DBITYPE}:$self->{DBNAME}",
	    		     $self->{DBUSER}, $self->{DBPASS},
			     { RaiseError => 1, AutoCommit => 0 });
        return undef if ! $dbh;

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
    };

    if ($@)
    {
	&alert ("failed to update agent status: $@");
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
        $dbh->disconnect() if $dbh;
        undef $dbh;
        undef $self->{DBH};
        undef $self->{DBH_AGE};
    }
}

# Simple utility to prepare a SQL statement
sub dbprep
{
    my ($dbh, $sql) = @_;
    return $dbh->prepare ($sql);
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

    while (my ($param, $val) = each %params) {
	$stmt->bind_param ($param, $val);
    }

    if ($ENV{PHEDEX_LOG_SQL})
    {
        my $sql = $stmt->{Statement};
	$sql =~ s/\s+/ /g; $sql =~ s/^\s+//; $sql =~ s/\s+$//;
	my $bound = join (", ", map { "($_, $params{$_})" } sort keys %params);
        &logmsg ("executing statement `$sql' [$bound]");
    }

    return $stmt->execute();
}
