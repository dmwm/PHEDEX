package PHEDEX::File::MSSMigrate::Agent;
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
		  MSSBACKEND => 'fake',         # MSS backend
		  CHECKROUTINE => '',           # check file in MSS routine
		  RETRANSFERLOST => '',         # whether to mark lost files for re-xfer 
		  WAITTIME => 150 + rand(50),	# Agent activity cycle
	  	  ME => "FileDownload",		# Identity for activity logs
		  CATALOGUE => {},		# TFC cache
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;

    bless $self, $class;

    $self->loadcheckroutine(); 

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

	my @nodes;
	$dbh = $self->connectAgent();
	@nodes = $self->expandNodes();
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
	    insert into t_xfer_task_export (task, time_update)
	    select xt.id, :now from t_xfer_task xt
	    where $mynode
	      and not exists
	        (select 1 from t_xfer_task_export xte where xte.task = xt.id)},
	    ":now" => $start, %myargs);

#	&dbexec($dbh, qq{
#	    insert into t_xfer_task_inxfer (task, time_update)
#	    select xt.id, :now from t_xfer_task xt
#	    where $mynode
#	      and not exists
#	        (select 1 from t_xfer_task_inxfer xti where xti.task = xt.id)},
#	    ":now" => $start, %myargs);
	my $q1 = &dbexec($dbh, qq{
	    select xt.id, xt.from_node, xt.to_node, logical_name, is_custodial
	     from t_xfer_task xt join t_dps_file f on xt.fileid = f.id
	    where $mynode
	      and not exists
	        (select 1 from t_xfer_task_inxfer xti where xti.task = xt.id)},
		%myargs );
	while (my $task = $q1->fetchrow_hashref())
        {
#	  $self->Logmsg('untested code ahead: ',join(', ', map { "$_=$task->{$_}" } sort keys %{$task}));
	  my $h = $self->makeTransferTask
		(
			{
			  FROM_NODE_ID	=> $task->{FROM_NODE},
			  TO_NODE_ID	=> $task->{TO_NODE},
			  FROM_PROTOS	=> $self->{PROTOCOLS},
			  TO_PROTOS	=> $self->{PROTOCOLS},
			  LOGICAL_NAME	=> $task->{LOGICAL_NAME},
			  IS_CUSTODIAL	=> $task->{IS_CUSTODIAL},
			},
			$self->{CATALOGUE},
		);
#	  $self->Logmsg('untested code: makeTransfer ',join(', ', map { "$_=$h->{$_} "} sort keys %{$h}));
	  &dbexec($dbh, qq{
	    insert into t_xfer_task_inxfer (task, time_update, from_pfn, to_pfn, space_token)
	    values (:task, :time_update, :from_pfn, :to_pfn, :space_token) },
	    ":task"	   => $task->{ID},
	    ":time_update" => $start,
	    ":from_pfn"    => $h->{FROM_PFN},
	    ":to_pfn"      => $h->{TO_PFN},
	    ":space_token" => $h->{TO_TOKEN}
	    );
	}

	$dbh->commit();

	# Pick up work and process it.
        my $done = &dbprep ($dbh, qq{
	    insert into t_xfer_task_done
	    (task, report_code, xfer_code, time_xfer, time_update)
	    values (:task, 0, 0, :now, :now)});
# I used to do this...
#	my $q = &dbexec($dbh, qq{
#	    select
#	      xt.id, n.name, f.filesize, f.logical_name,
#	      xt.time_assign, xt.is_custodial,
#	      xt.from_node, xt.to_node
#	    from t_xfer_task xt
#	      join t_xfer_file f on f.id = xt.fileid
#	      join t_adm_node n on n.id = xt.to_node
#	    where $mynode
#	      and not exists
#	        (select 1 from t_xfer_task_done xtd where xtd.task = xt.id)
#	    order by xt.time_assign asc, xt.rank asc}, %myargs);
# but nos I avoid the join on t_adm_node...
	my $q = &dbexec($dbh, qq{
	    select
	      xt.id, f.filesize, f.logical_name,
	      xt.time_assign, xt.is_custodial,
	      xt.from_node, xt.to_node
	    from t_xfer_task xt
	      join t_xfer_file f on f.id = xt.fileid
	    where $mynode
	      and not exists
	        (select 1 from t_xfer_task_done xtd where xtd.task = xt.id)
	    order by xt.time_assign asc, xt.rank asc}, %myargs);
