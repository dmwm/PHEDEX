-- PhEDEx ORACLE schema for file information.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_file;
drop table t_file_attributes;

----------------------------------------------------------------------
-- Create new tables

-- FIXME: index organised?
-- FIXME: partitioned?

create table t_file
  (timestamp		float		not null,
   guid			char (36)	not null,
   node			varchar (20)	not null,
   inblock		varchar (200)	not null,
   insubblock		varchar (200)	not null,
   lfn			varchar (255)	not null,
   filetype		varchar (100)	not null,
   filesize		integer		not null,
   checksum		integer);

create table t_file_attributes
  (guid			char (36)	not null,
   attribute		varchar (32)	not null,
   value		varchar (1000));

----------------------------------------------------------------------
-- Add constraints

alter table t_file
  add constraint pk_file
  primary key (guid)
  using index tablespace INDX01;

alter table t_file
  add constraint fk_file_node
  foreign key (node) references t_node (name);

alter table t_file_attributes
  add constraint pk_file_attributes
  primary key (guid, attribute)
  using index tablespace INDX01;

alter table t_file_attributes
  add constraint fk_file_attributes_guid
  foreign key (guid) references t_file (guid);

----------------------------------------------------------------------
-- Add indices

create index ix_file_node
  on t_file (node)
  tablespace INDX01;


create index ix_file_attributes_attr
  on t_file_attributes (attribute)
  tablespace INDX01;
