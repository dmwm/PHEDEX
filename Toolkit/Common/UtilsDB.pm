package UtilsDB; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(connectToDatabase);
use DBI;

# Create a connection to the transfer database.  Updates the agent's
# last contact, inserting the agent entries if necessary.  Takes one
# argument, the reference to the agent, which must have the standard
# database-related data members DBITYPE, DBNAME, DBUSER, DBPASS, and
# the TMDB node MYNODE.  The automatic identification is suppressed
# if a second optional argument is given and it's value is zero.
sub connectToDatabase
{
    my ($self, $identify) = @_;

    # Connect to the database.
    my $dbh = DBI->connect ("DBI:$self->{DBITYPE}:$self->{DBNAME}",
	    		    $self->{DBUSER}, $self->{DBPASS},
			    { RaiseError => 1, AutoCommit => 0 });
    return undef if ! $dbh;

    # Was identification suppressed?
    return $dbh if defined $identify && $identify == 0;

    # Make myself known.  If this fails, the database is probably
    # so wedged that we can't do anything useful, so bail out.
    eval
    {
	my $now = time();
	my $mynode = $self->{MYNODE};
	my $me = $0; $me =~ s|.*/||;
	my $agent = $dbh->selectcol_arrayref(qq{
		select count(*) from t_agents where name = '$me'});
	my $status = $dbh->selectcol_arrayref(qq{
		select count(*) from t_lookup where node = '$mynode' and agent = '$me'});

	$dbh->do(qq{insert into t_agents values ('$me')})
	    if ! $agent || ! $agent->[0];

	$dbh->do(qq{insert into t_lookup values ('$mynode', '$me', 1, $now)})
	    if ! $status || ! $status->[0];

	$dbh->do(qq{
		update t_lookup
		set state = 1, last_contact = $now
		where node = '$mynode' and agent = '$me'});
	$dbh->commit();
    };

    if ($@)
    {
	&alert ("failed to update agent status: $@");
	$dbh->disconnect();
	undef $dbh;
	return undef;
    }

    return $dbh;
}
