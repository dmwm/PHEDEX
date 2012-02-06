/*
=pod

=head1 NAME

Block - tables defining and using the file-block concept

=head1 DESCRIPTION

These tables define the concept of the file-block, which is a
collection of files, and how they are organized into datasets, which
are collections of blocks.  Other block-level tables which are used
for transfer workflow bookkeeping are also defined here.

=head1 TABLES

=head2 t_dps_dbs

Defines a DBS endpoint, which is responsible for bookkeeping datasets
and blocks.  Filled by L<data injections|PHEDEX::Core::Inject>.

=over

=item t_dps_dbs.id

=item t_dps_dbs.name

Name of the DBS (Dataset Bookkeeping Service).  Typically the full URI
to the service endpoint, but technically an arbitrary string.

=item t_dps_dbs.dls

Name of the associated DLS (Data Location Service).  Essentially
obsolete, the convention is to set the value to "dbs" to signify that
the DBS itself functions as the DLS.

=item t_dps_dbs.time_create

=back

=cut

*/
create table t_dps_dbs
  (id			integer		not null,
   name			varchar (1000)	not null,
   dls			varchar (1000)	not null,
   time_create		float		not null,
   --
   constraint pk_dps_dbs
     primary key (id),
   --
   constraint uq_dps_dbs_name
     unique (name));

create sequence seq_dps_dbs;

/*
=pod

=head2 t_dps_dataset

Defines a dataset, a collection of blocks.  Filled by L<data injections|PHEDEX::Core::Inject>.

=over

=item t_dps_dataset.id

=item t_dps_dataset.dbs

The DBS this dataset is associated with.

=item t_dps_dataset.name

Name of the dataset.  Typically in the form /PRIMARY/PROCESSED/TIER.

=item t_dps_dataset.is_open

Whether or not more blocks can be added to this dataset.  Datasets may
be reopened after they are closed.

=item t_dps_dataset.is_transient

OBSOLETE.  Whether or not we can forget about this dataset once all
transfers have been made.

=item t_dps_dataset.time_create

=item t_dps_dataset.time_update

=back

=cut

*/
create table t_dps_dataset
  (id			integer		not null,
   dbs			integer		not null,
   name			varchar (1000)	not null,
--   blocks		integer		not null,
--   files		integer		not null,
--   bytes		integer		not null,
   is_open		char (1)	not null,
   is_transient		char (1)	not null,
   time_create		float		not null,
   time_update		float,
   --
   constraint pk_dps_dataset
     primary key (id),
   --
   constraint uq_dps_dataset_key
     unique (dbs, name),
   --
   constraint fk_dps_dataset_dbs
     foreign key (dbs) references t_dps_dbs (id),
   --
   constraint ck_dps_dataset_open
     check (is_open in ('y', 'n')),
   --
   constraint ck_dps_dataset_transient
     check (is_transient in ('y', 'n')));

create sequence seq_dps_dataset;

/*
=pod

=head2 t_dps_block

Defines blocks, which are collections of files and the minimum unit of
transfer managed by PhEDEx.  Filled by L<data injections|PHEDEX::Core::Inject>.

=over

=item t_dps_block.id

=item t_dps_block.dataset

The dataset this block belongs to.

=item t_dps_block.name

Name of the block.  Typically in the form PRIMARY/PROCESSED/TIER#GUID.

=item t_dps_block.files

Number of files in the block.

=item t_dps_block.bytes

Number of bytes in the block.

=item t_dps_block.is_open

Whether or not more files may be added to this block.  A closed block
may never become open again.

=item t_dps_block.time_create

=item t_dps_block.time_update

=back

=cut

 */
create table t_dps_block
  (id			integer		not null,
   dataset		integer		not null,
   name			varchar (1000)	not null,
   files		integer		not null,
   bytes		integer		not null,
   is_open		char (1)	not null,
   time_create		float		not null,
   time_update		float,
   --
   constraint pk_dps_block
     primary key (id),
   --
   constraint uq_dps_block_dataset
     unique (dataset, id),
   --
   constraint uq_dps_block_name
     unique (dataset, name),
   --
   constraint fk_dps_block_dataset
     foreign key (dataset) references t_dps_dataset (id),
   --
   constraint ck_dps_block_open
     check (is_open in ('y', 'n')),
   --
   constraint ck_dps_block_files
     check (files >= 0),
   --
   constraint ck_dps_block_bytes
     check (bytes >= 0));

create sequence seq_dps_block;

create index ix_dps_block_name on t_dps_block (name);

