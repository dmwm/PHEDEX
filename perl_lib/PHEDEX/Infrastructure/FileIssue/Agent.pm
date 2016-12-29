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
    #
    # We also distinguish between a custodial task and a non-custodial
    # one.  Tasks may be custodial if the request is for custodial
    # storage and:
    #   1. The path hop is to the destination
    #   2. The path hop is to a local Buffer node of the destination
    # Otherwise the task is not custodial
    # 
    # Also, do not create tasks where a deletion is scheduled for
    # either the source or the destination node (or locally connected MSS nodes),
    # or an invalidation on the source node (or locally connected MSS),
    # in order to allow the deletion/invalidation to proceed.
    my $q = &dbexec($dbh, qq{
	select
          xp.fileid, f.inblock block_id, f.logical_name,
          xp.from_node, ns.name from_node_name, ns.kind from_kind,
          xr.id replica, xp.to_node, nd.name to_node_name,
	  xso.protocols from_protos, xsi.protocols to_protos,
          xp.priority, xp.is_local, xp.time_request, xp.time_expire,
          (case
            when xp.to_node = xp.destination
              or (l.is_local = 'y' and nd.kind = 'Buffer')
            then xrq.is_custodial
            else 'n' end
          ) is_custodial
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
            and (xd.node = ns.id or xd.node = nd.id)
          left join t_xfer_invalidate xi
            on xi.fileid = f.id
            and xi.node = ns.id
          left join (select xdmss.fileid,
                       ndbuf.id node
                     from t_xfer_delete xdmss
                       join t_adm_node ndmss
                       on ndmss.id=xdmss.node and ndmss.kind='MSS'
                       join t_adm_link lnmss
                       on lnmss.to_node=ndmss.id and lnmss.is_local='y'
                       join t_adm_node ndbuf
                       on lnmss.from_node=ndbuf.id and ndbuf.kind='Buffer'
                     ) xdbuf
            on xdbuf.fileid = f.id
            and (xdbuf.node = ns.id or xdbuf.node = nd.id)
	  left join (select ximss.fileid,
		       nibuf.id node
		     from t_xfer_invalidate ximss
		       join t_adm_node nimss
		       on nimss.id=ximss.node and nimss.kind='MSS'
		       join t_adm_link lnimss
		       on lnimss.to_node=nimss.id and lnimss.is_local='y'
		       join t_adm_node nibuf
		       on lnimss.from_node=nibuf.id and nibuf.kind='Buffer'
		     ) xibuf
	    on xibuf.fileid = f.id
            and xibuf.node = ns.id
          join t_xfer_request xrq
            on xp.fileid = xrq.fileid
            and xp.destination = xrq.destination
          left join t_adm_link l
            on l.to_node = xp.destination
            and l.from_node = xp.to_node
        where xp.is_valid = 1
          and xdr.id is null
          and xe.fileid is null
          and xt.id is null
          and xd.fileid is null
	  and xdbuf.fileid is null
          and xi.fileid is null
          and xibuf.fileid is null
	  and ((ns.kind = 'MSS' and nd.kind = 'Buffer')
	       or (ns.kind = 'Buffer' and nd.kind = 'MSS'
       	           and xsi.from_node is not null)
	       or (xso.from_node is not null
       	           and xsi.from_node is not null)) },
	":recent" => $now - 5400);

    while (! $finished)
    {
	$finished = 1;
        my @tasks;
	my %errors;
        while (my $task = $q->fetchrow_hashref())
        {
	    if ( $task->{FROM_KIND} eq 'MSS' )
	    {
		# Do nothing.  MSS->Buffer 'transfers' are completely faked.
	    } 
	    else 
	    {
		# Check that we can make a task.  If we can't do it
		# now the download agent isn't likely to be able to
		# either.
		$task->{FROM_NODE_ID} = $task->{FROM_NODE};
		$task->{TO_NODE_ID}   = $task->{TO_NODE};
		eval { $self->makeTransferTask($task, $cats); };
		if ($@) {
		    chomp $@;
		    $errors{$@} ||= 0;
		    $errors{$@}++;
		    next;
		}
	    }

	    push(@tasks, $task);
	    do { $finished = 0; last } if scalar @tasks >= 10_000;
        }

        my ($done, %did, %iargs) = 0;
        my $istmt = &dbprep($dbh, qq{
	    insert into t_xfer_task (id, fileid, from_replica, priority, rank,
	      from_node, to_node, time_expire, time_assign, is_custodial)
	    values (seq_xfer_task.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?)});

	# Determine rank.  This statement centrally determines the
	# order transfers.  Here we order transfers by:
	#   priority:      lower number is higher priority
	#   time_request:  older requests have priority.  this is important for T0->T1
	#   block_id:      we want to optimize for block completion
	#   TODO:  different ranking based on link?  (e.g.:  T1s different than T2s)
        foreach my $task (sort { $$a{PRIORITY} <=> $$b{PRIORITY}
				 || $$a{TIME_REQUEST} <=> $$b{TIME_REQUEST}
		                 || $$a{BLOCK_ID} <=> $$b{BLOCK_ID} }
		          @tasks)
        {
	    my $n = 1;
	    push(@{$iargs{$n++}}, $$task{FILEID});
	    push(@{$iargs{$n++}}, $$task{REPLICA});
	    push(@{$iargs{$n++}}, $$task{PRIORITY});
	    push(@{$iargs{$n++}}, $rank++);
	    push(@{$iargs{$n++}}, $$task{FROM_NODE});
	    push(@{$iargs{$n++}}, $$task{TO_NODE});
	    push(@{$iargs{$n++}}, $$task{TIME_EXPIRE});
	    push(@{$iargs{$n++}}, $now);
	    push(@{$iargs{$n++}}, $$task{IS_CUSTODIAL});
	    $did{$$task{TO_NODE_NAME}} = 1;
	    $done++;
        }

        &dbbindexec($istmt, %iargs) if %iargs;
        $dbh->commit();

	# report error summary
	foreach my $err (keys %errors) {
	    $self->Alert ("'$err' occurred for $errors{$err} tasks" );
	    delete $errors{$err};
	}

	$self->Logmsg ("issued $done transfers to the destinations"
		 . " @{[sort keys %did]}") if $done;
	$alldone += $done;

	$self->maybeStop();
    }

    $self->Logmsg ("no transfer tasks to issue") if ! $alldone;
}

