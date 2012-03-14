/*

=pod

=head1 NAME

Status - PhEDEx snapshot and historical statics, and logs

=head1 DESCRIPTION

Status tables come in three general types: snapshot tables, history
tables, and log tables.

Snapshot tables begin with C<t_status_> and describe some aspect of
the system at a single point in time, which is approximately the
present.  These tables are used to efficiently present aggregate
statistics to the user, for example via the web site.

History tables begin with C<t_history_> and contain time-ordered
statistics which should be saved forever.  These tables are used to
generate time-based plots of system, node, or link behavior.

Snapshot and history tables contain data-anonymous statistics.  They
describe counts of files or bytes, but not which files, blocks, or
datasets the statistics refer to.

Log table begin with C<t_log_> and contain more detailed statistics
that are identified by some data item as well as a timestamp.  Both
time-ordered and snapshot-type data can be derieved from these.

=head1 TABLES

=head2 t_history_link_events

This history table stores per-link file and byte counts for various
transfer I<events>.  The events occur at a single point in time, and
the statistics of events are aggregated into variable-width bins
C<timewidth> wide.

When comparing the columns in these tables, it is important to only
compare columns which share the same event time, and the only ones
that do this are the done_, fail_ and expire_ columns.  For example,
it makes no sense to derive done_bytes / try_bytes for the same
timebin, because the quantites do not represent events on the same
files!

Because these data come from distinct events, they can be aggregated
over time to produce a sum over a longer time period.

=over

=item t_history_link_events.timebin

Bin timestamp, see L<here|Schema::Schema/Timestamp Columns>.

=item t_history_link_events.timewidth

Width of the bin histogram bin in seconds.

=item t_history_link_events.from_node

Source node of the event, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_history_link_events.to_node

Destination node of the event, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_history_link_events.priority

Priority of the transfer, see 
L<here|Schema::Schema/priority (Link-level)>.

=item t_history_link_events.avail_files

Number of files that became available for transfer (were exported) in
this timebin.

=item t_history_link_events.avail_bytes

Number of files that became available for transfer (were exported) in
this timebin.

=item t_history_link_events.done_files

Number of files which finished transfer successfully within this
timebin.

=item t_history_link_events.done_bytes

Number of bytes which finished transfer successfully within this
timebin.

=item t_history_link_events.try_files

Number of files which which began transfer within this timebin.

=item t_history_link_events.try_bytes

Number of bytes which which began transfer within this timebin.

=item t_history_link_events.fail_files

Number of files which finished transfer unsuccessfully within this
timebin. 

=item t_history_link_events.fail_bytes

Number of bytes which finished transfer unsuccessfully within this
timebin. 

=item t_history_link_events.expire_files

Number of files which finished transfer by expiring within this
timebin.

=item t_history_link_events.expire_bytes

Number of bytes which finished transfer by expiring within this
timebin.

=back

=cut

*/

/* FIXME: Consider using compressed table here, see Tom Kyte's
   Effective Oracle By Design, chapter 7.  See also the same chapter,
   "Compress Auditing or Transaction History" for swapping partitions.
   Also test if index-organised table is good. Also, look into making
   the history tables range partitioned on their timestamp. */

create table t_history_link_events
  (timebin		float		not null,
   timewidth		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   -- statistics for timebin period from t_xfer_task
   avail_files		integer, -- became available
   avail_bytes		integer,
   done_files		integer, -- successfully transferred
   done_bytes		integer,
   try_files		integer, -- attempts
   try_bytes		integer,
   fail_files		integer, -- attempts that errored out
   fail_bytes		integer,
   expire_files		integer, -- attempts that expired
   expire_bytes		integer,
   --
   constraint pk_history_link_events
     primary key (timebin, to_node, from_node, priority),
   --
   constraint fk_history_link_events_from
     foreign key (from_node) references t_adm_node (id),
   --
   constraint fk_history_link_events_to
     foreign key (to_node) references t_adm_node (id)
  );

