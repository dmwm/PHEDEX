-- PhEDEx ORACLE schema for transfer and replica data.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: OracleCoreTopo.sql, OracleCoreFiles.sql

----------------------------------------------------------------------
-- Create new tables

-- FIXME: partitioning
-- FIXME: index organised?

create table t_replica_state
  (timestamp		float		not null,
   guid			char (36)	not null,
   node			varchar (20)	not null,
   state		integer		not null,
   state_timestamp	float		not null);

create table t_transfer_state
  (timestamp		float		not null,
   guid			char (36)	not null,
   to_node		varchar (20)	not null,
   to_state		integer		not null,
   to_timestamp		float		not null,
   from_node		varchar (20)	not null,
   from_state		integer		not null,
   from_timestamp	float		not null,
   from_pfn		varchar (500));

create table t_transfer_completed
  (timestamp		float		not null,
   guid			char (36)	not null,
   to_node		varchar (20)	not null,
   to_state		integer		not null,
   to_timestamp		float		not null,
   from_node		varchar (20)	not null,
   from_state		integer		not null,
   from_timestamp	float		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_replica_state
  add constraint pk_replica_state
  primary key (guid, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_replica_state
  add constraint fk_replica_state_guid
  foreign key (guid) references t_file (guid);

alter table t_replica_state
  add constraint fk_replica_state_node
  foreign key (node) references t_node (name);


alter table t_transfer_state
  add constraint pk_transfer_state
  primary key (guid, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_transfer_state
  add constraint fk_transfer_state_guid
  foreign key (guid) references t_file (guid);

alter table t_transfer_state
  add constraint fk_transfer_state_from_node
  foreign key (from_node) references t_node (name);

alter table t_transfer_state
  add constraint fk_transfer_state_to_node
  foreign key (to_node) references t_node (name);

----------------------------------------------------------------------
-- Add indices

create index ix_replica_state_node
  on t_replica_state (node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_replica_state_common
  on t_replica_state (node, state, guid)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_transfer_state_from_node
  on t_transfer_state (from_node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_state_to_node
  on t_transfer_state (to_node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_state_to_state
  on t_transfer_state (to_state)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_state_fromto_state
  on t_transfer_state (from_node, guid, to_state)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_state_fromto_pair
  on t_transfer_state (from_node, to_node)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_transfer_completed_fromto
  on t_transfer_completed (from_node, to_node)
  tablespace CMS_TRANSFERMGMT_INDX01;

----------------------------------------------------------------------
-- Modify storage options

alter table t_replica_state			move initrans 8;
alter table t_transfer_state			move initrans 8;

alter index pk_replica_state			rebuild initrans 8;
alter index ix_replica_state_node		rebuild initrans 8;
alter index ix_replica_state_common		rebuild initrans 8;

alter index pk_transfer_state			rebuild initrans 8;
alter index ix_transfer_state_from_node		rebuild initrans 8;
alter index ix_transfer_state_to_node		rebuild initrans 8;
alter index ix_transfer_state_to_state		rebuild initrans 8;
alter index ix_transfer_state_fromto_state	rebuild initrans 8;
alter index ix_transfer_state_fromto_pair	rebuild initrans 8;
