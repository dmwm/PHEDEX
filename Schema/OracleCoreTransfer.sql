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
  (guid			char (36)	not null,
   node			varchar (20)	not null,
   timestamp		float		not null);

create table t_replica_state
  (guid			char (36)	not null,
   node			varchar (20)	not null,
   state		integer		not null,
   local_state		integer		not null,
   timestamp		float		not null);

create table t_transfer_state
  (guid			char (36)	not null,
   from_node		varchar (20)	not null,
   from_state		integer		not null,
   from_timestamp	float		not null,
   from_pfn		varchar (500),
   to_node		varchar (20)	not null,
   to_state		integer		not null,
   to_timestamp		float		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_destinations
  add constraint t_destinations_pk
  primary key (guid, destination_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_destinations
  add constraint t_destinations_fk_guid
  foreign key (guid) references t_files_for_transfer (guid);

alter table t_destinations
  add constraint t_destinations_fk_node
  foreign key (node) references t_nodes (name);


alter table t_replica_state
  add constraint t_replica_state_pk
  primary key (guid, node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_replica_state
  add constraint t_replica_state_fk_guid
  foreign key (guid) references t_files_for_transfer (guid);

alter table t_replica_state
  add constraint t_replica_state_fk_node
  foreign key (node) references t_nodes (name);


alter table t_transfer_state
  add constraint t_transfer_state_pk
  primary key (guid, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_transfer_state
  add constraint t_transfer_state_fk_guid
  foreign key (guid) references t_files_for_transfer (guid);

alter table t_transfer_state
  add constraint t_transfer_state_fk_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_state
  add constraint t_transfer_state_fk_to_node
  foreign key (to_node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