/*

=pod

=head2 t_history_link_stats

This history table contains per-link file and byte counts for various
I<sampled> quantities in the database.  The data here are read
periodically from the current system state in a "heartbeat" fashion.
Most of these data represent some per-link queue.

Because these data are sampled, it makes no sense to aggregate
sums of them in order to represent behavior over a longer time
period.  The data may be averaged over a longer time period, or a
representative bin may be selected for the whole period.

=over

=item t_history_link_stats.timebin

Bin timestamp, see L<here|Schema::Schema/Timestamp Columns>.

=item t_history_link_stats.timewidth

Width of the bin histogram bin in seconds.

=item t_history_link_stats.from_node

Source node of the queue, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_history_link_stats.to_node

Destination node of the queue, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_history_link_stats.priority

Priority of the queue, see 
L<here|Schema::Schema/priority (Link-level)>.

=item t_history_link_stats.pend_files

Number of files pending transfer during this timebin.

=item t_history_link_stats.pend_bytes

Number of bytes pending transfer during this timebin.

=item t_history_link_stats.wait_files

Number of files pending transfer and waiting for the source replica to
be exported.

=item t_history_link_stats.wait_bytes

Number of bytes pending transfer and waiting for the source replica to
be exported.

=item t_history_link_stats.cool_files

B<WARNING: OBSOLETE!>  Number of files purposefully being delayed from
transfer at this time.

=item t_history_link_stats.cool_bytes

B<WARNING: OBSOLETE!>  Number of bytes purposefully being delayed from
transfer at this time.

=item t_history_link_stats.ready_files

Number of files pending transfer and exported at the source node.

=item t_history_link_stats.ready_bytes

Number of bytes pending transfer and exported at the source node.

=item t_history_link_stats.xfer_files

Number of files pending transfer and queued by the destination node.

=item t_history_link_stats.xfer_bytes

Number of bytes pending transfer and queued by the destination node.

=item t_history_link_stats.confirm_files

Number of files routed over this link.

=item t_history_link_stats.confirm_bytes

Number of bytes routed over this link.

=item t_history_link_stats.confirm_weight

B<WARNING: OBSOLETE!>  Average cost of the files routed over this
link.

=item t_history_link_stats.param_rate

Transfer rate over this link used by
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> 
during this timebin.

=item t_history_link_stats.param_latency

Transfer latency (time to transfer all files in queue) over this link
used by L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> during
this timebin.

=back

=cut

*/

create table t_history_link_stats
  (timebin		float		not null,
   timewidth		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   --
   -- statistics for t_xfer_state during/at end of this timebin
   pend_files		integer, -- all tasks
   pend_bytes		integer,
   wait_files		integer, -- tasks not exported
   wait_bytes		integer,
   cool_files		integer, -- cooling off (in error) (obsolete)
   cool_bytes		integer,
   ready_files		integer, -- exported, available for transfer
   ready_bytes		integer,
   xfer_files		integer, -- taken for transfer
   xfer_bytes		integer,
   --
   -- statistics for t_xfer_path during/at end of this bin
   confirm_files	integer, -- t_xfer_path
   confirm_bytes	integer,
   confirm_weight	integer,
   -- 
   -- statistics from t_link_param calculated at the end of this cycle
   param_rate		float,
   param_latency	float,
   --
   constraint pk_history_link_stats
     primary key (timebin, to_node, from_node, priority),
   --
   constraint fk_history_link_stats_from
     foreign key (from_node) references t_adm_node (id),
   --
   constraint fk_history_link_stats_to
     foreign key (to_node) references t_adm_node (id)
  );

