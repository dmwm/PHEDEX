----------------------------------------------------------------------
-- Create sequences

create sequence seq_dps_dbs;
create sequence seq_dps_dataset;
create sequence seq_dps_block;

----------------------------------------------------------------------
-- Create tables

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


create table t_dps_dataset
  (id			integer		not null,
   dbs			integer		not null,
   name			varchar (1000)	not null,
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
   constraint ck_dps_block_replica_active
     check (is_active in ('y', 'n')));


create table t_dps_block_dest
  (block		integer		not null,
   dataset		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
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
     on delete cascade);


create table t_dps_block_activate
  (block		integer		not null,
   time_request		float		not null,
   time_until		float,
   --
   constraint fk_dps_block_activate_block
     foreign key (block) references t_dps_block (id)
     on delete cascade);


create table t_dps_block_delete
  (block		integer		not null,
   dataset		integer		not null,
   node			integer		not null,
   time_request		float		not null,
   time_complete	float,
   --
   constraint pk_dps_block_delete
     primary key (block, node),
   --
   constraint fk_dps_block_delete_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_dps_block_delete_dataset
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_block_delete_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);


create table t_dps_subscription
  (dataset		integer,
   block		integer,
   destination		integer		not null,
   priority		integer		not null,
   is_move		char (1)	not null,
   is_transient		char (1)	not null,
   time_create		float		not null,
   time_complete	float,
   time_clear		float,
   time_done		float,
   time_suspend_until	float,
   --
   constraint uq_dps_subscription
     unique (dataset, block, destination),
   --
   constraint fk_dps_subscription_dataset
     foreign key (dataset) references t_dps_dataset (id),
   --
   constraint fk_dps_subscription_block
     foreign key (block) references t_dps_block (id),
   --
   constraint fk_dps_subscription_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint ck_dps_subscription_ref
     check (not (block is null and dataset is null)
            and not (block is not null and dataset is not null)),
   --
   constraint ck_dps_subscription_move
     check (is_move in ('y', 'n')),
   --
   constraint ck_dps_subscription_transient
     check (is_transient in ('y', 'n')));

----------------------------------------------------------------------
-- Create indices

create index ix_dps_block_dataset
  on t_dps_block (dataset);

--
create index ix_dps_block_replica_node
  on t_dps_block_replica (node);

--
create index ix_dps_block_dest_dataset
  on t_dps_block_dest (dataset);

create index ix_dps_block_dest_dest
  on t_dps_block_dest (destination);

--
create index ix_dps_block_activate_b
  on t_dps_block_activate (block);

--
create index ix_dps_block_delete_ds
  on t_dps_block_delete (dataset);

create index ix_dps_block_delete_node
  on t_dps_block_delete (node);

--
create index ix_dps_subscription_dataset
  on t_dps_subscription (dataset);

create index ix_dps_subscription_block
  on t_dps_subscription (block);

create index ix_dps_subscription_dest
  on t_dps_subscription (destination);

