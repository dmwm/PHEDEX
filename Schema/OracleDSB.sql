-- PhEDEx ORACLE schema for agent operations.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: None.

----------------------------------------------------------------------
-- Create new tables

create sequence seq_dbs_dataset;
create sequence seq_dbs_block;
create sequence seq_dbs_run;
create sequence seq_dbs_file;

create table t_dbs_dataset
  (id			integer		not null,
   datatype		varchar (10)	not null,
   dataset		varchar (100)	not null,
   owner		varchar (100)	not null,
   collectionid		integer		not null,
   collectionstatus	integer		not null,
   inputowner		varchar (100),
   pudataset		varchar (100),
   puowner		varchar (100));


create table t_dbs_block
  (id			integer		not null,
   dataset		integer		not null,
   name			varchar (200)	not null,
   assignment		integer		not null);

create table t_dbs_run
  (id			integer		not null,
   dataset		integer		not null,
   name			varchar (40)	not null,
   events		integer		not null);


create table t_dbs_file
  (id			integer		not null,
   guid			char (36)	not null,
   filesize		integer		/* not null */,
   checksum		integer		/* not null */,
   filename		varchar (255)	not null,
   filetype		varchar (20),
   catfragment		varchar (4000));

create table t_dbs_file_attributes
  (fileid		integer		not null,
   attribute		varchar (40)	not null,
   value		varchar (1000));


create table t_dbs_file_map
  (fileid		integer		not null,
   dataset		integer		not null,
   block		integer		not null,
   run			integer		not null);


create table t_dls_index
  (block		integer		not null,
   location		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_dbs_dataset
  add constraint pk_dbs_dataset
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_dataset
  add constraint uq_dbs_dataset_dso
  unique (dataset, owner);

alter table t_dbs_dataset
  add constraint uq_dbs_dataset_collectionid
  unique (collectionid);


alter table t_dbs_block
  add constraint pk_dbs_block
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_block
  add constraint fk_dbs_block_dataset
  foreign key (dataset) references t_dbs_dataset (id);

alter table t_dbs_block
  add constraint uq_dbs_block_name
  unique (name);

alter table t_dbs_block
  add constraint uq_dbs_block_assignment
  unique (assignment);


alter table t_dbs_run
  add constraint pk_dbs_run
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_run
  add constraint fk_dbs_run_dataset
  foreign key (dataset) references t_dbs_dataset (id);

alter table t_dbs_run
  add constraint uq_dbs_run_dataset_name
  unique (dataset, name);


alter table t_dbs_file
  add constraint pk_dbs_file
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_file
  add constraint uq_dbs_file_guid
  unique (guid);


alter table t_dbs_file_attributes
  add constraint pk_dbs_file_attributes
  primary key (fileid, attribute)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_file_attributes
  add constraint fk_dbs_file_attributes_fileid
  foreign key (fileid) references t_dbs_file (id);


alter table t_dbs_file_map
  add constraint pk_dbs_file_map
  primary key (fileid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dbs_file_map
  add constraint fk_dbs_file_map_fileid
  foreign key (fileid) references t_dbs_file (id);

alter table t_dbs_file_map
  add constraint fk_dbs_file_map_dataset
  foreign key (dataset) references t_dbs_dataset (id);

alter table t_dbs_file_map
  add constraint fk_dbs_file_map_block
  foreign key (block) references t_dbs_block (id);

alter table t_dbs_file_map
  add constraint fk_dbs_file_map_run
  foreign key (run) references t_dbs_run (id);


alter table t_dls_index
  add constraint pk_dls_index
  primary key (block, location)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_dls_index
  add constraint fk_dls_index_block
  foreign key (block) references t_dbs_block (id);

----------------------------------------------------------------------
-- Add indices

create index ix_dbs_file_attributes_attr
  on t_dbs_file_attributes (attribute)
  tablespace CMS_TRANSFERMGMT_INDX01;