/*

=pod

=head2 t_history_dest

This history table contains per-node file and byte counts for various
I<sampled> quantities in the database.  The data here are read
periodically from the current system state in a "heartbeat" fashion.

Because these data are sampled, it makes no sense to aggregate
sums of them in order to represent behavior over a longer time
period.  The data may be averaged over a longer time period, or a
representative bin may be selected for the whole period.

=over

=item t_history_link_stats.timebin

Bin timestamp, see L<here|Schema::Schema/Timestamp Columns>.

=item t_history_link_stats.timewidth

Width of the bin histogram bin in seconds.

=item t_history_link_stats.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_history_dest.dest_files

Number of files subscribed to this node in this timebin.

=item t_history_dest.dest_bytes

Number of bytes subscribed to this node in this timbin.

=item t_history_dest.cust_dest_files

Number of custodial files subscribed to this node in this timebin.

=item t_history_dest.cust_dest_bytes

Number of custodial bytes subscribed to this node in this timebin.

=item t_history_dest.src_files

Total number of files which this node has generated until this
timebin.

=item t_history_dest.src_bytes

Total number of bytes which this node has generated until this
timebin.

=item t_history_dest.node_files

Number of files resident at this node during this timebin.

=item t_history_dest.node_bytes

Number of bytes resident at this node during this timebin.

=item t_history_dest.cust_node_files

Number of custodial files resident at this node during this timebin.

=item t_history_dest.cust_node_bytes

Number of custodial bytes resident at this node during this timebin.

=item t_history_dest.miss_files

Number of subscribed files to this node which are not resident at this
node during this timebin.

=item t_history_dest.miss_bytes

Number of subscribed bytes to this node which are not resident at this
node during this timebin.

=item t_history_dest.cust_miss_files

Number of custodial subscribed files to this node which are not
resident at this node during this timebin.

=item t_history_dest.cust_miss_bytes

Number of custodial subscribed bytes to this node which are not
resident at this node during this timebin.

=item t_history_dest.request_files

Number of files which have an active request for routing during this
timebin.

=item t_history_dest.request_bytes

Number of bytes which have an active request for routing during this
timebin.

=item t_history_dest.idle_files

Number of files which have an inactive request for routing during this
timebin.

=item t_history_dest.idle_bytes

Number of bytes which have an inactive request for routing during this
timebin.

=back

=cut

*/

/* TODO: Use another identifyer column 'is_custodial' to split
custodial/non-custodial values instead of separate columns. Allow to
be null for values where custodiality does not apply. request_ and
idle_ *do* have a custodial status */

create table t_history_dest
  (timebin		float		not null,
   timewidth		float		not null,
   node			integer		not null,
   dest_files		integer, -- t_status_block_dest
   dest_bytes		integer,
   cust_dest_files	integer, -- t_status_block_dest
   cust_dest_bytes	integer,
   src_files		integer, -- t_status_file
   src_bytes		integer,
   node_files		integer, -- t_status_replica
   node_bytes		integer,
   cust_node_files	integer, -- t_status_replica
   cust_node_bytes	integer,
   miss_files		integer, -- t_status_missing
   miss_bytes		integer,
   cust_miss_files	integer, -- t_status_missing
   cust_miss_bytes	integer,
   request_files	integer, -- t_status_request
   request_bytes	integer,
   idle_files		integer, -- t_status_request
   idle_bytes		integer,
   --
   constraint pk_history_dest
     primary key (timebin, node),
   --
   constraint fk_history_dest_node
     foreign key (node) references t_adm_node (id)
  );

/*

=pod

=head2 t_status_block_dest

This status table contains the current per-node file and byte counts
for "destined" (subscribed) blocks to node, broken down by their
custodial status and state.  The data is collected from
L<t_dps_block_dest|Schema::OracleCoreBlock/t_dps_block_dest>.

=over

=item t_status_block_dest.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_status_block_dest.destination

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_dest.is_custodial

Whether the subscription was custododial.

=item t_status_block_dest.state

Integer state of the block destination, see
L<t_dps_block_dest.state|Schema::OracleCoreBlock/t_dps_block_dest.state>.

=item t_status_block_dest.files

Number of files subscribed to the destination.

=item t_status_block_dest.bytes

Number of bytes subscribed to the destination.

=back

=cut

*/

create table t_status_block_dest
  (time_update		float		not null,
   destination		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_block_dest
     primary key (destination, is_custodial, state),
   --
   constraint fk_status_block_dest_node
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_status_block_dest_cust
     check (is_custodial in ('y', 'n'))
  );

