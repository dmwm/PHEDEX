-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_transfer_history;
drop table t_transfer_summary;

----------------------------------------------------------------------
-- Create new tables

-- FIXME: partitioning
-- FIXME: index organised?

create table t_transfer_history
  (timestamp		float		not null,
   guid			char (36)	not null,
   from_node		varchar (20)	not null,
   from_old_state	integer,
   from_new_state	integer		not null,
   to_node		varchar (20)	not null,
   to_old_state		integer,
   to_new_state		integer		not null);

create table t_transfer_summary
  (guid			char (36)	not null,
   from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   assigned		float		not null,
   wanted		float,
   exported		float,
   started		float,
   completed		float,
   errors		integer		not null,
   inerror		float		not null,
   last_error_entry	float);

----------------------------------------------------------------------
-- Add constraints

alter table t_transfer_history
  add constraint t_transfer_history_pk
  primary key (guid, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_transfer_history
  add constraint t_transfer_history_fk_guid
  foreign key (guid) references t_files_for_transfer (guid);

alter table t_transfer_history
  add constraint t_transfer_history_fk_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_history
  add constraint t_transfer_history_fk_to_node
  foreign key (to_node) references t_nodes (name);


alter table t_transfer_summary
  add constraint t_transfer_summary_pk
  primary key (guid, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_transfer_summary
  add constraint t_transfer_summary_fk_guid
  foreign key (guid) references t_files_for_transfer (guid);

alter table t_transfer_summary
  add constraint t_transfer_summary_fk_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_transfer_summary
  add constraint t_transfer_summary_fk_to_node
  foreign key (to_node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