/* TODO: document!
FUTURE/UNUSED Which directories blocks can be found
create table t_dps_block_dir (
  block     integer      not null,
  dir       integer      not null,
  --
  constraint pk_dps_block_dir
    primary key (block, dir),
  --
  constraint fk_dps_block_dir_block
    foreign key (block) references t_dps_block (id)
    on delete cascade,
  --
  constraint fk_dps_block_dir_dir
    foreign key (dir) references t_dps_dir (id)
    on delete cascade
);

create index ix_dps_block_dir_dir on t_dps_block_dir (dir);
*/

/*
=pod

=head2 t_tmp_br_active

Temporary table for merging into t_dps_block_replica.  Contains a list
of blocks which are active.

=cut

*/
create global temporary table t_tmp_br_active
  (block      		integer		not null
) on commit delete rows;

/*
=pod

=head2 t_tmp_br_src

Temporary table for merging into t_dps_block_replica.  Contains
statistics for block generation.

=cut

*/
create global temporary table t_tmp_br_src
  (block      		integer		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   time_update		integer		not null
) on commit delete rows;


/*
=pod

=head2 t_tmp_br_dest

Temporary table for merging into t_dps_block_replica.  Contains
statistics for subscribed blocks.

=cut

*/
create global temporary table t_tmp_br_dest
  (block      		integer		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   time_update		integer		not null
) on commit delete rows;

/*
=pod

=head2 t_tmp_br_node

Temporary table for merging into t_dps_block_replica.  Contains
statistics for replicated blocks.

=cut

*/
create global temporary table t_tmp_br_node
  (block      		integer		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   time_update		integer		not null
) on commit delete rows;

/*
=pod

=head2 t_tmp_br_xfer

Temporary table for merging into t_dps_block_replica.  Contains
statistics for blocks currently being transferred.

=cut

*/
create global temporary table t_tmp_br_xfer
  (block      		integer		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   time_update		integer		not null
) on commit delete rows;

/*
=pod

=head2 t_tmp_br_flag

Temporary table for merging into t_dps_block_replica.  Contains
flags associated with a block replica.

=cut

*/
create global temporary table t_tmp_br_flag
  (block      		integer		not null,
   node			integer		not null,
   is_custodial		char(1)		not null,
   user_group		integer		,
   time_update		integer		not null
) on commit delete rows;

/*
=pod

=head2 t_dps_block_replica

A table containing statistics and various flags for blocks at (or
destined to be at) nodes.  This table becomes the only record that
transfers have been done once a block replica is deactivated and the
file-level replica information is removed.  Monitored by
L<BlockMonitor|PHEDEX::BlockMonitor::Agent>.

=over

=item t_dps_block_replica.block

=item t_dps_block_replica.node

=item t_dps_block_replica.is_active

Whether or not this replica is "active" (or "expanded").  Active
blocks have file-level information in t_xfer_* tables, while inactive
blocks do not.  Active blocks either need transfers to some
destination, or have only recently finished all needed transfers.

=item t_dps_block_replica.src_files

Number of files from this block which were generated at this node.

=item t_dps_block_replica.src_bytes

Number of bytes from this block which were generated at this node.

=item t_dps_block_replica.dest_files

Number of files from this block which are subscribed to this node.

=item t_dps_block_replica.dest_bytes

Number of bytes from this block which are subscribed to this node.

=item t_dps_block_replica.node_files

Number of files from this block at this node.

=item t_dps_block_replica.node_bytes

Number of bytes from this block at this node.

=item t_dps_block_replica.xfer_files

Number of files from this block currently being transferred to this node.

=item t_dps_block_replica.xfer_bytes

Number of bytes from this block currently being transferred to this node.

=item t_dps_block_replica.is_custoidal

Whether this is a custodial replica for this node.

=item t_dps_block_replica.user_group

Which user group is responsible for this replica.

=item t_dps_block_replica.time_create

=item t_dps_block_replica.time_update

=back

=cut

*/
create table t_dps_block_replica
  (block		integer		not null,
   node			integer		not null,
   is_active		char (1)	not null,
   src_files		integer		not null,
   src_bytes		integer		not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   is_custodial		char (1)	not null, -- applies to dest_files, node_files
   user_group		integer			, -- applies to dest_files, node_files
   time_create		float		not null,
   time_update		float		not null,
   --
   constraint pk_dps_block_replica
     primary key (block, node),
   --
   constraint fk_dps_block_replica_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_dps_block_replica_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_dps_block_replica_cust
     check (is_custodial in ('y', 'n')),
   --
   constraint fk_dps_block_replica_group
     foreign key (user_group) references t_adm_group (id)
     on delete set null,
   --
   constraint ck_dps_block_replica_active
     check (is_active in ('y', 'n')));

create index ix_dps_block_replica_node on t_dps_block_replica (node);

create index ix_dps_block_replica_group on t_dps_block_replica (user_group);

