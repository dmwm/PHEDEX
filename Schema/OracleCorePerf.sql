-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_transfer_history;
drop table t_transfer_summary;

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
   wanted		float,
   exported		float,
   started		float,
   completed		float,
   cleared		float,
   errors		integer		not null,
   inerror		float		not null,
   last_error_entry	float);

----------------------------------------------------------------------
-- Add constraints

alter table t_transfer_history
  add constraint fk_transfer_history_guid
  foreign key (guid) references t_files (guid);

alter table t_transfer_history
  add constraint fk_transfer_history_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_history
  add constraint fk_transfer_history_to_node
  foreign key (to_node) references t_nodes (name);


alter table t_transfer_summary
  add constraint fk_transfer_summary_guid
  foreign key (guid) references t_files (guid);

alter table t_transfer_summary
  add constraint fk_transfer_summary_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_summary
  add constraint fk_transfer_summary_to_node
  foreign key (to_node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

create index ix_transfer_history_guid
  on t_transfer_history (guid)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_history_from_node
  on t_transfer_history (from_node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_history_to_node
  on t_transfer_history (to_node)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_transfer_summary_guid
  on t_transfer_summary (guid)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_summary_from_node
  on t_transfer_summary (from_node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_transfer_summary_to_node
  on t_transfer_summary (to_node)
  tablespace CMS_TRANSFERMGMT_INDX01;
