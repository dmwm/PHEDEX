package PHEDEX::Monitoring::InfoStatesClean::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging', 'PHEDEX::BlockLatency::SQL';
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
	    	  MYNODE => undef,		# TMDB node name
	          WAITTIME => 300, 		# Agent activity cycle
		  ME => 'InfoStatesClean',
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
	my $now = &mytimeofday();

	# Delete obsolete agent status messages (3 days)
	my %old = (":old" => &mytimeofday() - 3*86400);
	&dbexec($dbh,qq{delete from t_agent_status where time_update < :old}, %old);
	&dbexec($dbh,qq{delete from t_agent_log where time_update < :old},
		":old" => &mytimeofday() - 30*86400);

	# Keep 100 most recent errors for every link
	&dbexec($dbh, qq{
	   delete from t_xfer_error xe where rowid not in
	     (select rowid from
	      (select rowid, row_number()
		over (partition by from_node, to_node order by time_done desc) rank
	       from t_xfer_error)
	      where rank <= 100)});

	# Archive completed block latency information
	my @mergeLogStats=$self->mergeLogBlockLatency();
	$self->Dbgmsg("Merged block-level latency logs: "
                  .join(', ', map { $_->[1] + 0 .' '.$_->[0] } @mergeLogStats));
	# Clean up file-level latency entries for blocks completed more than 30 days ago
	my @cleanLogStats=$self->cleanLogFileLatency();
	$self->Dbgmsg("Cleaned file-level latency logs: "
                  .join(', ', map { $_->[1] + 0 .' '.$_->[0] } @cleanLogStats));
	
	$dbh->commit();

    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

1;
