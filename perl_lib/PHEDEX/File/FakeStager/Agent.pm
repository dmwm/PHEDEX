package PHEDEX::File::FakeStager::Agent;
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
	  	  NODES => undef,		# Nodes this agent runs for
		  WAITTIME => 60 + rand(15),	# Agent cycle time
		  ME => "FileStager");	# Identity for activity logs
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Pick up stage-in
# assignments and map current stager state back to the database.
sub idle
{
    my ($self, @pending) = @_;

    my $dbh = undef;
    eval
    {
	my @nodes;
	$dbh = $self->connectAgent();
	@nodes = $self->expandNodes();
        my ($mynodes, %myargs) = $self->myNodeFilter("xr.node");

        # Mark as staged everything requiring export.
        my $stmt = &dbexec($dbh, qq{
	    update t_xfer_replica xr
	    set state = 1, time_state = :now
	    where state = 0 and $mynodes and exists
	      (select 1 from t_xfer_task xt
	       where xt.from_node = xr.node
		 and xt.fileid = xr.fileid)},
	    ":now" => &mytimeofday(), %myargs);

	$dbh->commit();
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

1;
