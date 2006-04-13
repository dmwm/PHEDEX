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
   time_create		float		not null);

create table t_dps_dataset
  (id			integer		not null,
   dbs			integer		not null,
   name			varchar (1000)	not null,
   is_open		char (1)	not null,
   is_transient		char (1)	not null,
   time_create		float		not null,
   time_update		float);

create table t_dps_block
  (id			integer		not null,
   dataset		integer		not null,
   name			varchar (1000)	not null,
   files		integer		not null,
   bytes		integer		not null,
   is_open		char (1)	not null,
   time_create		float		not null,
   time_update		float);

create table t_dps_block_replica
  (block		integer		not null,
   node			integer		not null,
   is_active		char (1)	not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   time_create		float		not null,
   time_update		float		not null);

create table t_dps_block_dest
  (block		integer		not null,
   dataset		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   time_subscription	float		not null,
   time_create		float		not null,
   time_complete	float,
   time_suspend_until	float);

create table t_dps_block_activate
  (block		integer		not null,
   time_request		float		not null,
   time_until		float);

create table t_dps_block_delete
  (block		integer		not null,
   dataset		integer		not null,
   node			integer		not null,
   time_request		float		not null,
   time_complete	float);

create table t_dps_subscription
  (dataset		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   is_move		char (1)	not null,
   is_transient		char (1)	not null,
   time_create		float		not null,
   time_complete	float,
   time_clear		float,
   time_done		float,
   time_suspend_until	float);

----------------------------------------------------------------------
-- Add constraints

alter table t_dps_dbs
  add constraint pk_dps_dbs
  primary key (id);

alter table t_dps_dbs
  add constraint uq_dps_dbs_name
  unique (name);


alter table t_dps_dataset
  add constraint pk_dps_dataset
  primary key (id);

alter table t_dps_dataset
  add constraint uq_dps_dataset_key
  unique (dbs, name);

alter table t_dps_dataset
  add constraint fk_dps_dataset_dbs
  foreign key (dbs) references t_dps_dbs (id);

alter table t_dps_dataset
  add constraint ck_dbs_dataset_open
  check (is_open in ('y', 'n'));

alter table t_dps_dataset
  add constraint ck_dbs_dataset_transient
  check (is_transient in ('y', 'n'));


alter table t_dps_block
  add constraint pk_dps_block
  primary key (id);

-- alter table t_dps_block
--  add constraint uq_dps_block_key
--  unique (dbs, name);

-- alter table t_dps_block
--   add constraint fk_dbs_block_dbs
--   foreign key (dbs) references t_dps_dbs (id);

alter table t_dps_block
  add constraint fk_dbs_block_dataset
  foreign key (dataset) references t_dps_dataset (id);

alter table t_dps_block
  add constraint ck_dbs_block_open
  check (is_open in ('y', 'n'));


alter table t_dps_block_replica
  add constraint pk_dps_block_replica
  primary key (block, node);

alter table t_dps_block_replica
  add constraint fk_dps_block_replica_block
  foreign key (block) references t_dps_block (id);

alter table t_dps_block_replica
  add constraint fk_dps_block_replica_node
  foreign key (node) references t_node (id);

alter table t_dps_block_replica
  add constraint ck_dbs_block_replica_active
  check (is_active in ('y', 'n'));


alter table t_dps_block_dest
  add constraint pk_dps_block_dest
  primary key (block, destination);

alter table t_dps_block_dest
  add constraint fk_dps_block_dest_dataset
  foreign key (dataset) references t_dps_dataset (id);

alter table t_dps_block_dest
  add constraint fk_dps_block_dest_block
  foreign key (block) references t_dps_block (id);

alter table t_dps_block_dest
  add constraint fk_dps_block_dest_node
  foreign key (destination) references t_node (id);


alter table t_dps_block_activate
  add constraint fk_dps_block_activate_block
  foreign key (block) references t_dps_block (id);


alter table t_dps_block_delete
  add constraint pk_dps_block_remove
  primary key (block, node);

alter table t_dps_block_delete
  add constraint fk_dps_block_remove_block
  foreign key (block) references t_dps_block (id);

alter table t_dps_block_delete
  add constraint fk_dps_block_remove_dataset
  foreign key (dataset) references t_dps_dataset (id);

alter table t_dps_block_delete
  add constraint fk_dps_block_remove_node
  foreign key (node) references t_node (id);


alter table t_dps_subscription
  add constraint pk_dps_subscription
  primary key (dataset, destination);

alter table t_dps_subscription
  add constraint fk_dps_subscription_dataset
  foreign key (dataset) references t_dps_dataset (id);

alter table t_dps_subscription
  add constraint fk_dps_subscription_dest
  foreign key (destination) references t_node (id);

alter table t_dps_subscription
  add constraint ck_dps_subscription_move
  check (is_move in ('y', 'n'));

alter table t_dps_subscription
  add constraint ck_dps_subscription_transient
  check (is_transient in ('y', 'n'));

----------------------------------------------------------------------
-- Add indices

create index ix_dps_subscription_stream
  on t_dps_subscription (dataset);

create index ix_dps_subscription_dest
  on t_dps_subscription (destination);
