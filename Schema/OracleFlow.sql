-- PhEDEx ORACLE schema for dataflow layer.
-- REQUIRES: None.

----------------------------------------------------------------------
-- Create new tables

create table t_block
  (timestamp		float		not null,
   name			varchar (200)	not null,
   owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   files		integer		not null,
   bytes		integer		not null,
   isopen		char (1)	not null);

create table t_block_replica
  (timestamp		float		not null,
   name			varchar (200)	not null,
   node			varchar (20)	not null,
   isactive		char (1)	not null,
   last_update		float		not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   expt_files		integer		not null,
   expt_bytes		integer		not null);

create table t_block_destination
  (timestamp		float		not null,
   name			varchar (200)	not null,
   node			varchar (20)	not null,
   completed		float);

create table t_subscription
  (owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   destination		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_block
  add constraint pk_block
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_block_replica
  add constraint pk_block_replica
  primary key (name, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_block_replica
  add constraint fk_block_replica_name
  foreign key (name) references t_block (name);

alter table t_block_replica
  add constraint fk_block_replica_node
  foreign key (node) references t_node (name);


alter table t_block_destination
  add constraint pk_block_destination
  primary key (name, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_block_destination
  add constraint fk_block_destination_name
  foreign key (name) references t_block (name);

alter table t_block_destination
  add constraint fk_block_destination_node
  foreign key (node) references t_node (name);

----------------------------------------------------------------------
-- Add indices

create index ix_subscription_stream
  on t_subscription (owner, dataset)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_subscription_destination
  on t_subscription (destination)
  tablespace CMS_TRANSFERMGMT_INDX01;