/*
=pod

=head2 t_dps_dataset_replica

FUTURE/UNUSED A table containing statistics for datasets at (or destined to be at)
nodes. Monitored by L<BlockMonitor|PHEDEX::BlockMonitor::Agent>.

=over

=item t_dps_dataset_replica.dataset

=item t_dps_dataset_replica.node

=item t_dps_dataset_replica.src_files

Number of files from this dataset which were generated at this node.

=item t_dps_dataset_replica.src_bytes

Number of bytes from this dataset which were generated at this node.

=item t_dps_dataset_replica.dest_files

Number of files from this dataset which are subscribed to this node.

=item t_dps_dataset_replica.dest_bytes

Number of bytes from this dataset which are subscribed to this node.

=item t_dps_dataset_replica.node_files

Number of files from this dataset at this node.

=item t_dps_dataset_replica.node_bytes

Number of bytes from this dataset at this node.

=item t_dps_dataset_replica.xfer_files

Number of files from this dataset currently being transferred to this node.

=item t_dps_dataset_replica.xfer_bytes

Number of bytes from this dataset currently being transferred to this node.

=item t_dps_dataset_replica.time_create

=item t_dps_dataset_replica.time_update

=back

=cut


create table t_dps_dataset_replica
  (dataset		integer		not null,
   node			integer		not null,
   src_files		integer		not null,
   src_bytes		integer		not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   time_create		float		not null,
   time_update		float		not null,
   --
   constraint pk_dps_dataset_replica
     primary key (dataset, node),
   --
   constraint fk_dps_dataset_replica_dataset
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_dataset_replica_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

create index ix_dps_dataset_replica_node on t_dps_dataset_replica (node);
*/
/* t_dps_block_dest.state states:
     0: Assigned but not yet active (= waiting for router to activate
        into t_xfer_request).
     1: Active (= routed has activated into t_xfer_request).
     2: Subscription suspended by user.
     3: Block completed and not to be considered further, but the
        entire subscription not yet completed and marked done.
     4: Suspended by the FileRouter due to bad behavior
*/

/*
=pod

=head2 t_dps_block_dest

Represents a block which should be transferred to a destination.
Monitored by L<BlockAllocator|PHEDEX::BlockAllocator::Agent>.

=over

=item t_dps_block_dest.block

=item t_dps_block_dest.dataset

=item t_dps_block_dataset.priority

Positive integer representing at what priority this block should be
transferred.  Lower values are higher priority.

=item t_dps_block_dest.is_custodial

Whether or not the destination is to have custodial responsibility for
this block.

=item t_dps_block_dest.state
  
 -2: Assigned but not yet active (router could not activate into
     t_xfer_request because there are no valid links to the destination)
 -1: Assigned but not yet active (router could not activate into
     t_xfer_request because the priority queue is full)
  0: Assigned but not yet active (= waiting for router to activate
     into t_xfer_request).
  1: Active (= routed has activated into t_xfer_request).
  2: Subscription suspended by user.
  3: Block completed and not to be considered further, but the
     entire subscription not yet completed and marked done.
  4: Suspended by the FileRouter due to bad behavior

=item t_dps_block_dest.time_subscription

The time this block was subscribed to the destination.

=item t_dps_block_dest.time_create

The time this block destination was created.

=item t_dps_block_dest.time_complete

The time this block destination was put into the complete state.

=item t_dps_block_dest.time_suspend_until

The time until which this block should remain suspended.

=back

=cut

*/
create table t_dps_block_dest
  (block		integer		not null,
   dataset		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   time_subscription	float		not null,
   time_create		float		not null,
   time_active		float,
   time_complete	float,
   time_suspend_until	float,
   --
   constraint pk_dps_block_dest
     primary key (block, destination),
   --
   constraint fk_dps_block_dest_dataset
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_block_dest_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_dps_block_dest_node
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_dps_block_dest_custodial
     check (is_custodial in ('y', 'n')));

create index ix_dps_block_dest_dataset on t_dps_block_dest (dataset);

create index ix_dps_block_dest_dest on t_dps_block_dest (destination);

/*
=pod

=head2 t_dps_block_activate

A table used to force the activation of a block.  Monitored by
L<BlockActivate|PHEDEX::BlockActivate::Agent>.

=over

=item t_dps_block_activate.block

=item t_dps_block_activate.time_request

The time this block was requested to be activated.

=item t_dps_block_activate.time_until

The time until which this block should remain activated.

=back

=cut

*/
create table t_dps_block_activate
  (block		integer		not null,
   time_request		float		not null,
   time_until		float,
   --
   constraint fk_dps_block_activate_block
     foreign key (block) references t_dps_block (id)
     on delete cascade);

create index ix_dps_block_activate_b on t_dps_block_activate (block);
