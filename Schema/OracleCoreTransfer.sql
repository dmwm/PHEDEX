-- PhEDEx ORACLE schema for transfer and replica data.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql, OracleCoreFiles.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_destinations;
drop table t_replica_state;
drop table t_transfer_state;

----------------------------------------------------------------------
-- Create new tables

-- FIXME: partitioning
-- FIXME: index organised?

create table t_destinations
  (timestamp		float		not null,
   guid			char (36)	not null,
   node			varchar (20)	not null);

create table t_replica_state
  (timestamp		float		not null,
   guid			char (36)	not null,
   node			varchar (20)	not null,
   state		integer		not null);

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

----------------------------------------------------------------------
-- Add constraints

alter table t_destinations
  add constraint pk_destinations
  primary key (guid, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_destinations
  add constraint fk_destinations_guid
  foreign key (guid) references t_files (guid);

alter table t_destinations
  add constraint fk_destinations_node
  foreign key (node) references t_nodes (name);


alter table t_replica_state
  add constraint pk_replica_state
  primary key (guid, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_replica_state
  add constraint fk_replica_state_guid
  foreign key (guid) references t_files (guid);

alter table t_replica_state
  add constraint fk_replica_state_node
  foreign key (node) references t_nodes (name);


alter table t_transfer_state
  add constraint pk_transfer_state
  primary key (guid, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_transfer_state
  add constraint fk_transfer_state_guid
  foreign key (guid) references t_files (guid);

alter table t_transfer_state
  add constraint fk_transfer_state_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_state
  add constraint fk_transfer_state_to_node
  foreign key (to_node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

create index ix_transfer_state_from_node
  on t_transfer_state (from_node)
  tablespace CMS_TRANSFERMGMT_INDX01;