1;

=pod

=head1 NAME

FileIssue - create transfer tasks for site agents

=head1 DESCRIPTION

FileIssue creates transfer tasks based on the transfer paths created
by the FileRouter.  Tasks are basically a signal to the destination
download agent that they should initiate a transfer of a file from
some source destination.  Tasks are only created over "active" links
where the source node has a FileExport agent running and the
destination node has a FileDownload agent running.

=head1 TABLES USED

=over

=item L<t_xfer_task|Schema::OracleCoreTransfer/t_xfer_task)>

This agent creates transfer tasks.

=item L<t_xfer_path|Schema::OracleCoreTransfer/t_xfer_path)>

Tasks are created where a valid hop exists.

=item L<t_xfer_replica|Schema::OracleCoreTransfer/t_xfer_replica)>

Tasks are created only when replica at the source node of the hop.

=item L<t_xfer_exclude|Schema::OracleCoreTransfer/t_xfer_exclude)>

Tasks are *not* created when a row in the exclude table exists.

=item L<t_xfer_delete|Schema::OracleCoreTransfer/t_xfer_delete)>

Tasks are *not* created when the source replica is queued for
deletion.

=item L<t_xfer_source|Schema::OracleCoreTransfer/t_xfer_source)>

Tasks are created only when an export agent is running at the source
end of a link.

=item L<t_xfer_sink|Schema::OracleCoreTransfer/t_xfer_sink)>

Tasks are created only when a download agent is running on the
destination end of a link.

=back



=head1 COOPERATING AGENTS

=over

=item L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>

This agent only creates tasks according to the transfer paths created
by FileRouter.

=item L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>

Tasks are only created when a replica exists at the source end of a
hop.  FilePump is responsible for identifying finished or expired
tasks, and deleting them.  For tasks which complete successfully,
FilePump creates a replica at the to_node of the task.

=item L<FileExport|PHEDEX::File::Export::Agent>

A node must have a FileExport agent running for it before tasks will
be made from that node.

=item L<FileDownload|PHEDEX::File::Download::Agent>

A node must have a FileDownload agent running for it before tasks will
be made to that node.  FileDownload is responsible for executing
transfer tasks.

=item L<FileMSSMigrate|PHEDEX::File::MSSMigrate::Agent>

Another kind of FileDownload agent, but working for Buffer->MSS links.

=back



=head1 STATISTICS

=over

=item L<t_status_task|Schema::OracleCoreStatus/t_status_task>

Contains current per-link file and byte sums for tasks, grouped by the state
of the task.

=item L<t_history_link_stats|Schema::OracleCoreStatus/t_history_link_stats>

Contains a history of per-link file and byte sums for tasks in the
pend_files and pend_bytes columns.

=item L<t_history_link_events|Schema::OracleCoreStatus/t_history_link_events>

Contains a history of the times that tasks entered various states.

=back



=head1 SEE ALSO

=over

=item L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>

=item L<PHEDEX::Core::Catalogue|PHEDEX::Core::Catalogue>

=back

=cut