# ...and don't put $dest into the array-read here...
#	while (my ($task, $dest, $size, $lfn, $available, $is_custodial,
#		   $from_node, $to_node) = $q->fetchrow())
# ...because I get it for free later.
	while (my ($task, $size, $lfn, $available, $is_custodial,
		   $from_node, $to_node) = $q->fetchrow())
	{
	    my $h = $self->makeTransferTask
		(
			{
			  FROM_NODE_ID	=> $from_node,
			  TO_NODE_ID	=> $to_node,
			  FROM_PROTOS	=> $self->{PROTOCOLS},
			  TO_PROTOS	=> $self->{PROTOCOLS},
			  LOGICAL_NAME	=> $lfn,
			  IS_CUSTODIAL	=> $is_custodial,
			},
			$self->{CATALOGUE},
		);
#	    A strict sanity check, should not be needed but who knows...
            foreach ( qw / FROM_PFN TO_PFN FROM_NODE TO_NODE / )
            {
              if ( !defined($h->{$_}) )
              {
                $self->Fatal('No $_ in task: ',join(', ',map { "$_=$h->{$_}" } sort keys %{$h}));
              }
            }
	    my $dest = $h->{TO_NODE};
            my $pfn= $h->{TO_PFN};
	    $self->Logmsg("Checking pfn $pfn");
	    
	    my $status = &checkFileInMSS($pfn);
	    
	    if ($status == 0) {
		$self->Logmsg ("Not yet migrated: $pfn"); next;
	    }
	    elsif ($status == -1) {
		$self->Logmsg ("File reported lost: $pfn"); 
		$self->markForRetransfer($lfn) if ($self->{RETRANSFERLOST}); 
		next;
	    }
	    
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

sub markForRetransfer {
    my ($self,$lfn) = @_;
    $self->Logmsg ("Marking for retransfer: $lfn");
}

sub loadcheckroutine {
    my $self = shift;


    undef &checkFileInMSS;

    if ($$self{CHECKROUTINE}) {
        require $$self{CHECKROUTINE};
    }
    elsif ($$self{MSSBACKEND} eq 'srm'){
	$self->Logmsg("Loading SRM backend routine");
	*checkFileInMSS = \&checkFileInMSS_SRM;
    }
    elsif ($$self{MSSBACKEND} eq 'castor'){
	$self->Logmsg("Loading Castor backend routine");
	*checkFileInMSS = \&checkFileInMSS_castor;
    }
    elsif ($$self{MSSBACKEND} eq 'dcache') {
	#as in original FiledCacheMigrate agent
	my $subr = join "",(<DATA>);
        eval $subr;
    }
    elsif ($$self{MSSBACKEND} eq 'fake')  {
        $self->Logmsg("Loading fake backend routine");
        *checkFileInMSS = \&checkFileInMSS_fake;
    }
    elsif ($$self{MSSBACKEND}) {
	die "Unknown -mssbackend specified\n"; 
    }
    else {
	#This is not required at this point, but..
	$self->Logmsg("Loading fake backend routine afterall");
        *checkFileInMSS = \&checkFileInMSS_fake;
    }

    die "Finished loadcheckroutine(), but somehow no checkFileInMSS routine defined\n" 
	unless defined &checkFileInMSS;
}


# This is a fake backend - always returns  successful migration status
sub checkFileInMSS_fake {
    return 1
}

# Castor Migration routine
sub checkFileInMSS_castor {
    my $pfn = shift @_;
    my $migrated = 0;
    open (NSLS, "nsls -l $pfn |")
	or do { warn ("cannot nsls $pfn: $!"); return 0 };
    my $status = <NSLS>;
    close (NSLS)
	or do { warn ("cannot nsls $pfn: $?"); return 0 };

    $migrated = 1 if ($status =~ /^m/);
    return $migrated;
}


# SRM migration routine, as in original FileSRMMigrate
# This is not a proper way to check for migration
sub checkFileInMSS_SRM {
    my $pfn = shift @_;

    my $migrated = 0;
            open (SRM, "srm-get-metadata -retry_num=1 $pfn |")
                or do { warn ("no metadata for $pfn: $!"); return 0 };

    while(<SRM>) {
	if (/isPermanent :true/) {
	    $migrated = 1;
	}
    }

    close (SRM)
	or do { warn ("no migration info for $pfn: $?"); return 0 };

    return $migrated
}

1;

#Below is an embedded example of a file with checking subroutine,
#from original FiledCacheMigrate agent 
#For your custom subroutine, create a file in your config dir, 
#fill it with your code for &checkFileInMSS and call this agent with
# -checkroutine ${PHEDEX_CONFIG}/$your_file.pl

__DATA__
    print "Loading default checkFileInMSS...\n";
sub checkFileInMSS {
    my $pfn = shift @_;
    
# Get the path and the filename
    my ($path, $filename) = ($pfn =~ m!(.*)/(.*)!);

    # Check if the file has been migrated.  If not, skip it.
    open (DCACHE, "$path/.(use)(1)($filename)")
	or do { warn ("no migration info for $pfn: $!"); return 0 };
    
    my $status = <DCACHE>;
    
    close (DCACHE)
	or do { warn ("no migration info for $pfn: $?"); return 0 };
    
    return $status?1:0 ;
	
}

1;
