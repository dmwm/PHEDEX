-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: None.

----------------------------------------------------------------------
-- Drop old tables

drop sequence seq_dsb_fileid;
drop sequence seq_dsb_dataset;
drop table t_dsb_file_availability;
drop table t_dsb_file_attributes;
drop table t_dsb_dataset_files;
drop table t_dsb_dataset;
drop table t_dsb_file;
drop table t_dsb_fileid;

----------------------------------------------------------------------
-- Create new tables

create sequence seq_dsb_fileid;
create sequence seq_dsb_dataset;

create table t_dsb_fileid
  (id			integer		not null,
   guid			char (36)	not null);

create table t_dsb_file
  (fileid		integer		not null,
   filesize		integer,
   checksum		integer,
   catfragment		clob);

create table t_dsb_file_attributes
  (fileid		integer		not null,
   attribute		varchar (32)	not null,
   value		varchar (1000)	not null);

create table t_dsb_file_availability
  (fileid		integer		not null,
   location		varchar (20)	not null);


create table t_dsb_dataset
  (id			integer		not null,
   dataset		varchar (1000)	not null,
   owner		varchar (1000)	not null);

create table t_dsb_dataset_files
  (dataset		integer		not null,
   fileid		integer		not null);


----------------------------------------------------------------------
-- Add constraints

alter table t_dsb_fileid
  add constraint pk_dsb_fileid_id
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dsb_fileid
  add constraint uq_dsb_fileid_guid
  unique (guid);


alter table t_dsb_file
  add constraint pk_dsb_file
  primary key (fileid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dsb_file
  add constraint fk_dsb_file_fileid
  foreign key (fileid) references t_dsb_fileid (id);


alter table t_dsb_file_attributes
  add constraint pk_dsb_file_attributes
  primary key (fileid, attribute)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dsb_file_attributes
  add constraint fk_dsb_file_attributes_fileid
  foreign key (fileid) references t_dsb_fileid (id);


alter table t_dsb_file_availability
  add constraint pk_dsb_file_availability
  primary key (fileid, location)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dsb_file_availability
  add constraint fk_dsb_file_avail_fileid
  foreign key (fileid) references t_dsb_fileid (id);


alter table t_dsb_dataset
  add constraint pk_dsb_dataset
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_dsb_dataset_files
  add constraint pk_dsb_dataset_files
  primary key (dataset, fileid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dsb_dataset_files
  add constraint fk_dsb_dataset_files_dataset
  foreign key (dataset) references t_dsb_dataset (id);

alter table t_dsb_dataset_files
  add constraint fk_dsb_dataset_files_fileid
  foreign key (fileid) references t_dsb_fileid (id);


----------------------------------------------------------------------
-- Add indices

create index ix_dsb_file_attributes_attr
  on t_dsb_file_attributes (attribute)
  tablespace CMS_TRANSFERMGMT_INDX01;
