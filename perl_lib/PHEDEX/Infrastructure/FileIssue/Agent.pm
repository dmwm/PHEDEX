package PHEDEX::Infrastructure::FileIssue::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use List::Util qw(max);
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My node name
		  WAITTIME => 60 + rand(10),
		  ME	   => 'FileIssue',
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
	@nodes = $self->expandNodes({ "FileDownload" => 5400 });

	# Route files.
	$self->confirm($dbh);
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

# Confirm transfers for all nodes.
sub confirm
{
    my ($self, $dbh) = @_;
    my $now = &mytimeofday();
    my $cats = {};
    my $finished = 0;
    my $alldone = 0;
    my $rank = 0;

    # Confirm transfers on valid hop destinations where the source
    # replica exists, but not the destination nor is there transfer.
    # Read link parameter information in the same go.  "Valid" hop
    # destinations include those where there is a live download
    # agent at the destination and an export agent at the source,
    # or specific combinations we always handle automatically.
    my $q = &dbexec($dbh, qq{
	select
          xp.fileid, f.logical_name,
          xp.from_node, ns.name from_node_name, ns.kind from_kind,
          xr.id replica, xp.to_node, nd.name to_node_name,
	  xso.protocols from_protos, xsi.protocols to_protos,
          xp.priority, xp.is_local, xp.time_expire
        from t_xfer_path xp
          join t_xfer_replica xr
            on xr.fileid = xp.fileid
            and xr.node = xp.from_node
          left join t_xfer_replica xdr
            on xdr.fileid = xp.fileid
            and xdr.node = xp.to_node
          join t_adm_node ns
            on ns.id = xp.from_node
	  join t_adm_node nd
	    on nd.id = xp.to_node
          left join t_xfer_exclude xe
            on xe.from_node = ns.id
            and xe.to_node = nd.id
            and xe.fileid = xp.fileid
          left join t_xfer_task xt
            on xt.fileid = xp.fileid
            and xt.to_node = xp.to_node
          join t_xfer_file f
            on f.id = xp.fileid
	  left join t_adm_link_param p
	    on p.from_node = xp.from_node
	    and p.to_node = xp.to_node
	  left join t_xfer_source xso
	    on xso.from_node = ns.id
	    and xso.to_node = nd.id
	    and xso.time_update >= :recent
	  left join t_xfer_sink xsi
	    on xsi.from_node = ns.id
	    and xsi.to_node = nd.id
	    and xsi.time_update >= :recent
	  left join t_xfer_delete xd
	    on xd.fileid = f.id
            and xd.node = ns.id
            and xd.time_complete is null
        where xp.is_valid = 1
          and xdr.id is null
          and xe.fileid is null
          and xt.id is null
          and xd.fileid is null
	  and ((ns.kind = 'MSS' and nd.kind = 'Buffer')
	       or (ns.kind = 'Buffer' and nd.kind = 'MSS'
       	           and xsi.from_node is not null)
	       or (xso.from_node is not null
       	           and xsi.from_node is not null))
	 /* order by priority asc, time_expire asc */ },
	":recent" => $now - 5400);

    while (! $finished)
    {
	$finished = 1;
        my @tasks;
        while (my $task = $q->fetchrow_hashref())
        {
	    $$task{PRIORITY} = 2*$$task{PRIORITY} + (1-$$task{IS_LOCAL});
	    $self->makeTransferTask($dbh, $task, $cats);
	    push(@tasks, $task);
	    do { $finished = 0; last } if scalar @tasks >= 10_000;
        }

        my ($done, %did, %iargs) = 0;
        my $istmt = &dbprep($dbh, qq{
	    insert into t_xfer_task (id, fileid, from_replica, priority, rank,
	      from_node, to_node, from_pfn, to_pfn, time_expire, time_assign)
	    values (seq_xfer_task.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)});
        foreach my $task (sort { $$a{PRIORITY} <=> $$b{PRIORITY}
		                 || $$a{LOGICAL_NAME} cmp $$b{LOGICAL_NAME} }
		          @tasks)
        {
	    my $n = 1;
	    next if ! $$task{FROM_PFN};
	    next if ! $$task{TO_PFN};
	    push(@{$iargs{$n++}}, $$task{FILEID});
	    push(@{$iargs{$n++}}, $$task{REPLICA});
	    push(@{$iargs{$n++}}, $$task{PRIORITY});
	    push(@{$iargs{$n++}}, $rank++);
	    push(@{$iargs{$n++}}, $$task{FROM_NODE});
	    push(@{$iargs{$n++}}, $$task{TO_NODE});
	    push(@{$iargs{$n++}}, $$task{FROM_PFN});
	    push(@{$iargs{$n++}}, $$task{TO_PFN});
	    push(@{$iargs{$n++}}, $$task{TIME_EXPIRE});
	    push(@{$iargs{$n++}}, $now);
	    $did{$$task{TO_NODE_NAME}} = 1;
	    $done++;
        }

        &dbbindexec($istmt, %iargs) if %iargs;
        $dbh->commit();

	$self->Logmsg ("issued $done transfers to the destinations"
		 . " @{[sort keys %did]}") if $done;
	$alldone += $done;

	$self->maybeStop();
    }

    $self->Logmsg ("no transfer tasks to issue") if ! $alldone;
}

# Expand transfer task information and insert into the database.
sub makeTransferTask
{
    my ($self, $dbh, $task, $cats) = @_;
    my ($from, $to) = @$task{"FROM_NODE", "TO_NODE"};
    my ($from_name, $to_name) = @$task{"FROM_NODE_NAME", "TO_NODE_NAME"};
    my @from_protos = split(/\s+/, $$task{FROM_PROTOS} || '');
    my @to_protos   = split(/\s+/, $$task{TO_PROTOS} || '');

    eval
    {
	my $from_cat    = &dbStorageRules($dbh, $cats, $from);
	my $to_cat      = &dbStorageRules($dbh, $cats, $to);
    };
    do { chomp ($@); $self->Alert ("catalogue error: $@"); return; } if $@;

    my $protocol    = undef;

    # Find matching protocol.
    foreach my $p (@to_protos)
    {
	next if ! grep($_ eq $p, @from_protos);
	$protocol = $p;
	last;
    }

    # If this is MSS->Buffer transition, pretend we have a protocol.
    $protocol = 'srm' if ! $protocol && $$task{FROM_KIND} eq 'MSS';
    
    # Check that we have prerequisite information to expand the file names.
    return if (! $from_cat
	       || ! $to_cat
	       || ! $protocol
	       || ! $$from_cat{$protocol}
	       || ! $$to_cat{$protocol});

    # Try to expand the file name. Follow destination-match instead of remote-match
    $$task{FROM_PFN} = &applyStorageRules($from_cat, $protocol, $to_name, 'pre', $$task{LOGICAL_NAME});
    $$task{TO_PFN}   = &applyStorageRules($to_cat, $protocol, $to_name, 'pre', $$task{LOGICAL_NAME});
}



1;
