-- PhEDEx ORACLE schema for file information.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_files;
drop table t_file_attributes;

----------------------------------------------------------------------
-- Create new tables

-- FIXME: index organised?
-- FIXME: partitioned?

create table t_files
  (timestamp		float		not null,
   guid			char (36)	not null,
   node			varchar (20)	not null,
   filesize		integer		not null,
   checksum		integer);

create table t_file_attributes
  (guid			char (36)	not null,
   attribute		varchar (32)	not null,
   value		varchar (1000));

----------------------------------------------------------------------
-- Add constraints

alter table t_files
  add constraint pk_files
  primary key (guid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_files
  add constraint fk_files_source_node
  foreign key (node) references t_nodes (name);


alter table t_file_attributes
  add constraint pk_file_attributes
  primary key (guid, attribute)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_file_attributes
  add constraint fk_file_attributes_guid
  foreign key (guid) references t_files (guid);

----------------------------------------------------------------------
-- Add indices

create index ix_files_node
  on t_files (node)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_file_attributes_attr
  on t_file_attributes (attribute)
  tablespace CMS_TRANSFERMGMT_INDX01;