/*

=pod

=head2 t_status_file

This status table contains the per-node file and byte counts for files
which were generated at the node.

=over

=item t_statust_file.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_file.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_statust_file.files

Total number of files generated at the node.

=item t_statust_file.bytes

Total number of bytes generated at the node.

=back

=cut

*/

create table t_status_file
  (time_update		float		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_file
     primary key (node),
   --
   constraint fk_status_file_node
     foreign key (node) references t_adm_node (id)
     on delete cascade
  );


/*

=pod

=head2 t_status_replica

This status table contains the file and byte counts for files resident
at the nodes.

=over

=item t_statust_replica.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_replica.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_replica.is_custodial

Whether the files are custodial copies of the data.

=item t_status_replica.state

B<WARNING: UNUSED/OBSOLETE!> Always set to 0.

=item t_status_replica.files

Number of files resident at the node.

=item t_status_replica.bytes

Number of bytes resident at the node.

=back

=cut

*/

create table t_status_replica
  (time_update		float		not null,
   node			integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_replica
     primary key (node, is_custodial, state),
   --
   constraint fk_status_replica_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_status_replica_cust
     check (is_custodial in ('y', 'n'))
  );

/*

=pod

=head2 t_status_missing

This status table contains file and byte counts for the amount of data
which is subscribed to a node but not resident there.

=over

=item t_statust_missing.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_missing.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_missing.is_custodial

Whether the subscriptions are for custodial copies of the data.

=item t_status_missing.files

Number of files subscribed to the node but not resident there.

=item t_status_missing.bytes

Number of bytes subscribed to the node but not resident there.

=back

=cut

*/

create table t_status_missing
  (time_update		float		not null,
   node			integer		not null,
   is_custodial		char (1)	not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_missing
     primary key (node, is_custodial),
   --
   constraint fk_status_missing_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_status_missing_cust
     check (is_custodial in ('y', 'n'))
  );

/*

=pod

=head2 t_status_request

This status table contains file and byte counts for requests for
transfer -- files allocated by the
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> for routing.
This data is aggregated from 
L<t_xfer_request|Schema::OracleCoreTransfer/t_xfer_request>.

=over

=item t_statust_request.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_request.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_request.priority

Priority of the queue, see 
L<Schema::Schema/priority (Node-level)>.

=item t_status_request.is_custodial

Whether the requests are for custodial copies of the data.

=item t_status_request.state

The request state, see
L<t_xfer_request.state|Schema::OracleCoreTransfer/t_xfer_request.state>.

=item t_status_request.files

Number of files requested for transfer.

=item t_status_request.bytes

Number of bytes requested for transfer.

=back

=cut

*/

 create table t_status_request
  (time_update		float		not null,
   destination		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_request
     primary key (destination, priority, is_custodial, state),
   --
   constraint fk_status_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_status_request_cust
     check (is_custodial in ('y', 'n'))
  );

/*

=pod

=head2 t_status_group

This status table contains file and byte counts for data subscribed
and resident per group.  This data is aggregated from
L<t_dps_block_replica|Schema::OracleCoreBlock/t_status_block_replica>.

=over

=item t_statust_request.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_request.node

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_group.group

Group, FK to
L<t_adm_group.id|Schema::OracleCoreAdm/t_adm_group.id>.

=item t_status_group.dest_files

Number of files subscribed to the node for this group.

=item t_status_group.dest_bytes

Number of bytes subscribed to the node for this group.

=item t_status_group.node_files

Number of files resident at the node for this group.

=item t_status_group.node_bytes

Number of bytes resident at the node for this group.

=back

=cut

*/

 create table t_status_group
  (time_update		float		not null,
   node			integer		not null,
   user_group		integer,
   dest_files		integer		not null, -- approved files for this group
   dest_bytes		integer		not null,
   node_files		integer		not null, -- acheived files for this group
   node_bytes		integer		not null,
   --
   constraint uk_status_group
     unique (node, user_group),
   --
   constraint fk_status_group_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_group_group
     foreign key (user_group) references t_adm_group (id)
     on delete set null
  );

