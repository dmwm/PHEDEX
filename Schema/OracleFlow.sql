-- PhEDEx ORACLE schema for dataflow layer.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: None.

----------------------------------------------------------------------
-- Drop old tables

drop table t_subscription;
drop table t_block_replica;
drop table t_block;

----------------------------------------------------------------------
-- Create new tables

create table t_block
  (name			varchar (200)	not null,
   owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_block_replica
  (timestamp		float		not null,
   name			varchar (200)	not null,
   node			varchar (20)	not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_subscription
  (owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   destination		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_block
  add constraint pk_block
  primary key (name)
  using index tablespace INDX01;


alter table t_block_state
  add constraint pk_block_state
  primary key (name, node)
  using index tablespace INDX01;

alter table t_block_state
  add constraint fk_block_state_name
  foreign key (name) references t_block (name);

alter table t_block_state
  add constraint fk_block_state_node
  foreign key (node) references t_node (name);


----------------------------------------------------------------------
-- Add indices

create index ix_subscription_stream
  on t_subscription (owner, dataset)
  tablespace INDX01;

create index ix_subscription_destination
  on t_subscription (destination)
  tablespace INDX01;
