package PHEDEX::Custom::Castor::Migrate::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
	  	  NODES => undef,		# Nodes to operate for
		  PROTOCOLS => [ 'direct' ],	# Protocols to accept
		  WAITTIME => 150 + rand(50),	# Agent activity cycle
	  	  ME => "FileDownload");	# Identity for activity logs
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Pick up work.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    eval
    {
	# Automate portions of the hand shake so accounting reports
	# the right values.  The Buffer/MSS nodes are expected to be
	# shared in reality and this agent to be the only one making
	# transfers to the MSS.

	$dbh = $self->connectAgent();
	my @nodes = $self->expandNodes();
	my ($mynode, %myargs) = $self->myNodeFilter("xt.to_node");
	my $start = &mytimeofday();

	# Advertise myself available so file routing kicks in.
        &dbexec($dbh, qq{delete from t_xfer_sink xt where $mynode}, %myargs);
        &dbexec($dbh, qq{
            insert into t_xfer_sink (from_node, to_node, protocols, time_update)
            select xt.from_node, xt.to_node, :protos, :now from t_adm_link xt
            where $mynode},
            ":protos" => "@{$$self{PROTOCOLS}}", ":now" => $start, %myargs);

	# Auto-export from buffer to me and put them into transfer.
	&dbexec($dbh, qq{
	    insert all
	       into t_xfer_task_export values (id, :now)
	       into t_xfer_task_inxfer values (id, :now)
	    select xt.id from t_xfer_task xt
	    where $mynode
	      and not exists
	        (select 1 from t_xfer_task_export xte where xte.task = xt.id)},
	    ":now" => $start, %myargs);

	$dbh->commit();

	# Pick up work and process it.
        my $done = &dbprep ($dbh, qq{
	    insert into t_xfer_task_done
	    (task, report_code, xfer_code, time_xfer, time_update)
	    values (:task, 0, 0, :now, :now)});
	my $q = &dbexec($dbh, qq{
	    select
	      xt.id, n.name, f.filesize, f.logical_name,
	      xt.to_pfn, xt.time_assign
	    from t_xfer_task xt
	      join t_xfer_file f on f.id = xt.fileid
	      join t_adm_node n on n.id = xt.to_node
	    where $mynode
	      and not exists
	        (select 1 from t_xfer_task_done xtd where xtd.task = xt.id)
	    order by xt.time_assign asc, xt.rank asc}, %myargs);
	while (my ($task, $dest, $size, $lfn, $pfn, $available) = $q->fetchrow())
	{
	    # Check if the file has been migrated.  If not, skip it.
	    open (NSLS, "nsls -l $pfn |")
		or do { $self->Warn ("cannot nsls $pfn: $!"); next };
	    my $status = <NSLS>;
	    close (NSLS)
		or do { $self->Warn ("cannot nsls $pfn: $?"); next };

	    next if $status !~ /^m/;

	    # Migrated, mark transfer completed
	    my $now = &mytimeofday();
	    &dbbindexec($done, ":task" => $task, ":now" => $now);
	    $dbh->commit ();

	    # Log delay data.
    	    $self->Logmsg ("xstats: to_node=$dest time="
		     . sprintf('%.1fs', $now - $available)
		     . " size=$size lfn=$lfn pfn=$pfn");

	    # Give up if we've taken too long
	    last if $now - $start > 10*60;
	}
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

1;