/*

=pod

=head2 t_status_dataset_arrive

B<WARNING: FUTURE/UNUSED!>  This status table contains a prediction of
when a subscribed dataset will arrive at a node.  The values are
aggregated from L<t_status_block_arrive>.

=over

=item t_statust_dataset_arrive.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_statust_dataset_arrive.destination

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_dataset_arrive.dataset

Dataset, FK to
L<t_dps_dataset.id|Schema::OracleCoreBlock/t_dps_dataset.id>.

=item t_status_dataset_arrive.blocks

Number of blocks in the dataset.

=item t_status_dataset_arrive.files

Number of files in the datatset.

=item t_status_dataset_arrive.bytes

Number of bytes in the dataset.

=item t_status_dataset_arrive.avg_priority

The average priority of blocks in the dataset.

=item t_status_dataset_arrive.basis

The technique used to arrive at the estimate. Values are taken from
block estimate, and the value for this dataset will be the value of
the worst (least informed) block basis.  For example, if even one
block is suspended, the basis is 's', if even one block is using
nominal estimate, the basis is 'n'.

See L<t_status_block_arrive.basis>.

=item t_status_dataset_arrive.time_span

Maximum duration in seconds of the history period that was analyzed when
making this estimate.

=item t_status_dataset_arrive.pend_bytes

Maximum queue size in bytes used in this estimation.

=item t_status_dataset_arrive.xfer_rate

Minimum transfer rate used in this estimation.

=item t_status_dataset_arrive.time_arrive

The time this dataset is expected to arrive.  Equivilent to the
latest predicted arriaval time of a block in this dataset.

=back

=cut

*/

create table t_status_dataset_arrive
  (time_update		float		not null,
   destination		integer		not null,
   dataset		integer		not null,
   blocks		integer		not null, -- number of blocks in the dataset during this estimate
   files		integer		not null, -- number of files in the dataset during this estimate
   bytes		integer		not null, -- number of bytes in the dataset during this estimate
   avg_priority		float		not null, -- average block priority
   basis		char(1)		not null, -- basis of estimate, see above
   time_span		float		        , -- max historical vision used in a block estimate
   pend_bytes		float		        , -- max queue size in bytes used in a block estimate
   xfer_rate		float		        , -- min transfer rate used in a block estimate
   time_arrive		float		        , -- worst time predicted that a block will arrive
   --
   constraint pk_status_dataset_arrive
     primary key (destination, dataset),
   --
   constraint fk_status_dataset_arrive_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_dataset_arrive_ds
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade
  );

/*

=pod

=head2 t_status_block_arrive

This status table contains a prediction of
when a subscribed block will arrive at a node.

=over

=item t_status_block_arrive.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_status_block_arrive.destination

Node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_arrive.block

Block, FK to
L<t_dps_block.id|Schema::OracleCoreBlock/t_dps_block.id>.

=item t_status_block_arrive.files

Number of files in the block.

=item t_status_block_arrive.bytes

Number of bytes in the block.

=item t_status_block_arrive.priority

L<Priority|Schema::Schema/priority (Node-level)> of the subscription.

=item t_status_block_arrive.basis

The technique used to arrive at the estimate. If no estimate can be given,
or the block will never arrive, the reason for the missing estimate.

Negative values are for blocks which are not expected to complete without
external intervention.
Non-negative values are for blocks which are expected to complete.

 -6 : at least one file in the block has no source replica remaining
 -5 : for at least one file in the block, there is no path from source to destination
 -4 : subscription was automatically suspended by router for too many failures
 -3 : there is no active download link to the destination
 -2 : subscription was manually suspended
 -1 : block is still open
  0 : all files in the block are currently routed. FileRouter estimate is used.
  1 : the block is not yet routed because the destination queue is full.
	Estimate will be calculated from queue statistics in t_history_dest
  2 : at least one file in the block is currently not routed, because it recently failed to transfer.

=item t_status_block_arrive.time_span

B<WARNING: FUTURE/UNUSED!> Duration in seconds of the history period that was analyzed when
making this estimate, for basis=1 blocks.

=item t_status_block_arrive.pend_bytes

B<WARNING: FUTURE/UNUSED!> Pending transfer queue in bytes used in this estimation, for basis=1 blocks.

=item t_status_block_arrive.xfer_rate

B<WARNING: FUTURE/UNUSED!> Transfer rate used in this estimation, for basis=1 blocks.

=item t_status_block_arrive.time_arrive

Time this block is predicted to arrive.

=back

=cut

*/

