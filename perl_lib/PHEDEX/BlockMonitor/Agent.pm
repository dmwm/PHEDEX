package PHEDEX::BlockMonitor::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE    => undef,           # my TMDB nodename
    	  DBCONFIG  => undef,		# Database configuration file
	  WAITTIME  => 120 + rand(30),	# Agent cycle time
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(%params,@_);
  $self->{LAST}{BLOCK_UPDATE} = 0;

  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub limitCheck
{
  my ($self,$reason, $b, $ref) = @_;
  $ref ||= $b;
  $reason = "$reason $b->{BLOCK} at node $b->{NODE}";

  $self->Alert("$reason destined $b->{DEST_FILES} files,"
            . " more than expected ($ref->{FILES})")
	if $b->{DEST_FILES} > $ref->{FILES};
  $self->Alert("$reason destined $b->{DEST_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{DEST_BYTES} > $ref->{BYTES};
  $self->Alert("$reason originated $b->{SRC_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{SRC_FILES} > $ref->{FILES};
  $self->Alert("$reason originated $b->{SRC_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{SRC_BYTES} > $ref->{BYTES};
  $self->Alert("$reason has $b->{NODE_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{NODE_FILES} > $ref->{FILES};
  $self->Alert("$reason has $b->{NODE_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{NODE_BYTES} > $ref->{BYTES};
  $self->Alert("$reason transferring $b->{XFER_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{XFER_FILES} > $ref->{FILES};
  $self->Alert("$reason transferring $b->{XFER_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{XFER_BYTES} > $ref->{BYTES};
}

# Update statistics.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;

    eval
    {
	$dbh = $self->connectAgent();
	my $now = &mytimeofday ();

	# The general strategy below is:
	#   I. Select block replica quantities from the active source
	#   table, inserting them into a temporary table.  Only write
	#   rows into the temporary tables where an update or
	#   insertion into t_dps_block_replica is necessary. In most
	#   cases, if the "active" table has null rows, and the
	#   block_replica table has non-zero rows, then the
	#   block_replica table needs to be "zeroed".  This is why
	#   most queries below are a FULL JOIN instead of a simple
	#   inner join or LEFT JOIN.
	#  II. Merge the "diff tables" from Part I into t_dps_block_replica.
	# III. Merge the "flags" into t_dps_block_replica; flags may
	# change even for inactive blocks.
	#  IV. Delete "empty source" block replicas -- those with no
	#  replicas or subscription or transfers.

	# Part I:  Get a consitent snapshot of block replica statistics

	# We use the existing state of the block replica table as the
	# basis for our updates To maintain consistency, we must
	# ensure this table does not change during our transaction,
	# especially the "is_active" flag.
	#
	# Note: This agent *must* run in a short amount of time (less
	# than a minute) or this agressive lock will block all other
	# agents working on this table (BlockActivate,
	# BlockDeactivate).  If performance becomes a problem, it may
	# be better to move Activation, Deactivation, and Monitoring
	# into a single agent.
	&dbexec ($dbh, qq{lock table t_dps_block_replica in exclusive mode});

	# Using Oracle flashback queries allows us to work safely in
	# the immutable past instead of in the constantly-changing
	# present. For reads on all tables involved in obtaining block
	# replica statistics, we specify the system change number
	# (scn) which specifies the point in time at which we are
	# interested in observing the table. Other processes are
	# therefore free to make changes to these tables while we
	# compile the statistics, and we are freed from locking issues
	# and inconsistent reads.
	#
	# Note: serializable transactions are how we used to achieve
	# this, but eventually the large number of ORA-08177 made this
	# unworkable.

	my $scn = &select_scalar($dbh, q{select dbms_flashback.get_system_change_number() from dual});
	my @rv;
	my ($t1, $t2) = (&mytimeofday(), undef);

	# Note which blocks are active, as for most of the statisitcs
	# below updates are only to be made for active blocks.
	@rv = &dbexec ($dbh, qq{
	    insert into t_tmp_br_active
	    (block)
	    select b.id
              from t_dps_block as of scn :scn b 
              join t_xfer_file as of scn :scn xf 
                on xf.inblock = b.id
             group by b.id, b.files
            having count(xf.id) = b.files
	    }, ':scn' => $scn);
	$t2 = &mytimeofday();
	$self->Logmsg("got active snapshot for $rv[1] blocks ", sprintf('%.3fs', $t2-$t1));

	# src_files/bytes: number of files from a block which were
	# generated at the given node.  This comes from the main file
	# table, t_dps_file. We don't expect that these quantities
	# change without also setting t_dps_block.time_udpate.
	# Inserts and deletes on t_dps_file should handle this with a
	# trigger, BUT updating a file's size or bytes, or moving its
	# creation node is not handled.  We don't need to check for
	# null rows in the 'act' table because that would indicate
	# that the whole block was removed, at which point there
	# should no longer be a block replica either.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec ($dbh,  qq{
	    insert into t_tmp_br_src
            (block, node, files, bytes, time_update)
	    select act.block, act.node,
                   act.src_files, act.src_bytes,
	           act.time_update
              from (select f.inblock block, f.node,
	                   count(f.id)     src_files,
		           sum(f.filesize) src_bytes,
                           max(f.time_create) time_update
	              from t_dps_block as of scn :scn b
                      join t_dps_file as of scn :scn f
                        on f.inblock = b.id
                     where b.time_update > :block_update
                     group by f.inblock, f.node
	           ) act
	      left join t_dps_block_replica as of scn :scn br
	             on br.block = act.block and br.node = act.node
	     where act.src_files != nvl(br.src_files,0)
                or act.src_bytes != nvl(br.src_bytes,0)
	 }, ':scn' => $scn, ':block_update' => $self->{LAST}{BLOCK_UPDATE});
	$t2 = &mytimeofday();
	$self->Logmsg("got src snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# dest_files/bytes: number of files from a block subscribed to
	# the given node. This may change for inactive blocks,
	# e.g. when a node removes their subscription to delete files.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec ($dbh, qq{
	    insert into t_tmp_br_dest
	    (block, node, files, bytes, time_update)
	    select nvl(act.block,br.block), nvl(act.node,br.node),
                   nvl(act.dest_files,0), nvl(act.dest_bytes,0),
	           nvl(act.time_update,:now)
	      from (select b.id block, s.destination node,
		           b.files dest_files,
		           b.bytes dest_bytes,
		           s.time_create time_update
      		      from t_dps_subs_block as of scn :scn s
      		      join t_dps_block as of scn :scn b 
                        on b.id = s.block
	           ) act
	 full join t_dps_block_replica as of scn :scn br
	        on br.block = act.block and br.node = act.node
	   where nvl(act.dest_files,0) != nvl(br.dest_files,0)
              or nvl(act.dest_bytes,0) != nvl(br.dest_bytes,0)
	    }, ':scn' => $scn, ':now' => $now);
	$t2 = &mytimeofday();
	$self->Logmsg("got dest snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# node_files/bytes: number of files from a block actually at
	# the given node. This may ONLY change for active blocks. For
	# inactive blocks, this becomes the only record that the
	# blocks exist at the node, so its proper maintenance is very
	# important.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec ($dbh, qq{ 
	    insert into t_tmp_br_node
            (block, node, files, bytes, time_update)
	    select nvl(act.block,br.block), nvl(act.node,br.node),
                   nvl(act.node_files,0), nvl(act.node_bytes,0),
	           nvl(act.time_update,:now)
	    from t_tmp_br_active ba
            join (select f.inblock block, xr.node,
		         count(xr.fileid) node_files,
		         sum(f.filesize)  node_bytes,
                         max(xr.time_create) time_update
      	            from t_xfer_replica as of scn :scn xr
	            join t_xfer_file as of scn :scn f 
                      on f.id = xr.fileid 
                   group by f.inblock, xr.node
	         ) act on act.block = ba.block
	    full join (t_dps_block_replica as of scn :scn br
                       join t_tmp_br_active ba on ba.block = br.block)
	           on br.block = act.block and br.node = act.node
           where nvl(act.node_files,0) != nvl(br.node_files,0)
              or nvl(act.node_bytes,0) != nvl(br.node_bytes,0)
	}, ':scn' => $scn, ':now' => $now);
	$t2 = &mytimeofday();
	$self->Logmsg("got node snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# xfer_files/bytes: number of files in a block which are
	# currently queued for transfer to a given node. This can ONLY
	# change for active blocks, and should be zero for inactive
	# blocks.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec ($dbh, qq{ 
	    insert into t_tmp_br_xfer
            (block, node, files, bytes, time_update)
	    select nvl(act.block,br.block), nvl(act.node,br.node),
                   nvl(act.xfer_files,0), nvl(act.xfer_bytes,0),
	           nvl(act.time_update,:now)
	    from t_tmp_br_active ba
	    join (select f.inblock block, xt.to_node node,
		         count(xt.fileid) xfer_files,
		         sum(f.filesize)  xfer_bytes,
                         max(xt.time_assign) time_update
      	            from t_xfer_task as of scn :scn xt
	            join t_xfer_file as of scn :scn f
                      on f.id = xt.fileid 
                   group by f.inblock, xt.to_node
	         ) act on act.block = ba.block
	    full join (t_dps_block_replica as of scn :scn br
                       join t_tmp_br_active ba on ba.block = br.block)
	           on br.block = act.block and br.node = act.node
           where nvl(act.xfer_files,0) != nvl(br.xfer_files,0)
              or nvl(act.xfer_bytes,0) != nvl(br.xfer_bytes,0)
       },  ':scn' => $scn, ':now' => $now);
	$t2 = &mytimeofday();
	$self->Logmsg("got xfer snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# flags: classifications for the block replicas. These can
	# change for inactive blocks.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec ($dbh, qq{
	    insert into t_tmp_br_flag
	    (block, node, is_custodial, user_group, time_update)
	    select nvl(act.block,br.block), nvl(act.node,br.node),
                   nvl(act.is_custodial,'n'), act.user_group,
	           nvl(act.time_update,:now)
	    from (
	    select b.id block, s.destination node,
	           sp.is_custodial, sp.user_group,
		   s.time_create time_update
      		from t_dps_subs_block as of scn :scn s
		join t_dps_subs_param as of scn :scn sp
		     on s.param=sp.id
		join t_dps_block as of scn :scn b 
                     on b.id = s.block
	    ) act
	    full join t_dps_block_replica as of scn :scn br
	      on act.block = br.block and act.node = br.node
           where nvl(act.is_custodial,'n') != nvl(br.is_custodial,'n')
              or nvl(act.user_group,-1)    != nvl(br.user_group,-1)
	    }, ':scn' => $scn, ':now' => $now);
	$t2 = &mytimeofday();
	$self->Logmsg("got flag snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# Part II: merge statistics into t_dps_block_replica summary table.
	my @parts = qw(src dest node xfer);
	my @quantities = qw(files bytes);
	foreach my $part (@parts) {
	    # build the insert string
	    my (@cols, @vals);
	    foreach my $p (@parts) {
		foreach my $q (@quantities) {
		    push @cols, "${p}_${q}";
		    if ($p eq $part) { push @vals, "act.${q}"; }
		    else             { push @vals, 0; }
		}
	    }
	    my $insert_cols = join ', ', @cols;
	    my $insert_vals = join ', ', @vals;

	    # quantities which may only update if the block is active
	    my @active_only = qw(node xfer);
	    my $active_where = grep($part eq $_, @active_only) ? "where br.is_active = 'y'" : '';

	    ($t1, $t2) = ($t2, undef);
	    @rv = &dbexec ($dbh, qq{
		merge into t_dps_block_replica br
		using (
                  select p.block, p.node, p.files, p.bytes, p.time_update, nvl2(ba.block,'y','n') active
		    from t_tmp_br_${part} p
		    left join t_tmp_br_active ba on ba.block = p.block
                 ) act on (act.block = br.block and act.node = br.node)
                when matched then
                update set 
                  br.${part}_files = act.files,
                  br.${part}_bytes = act.bytes,
	          br.time_update   = greatest(br.time_update,act.time_update)
		$active_where
                when not matched then
	        insert (block, node, is_active,
			$insert_cols,
			is_custodial, user_group,
			time_create, time_update)
		 values (act.block, act.node, act.active,
			 $insert_vals,
			 'n', NULL,
			 act.time_update, act.time_update)
	     });
	    $t2 = &mytimeofday();
	    $self->Logmsg("merged $part snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));
	}

	# Part III: merge flags into block replicas
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec($dbh, qq{
	    merge into t_dps_block_replica br
	    using (
	      select block, node, is_custodial, user_group, time_update
	        from t_tmp_br_flag
	    ) flag on (br.block = flag.block and br.node = flag.node)
	    when matched then
	    update set br.is_custodial = flag.is_custodial,
	               br.user_group   = flag.user_group,
	               br.time_update  = greatest(br.time_update,flag.time_update)
	 });
	$t2 = &mytimeofday();
	$self->Logmsg("merged flags snapshot for $rv[1] block replicas in ", sprintf('%.3fs', $t2-$t1));

	# Part IV: delete empty block replicas. Nobody is interested
	# in where a block was generated (src_files) if there are no
	# replicas or subscription.
	($t1, $t2) = ($t2, undef);
	@rv = &dbexec($dbh, qq{
	    delete from t_dps_block_replica where dest_files = 0 and node_files = 0 and xfer_files = 0
	 });
	$t2 = &mytimeofday();
	$self->Logmsg("deleted $rv[1] empty block replicas in ", sprintf('%.3fs', $t2-$t1));

	# Sanity checking. We do a basic check that none of the
	# quantiies we've collected are greater than what should be
	# possible. For efficiency, we put the limit check into the
	# selection criteria, then print out warnings for those that
	# match. Ideally the query returns zero rows.
	my @limits;
	foreach my $p (@parts) {
	    foreach my $q (@quantities) {
		push @limits, "br.${p}_${q} > b.${q}";
	    }
	}
	my $where = join ' or ', @limits;
	($t1, $t2) = ($t2, undef);
	my $q = &dbexec($dbh,
	    qq { select br.block, br.node,
		        br.is_active, b.files, b.bytes, b.is_open,
			br.dest_files, br.dest_bytes,
			br.src_files, br.src_bytes,
			br.node_files, br.node_bytes,
			br.xfer_files, br.xfer_bytes,
			br.is_custodial, br.user_group
		   from t_dps_block_replica br
                   join t_dps_block as of scn :scn b 
		     on b.id = br.block
		  where $where
	       }, ':scn' => $scn);
	my $n = 0;
	while (my $br = $q->fetchrow_hashref()) {
	    $n++;
	    $self->limitCheck("block", $br);
	}
	$t2 = &mytimeofday();
	$self->Logmsg("sanity checked $n block replicas in ", sprintf('%.3fs', $t2-$t1));

	# Get the most recently updated block to use for the selection filter in the next round
	my $last_block_update = 
	    &select_scalar($dbh, qq{ select max(time_update) 
				      from t_dps_block as of scn :scn }, 
			   ':scn' => $scn);

	# We can finally commit
	$self->execute_commit();

	# Save the update time. We do this after the commit to ensure
	# we don't miss anything in the next round if the commit failed.
	$self->{LAST}{BLOCK_UPDATE} = $last_block_update;
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $self->execute_rollback() } if $dbh } if $@;

    # Disconnect from the database.
    $self->disconnectAgent();
}

1;
