-- PhEDEx ORACLE schema for agent operations.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: OracleCoreTopo.sql, OracleCoreFiles.sql

----------------------------------------------------------------------
-- Create new tables

-- FIXME: partitioning by to_node?
-- FIXME: index organised?
-- FIXME: indexing?

create table t_transfer_history
  (timestamp		float		not null,
   guid			char (36)	not null,
   to_node		varchar (20)	not null,
   to_old_state		integer,
   to_new_state		integer		not null,
   from_node		varchar (20)	not null,
   from_old_state	integer,
   from_new_state	integer		not null);

create table t_transfer_summary
  (timestamp		float		not null,
   guid			char (36)	not null,
   from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   assigned		float		not null,
   wanted1st		float,
   wanted		float,
   exported		float,
   started		float,
   completed		float,
   cleared		float,
   errors		integer		not null,
   error_total		float		not null,
   error_began		float);

----------------------------------------------------------------------
-- Add constraints

----------------------------------------------------------------------
-- Add indices

create index ix_transfer_history
  on t_transfer_history (timestamp, guid)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_summary
  on t_transfer_summary (timestamp, guid)
  tablespace CMS_TRANSFERMGMT_INDX01;

----------------------------------------------------------------------
-- Modify storage options

alter table t_transfer_history			move initrans 8;
alter index ix_transfer_history			rebuild initrans 8;