create table t_status_block_arrive
  (time_update		float		not null,
   destination		integer		not null,
   block		integer		not null,
   files		integer		not null, -- number of files in the block during this estimate
   bytes		integer		not null, -- number of bytes in the block during this estimate
   priority		integer		not null, -- t_dps_block_dest priority
   basis		integer		not null, -- basis of estimate, see above
   time_span		float		        , -- historical vision used in estimate
   pend_bytes		float		        , -- queue size in bytes used in estimate
   xfer_rate		float		        , -- transfer rate used in estimate
   time_arrive		float		        , -- time predicted this block will arrive
   --
   constraint pk_status_block_arrive
     primary key (destination, block),
   --
   constraint fk_status_block_arrive_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_block_arrive_block
     foreign key (block) references t_dps_block (id)
     on delete cascade
  );

/*

=pod

=head2 t_status_block_request

This status table contains file and byte counts for requests for
transfer -- files allocated by the
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> for routing.
This data is aggregated by block and destination node from 
L<t_xfer_request|Schema::OracleCoreTransfer/t_xfer_request>.

=over

=item t_status_block_request.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_status_block_request.destination

Destination node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_request.block

Block ID, FK to
L<t_dps_block.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_request.priority

Priority of the queue, see 
L<Schema::Schema/priority (Node-level)>.

=item t_status_block_request.is_custodial

Whether the requests are for custodial copies of the data.

=item t_status_block_request.state

The request state, see
L<t_xfer_request.state|Schema::OracleCoreTransfer/t_xfer_request.state>.

=item t_status_block_request.request_files

Number of files requested for transfer.

=item t_status_block_request.request_bytes

Number of bytes requested for transfer.

=item t_status_block_request.xfer_attempts

Total number of transfer attempts for all file requests for this block.

=item t_status_block_request.time_request

L<Time|Schema::Schema/Timestamp Columns> when the first request for a file
in this block was created.

=back

=cut

*/

 create table t_status_block_request
  (time_update		float		not null,
   destination		integer		not null,
   block		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   request_files	integer		not null,
   request_bytes	integer		not null,
   xfer_attempts	integer		not null,
   time_request		integer		not null,
   --
   constraint pk_status_block_request
     primary key (destination, block, priority, is_custodial, state),
   --
   constraint fk_status_block_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_block_request_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint ck_status_block_request_cust
     check (is_custodial in ('y', 'n'))
  );

 create index ix_status_block_request_dest
  on t_status_block_request (destination);

 create index ix_status_block_request_block
  on t_status_block_request (block);

/* Statistics for blocks being routed . */
create table t_status_block_path
  (time_update		float		not null,
   destination		integer		not null,
   src_node		integer		not null,
   block		integer		not null,
   priority		integer		not null, -- t_xfer_path priority
   is_valid		integer		not null, -- t_xfer_path is_valid
   route_files		integer		not null, -- routed files
   route_bytes		integer		not null, -- routed bytes
   xfer_attempts	integer		not null, -- xfer attempts of routed
   time_request		integer		not null, -- min (oldest) request time of routed
   time_arrive		float		not null, -- max predicted arrival time estimated by router
   --
   constraint pk_status_block_path
     primary key (destination, src_node, block, priority, is_valid),
   --
   constraint fk_status_block_path_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_block_path_src
     foreign key (src_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_block_path_block
     foreign key (block) references t_dps_block (id)
     on delete cascade
  );

/* Statistics for transfer paths.
 * t_status_path.priority:
 *   same as t_xfer_path, see OracleCoreTransfers
 */
create table t_status_path
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   is_valid		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_path
     primary key (from_node, to_node, priority, is_valid),
   --
   constraint fk_status_path_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_path_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade
  );

