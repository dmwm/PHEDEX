-- PhEDEx ORACLE schema for file information.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_files;
drop table t_file_attributes;

----------------------------------------------------------------------
-- Create new tables

create table t_files
	(guid			char (36)	not null,
	 source_node		varchar (20)	not null,
	 filesize		integer		not null,
	 checksum		integer);

create table t_file_attributes
	(guid			char (36)	not null,
	 attribute		varchar (1000)	not null,
	 value			varchar (1000));

----------------------------------------------------------------------
-- Add constraints

alter table t_files
  add constraint t_files_pk
  primary key (guid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_files
  add constraint t_files_fk_source_node
  foreign key (source_node) references t_nodes (name);


alter table t_file_attributes
  add constraint t_file_attributes_pk
  primary key (guid, attribute)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_file_attributes
  add constraint t_file_attributes_fk_guid
  foreign key (guid) references t_files (guid);

----------------------------------------------------------------------
-- Add indices

