-- PhEDEx ORACLE schema for agent operations.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: None.

----------------------------------------------------------------------
-- Create new tables

create sequence seq_dbs_fileid;
create sequence seq_dbs_dataset;

create table t_dbs_fileid
  (id			integer		not null,
   guid			char (36)	not null);

create table t_dbs_file
  (fileid		integer		not null,
   filesize		integer		not null,
   checksum		integer		not null,
   filename		varchar (255)	not null,
   filetype		varchar (20),
   catfragment		varchar (4000));

create table t_dbs_file_attributes
  (fileid		integer		not null,
   attribute		varchar (40)	not null,
   value		varchar (1000));


create table t_dbs_dataset
  (id			integer		not null,
   datatype		varchar (10)	not null,
   dataset		varchar (100)	not null,
   owner		varchar (100)	not null,
   inputowner		varchar (100),
   pudataset		varchar (100),
   puowner		varchar (100));

-- FIXME: blocks

create table t_dbs_dataset_run
  (dataset		integer		not null,
   runid		varchar (40)	not null,
   events		integer		not null);

create table t_dbs_dataset_run_file
  (dataset		integer		not null,
   runid		varchar (40)	not null,
   fileid		integer		not null);

create table t_dbs_dataset_availability
  (dataset		integer		not null,
   location		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_dbs_fileid
  add constraint pk_dbs_fileid_id
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_fileid
  add constraint uq_dbs_fileid_guid
  unique (guid);


alter table t_dbs_file
  add constraint pk_dbs_file
  primary key (fileid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_file
  add constraint fk_dbs_file_fileid
  foreign key (fileid) references t_dbs_fileid (id);


alter table t_dbs_file_attributes
  add constraint pk_dbs_file_attributes
  primary key (fileid, attribute)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_file_attributes
  add constraint fk_dbs_file_attributes_fileid
  foreign key (fileid) references t_dbs_fileid (id);


alter table t_dbs_dataset
  add constraint pk_dbs_dataset
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_dbs_dataset_run
  add constraint pk_dbs_dataset_run
  primary key (dataset, runid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_dataset_run
  add constraint fk_dbs_dataset_run_dataset
  foreign key (dataset) references t_dbs_dataset (id);


alter table t_dbs_dataset_run_file
  add constraint pk_dbs_dataset_run_file
  primary key (dataset, fileid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_dataset_run_file
  add constraint fk_dbs_dataset_rfiles_dataset
  foreign key (dataset) references t_dbs_dataset (id);

alter table t_dbs_dataset_run_file
  add constraint fk_dbs_dataset_rfiles_fileid
  foreign key (fileid) references t_dbs_fileid (id);


alter table t_dbs_dataset_availability
  add constraint pk_dbs_dataset_availability
  primary key (dataset, location)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_dataset_availability
  add constraint fk_dbs_dataset_avail_dataset
  foreign key (dataset) references t_dbs_dataset (id);


----------------------------------------------------------------------
-- Add indices

create index ix_dbs_file_attributes_attr
  on t_dbs_file_attributes (attribute)
  tablespace CMS_TRANSFERMGMT_INDX01;