/* Statistics for transfer tasks.
 *
 * t_status_task.priority:
 *   same as for t_xfer_task, see OrackeCoreTransfer
 *
 * t_status_task.state:
 *   0 = waiting for transfer
 *   1 = exported
 *   2 = in transfer
 *   3 = finished transfer
*/
create table t_status_task
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_task
     primary key (from_node, to_node, priority, is_custodial, state),
   --
   constraint fk_status_task_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_task_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_status_task_cust
     check (is_custodial in ('y', 'n'))
  );


/* File size statistics (histogram + overview). */
create table t_status_file_size_overview
  (time_update		float		not null,
   n_files		integer		not null,
   sz_total		integer		not null,
   sz_min		integer		not null,
   sz_max		integer		not null,
   sz_mean		integer		not null,
   sz_median		integer		not null
  );

create table t_status_file_size_histogram
  (time_update		float		not null,
   bin_low		integer		not null,
   bin_width		integer		not null,
   n_total		integer		not null,
   sz_total		integer		not null
  );

create table t_log_dataset_latency
  (time_update		float		not null,
   destination		integer		not null,
   dataset		integer			, -- dataset id, can be null if dataset remvoed
   blocks		integer	        not null, -- number of blocks
   files		integer		not null, -- number of files
   bytes		integer		not null, -- size in bytes
   avg_priority		float		not null, -- average priority of blocks
   time_subscription	float		not null, -- min time a block was subscribed
   first_block_create	float		not null, -- min time a block was created
   last_block_create	float		not null, -- max time a block was created
   first_block_close	float		    	, -- min time a block was closed
   last_block_close	float			, -- max time a block was closed
   first_request	float			, -- min time a block was first routed
   first_replica	float			, -- min time the first file of a block was replicated
   last_replica		float			, -- max time the last file of a block was replicated
   latency		float			, -- current latency for this dataset
   serial_suspend       float                   , -- sum of all block suspend times
   serial_latency	float			, -- sum of all block latencies for this dataset
   --
   constraint fk_status_dataset_latency_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint fk_status_block_latency_ds
     foreign key (dataset) references t_dps_dataset (id)
     on delete set null);

/* Log for user actions - lifecycle of data at a node
   actions:  0 - request data
             1 - subscribe data
             3 - delete data
*/
create table t_log_user_action
  (time_update		float		not null,
   action		integer		not null,
   identity		integer		not null,
   node			integer		not null,
   dataset		integer,
   block		integer,
   --
   constraint uk_status_user_action
     unique (time_update, action, identity, node, dataset, block),
   --
   constraint fk_status_user_action_identity
     foreign key (identity) references t_adm_identity (id),
   --
   constraint fk_status_user_action_node
     foreign key (node) references t_adm_node (id),
   --
   constraint fk_status_user_action_dataset
     foreign key (dataset) references t_dps_dataset (id),
   --
   constraint fk_status_user_action_block
     foreign key (block) references t_dps_block (id),
   --
   constraint ck_status_user_action_ref
     check (not     (block is null and dataset is null)
            and not (block is not null and dataset is not null))
  );
  
  
   

----------------------------------------------------------------------
-- Create indices

create index ix_history_link_events_from
  on t_history_link_events (from_node);

create index ix_history_link_events_to
  on t_history_link_events (to_node);
--
create index ix_history_link_stats_from
  on t_history_link_stats (from_node);

create index ix_history_link_stats_to
  on t_history_link_stats (to_node);
--
create index ix_history_dest_node
  on t_history_dest (node);
--
create index ix_status_task_to
  on t_status_task (to_node);
--
create index ix_status_path_to
  on t_status_path (to_node);
--
create index ix_status_group_group
  on t_status_group (user_group);
--
create index ix_log_user_action_identity
  on t_log_user_action (identity);

create index ix_log_user_action_node
  on t_log_user_action (node);

create index ix_log_user_action_dataset
  on t_log_user_action (dataset);

create index ix_log_user_action_block
  on t_log_user_action (block);
--
create index ix_status_block_path_src
  on t_status_block_path (src_node);

create index ix_status_block_path_block
  on t_status_block_path (block);
