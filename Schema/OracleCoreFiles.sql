----------------------------------------------------------------------
-- Create sequences

create sequence seq_file;

----------------------------------------------------------------------
-- Create tables

create table t_file
  (id			integer		not null,
   node			integer		not null,
   inblock		integer		not null,
   logical_name		varchar (1000)	not null,
   filetype		varchar (1000)	not null,
   checksum		varchar (1000)	not null,
   filesize		integer		not null,
   time_create		float		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_file
  add constraint pk_file
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_file
  add constraint uq_file_logical_name
  unique (logical_name);

alter table t_file
  add constraint fk_file_node
  foreign key (node) references t_node (id);

alter table t_file
  add constraint fk_file_inblock
  foreign key (inblock) references t_dps_block (id);

----------------------------------------------------------------------
-- Add indices

create index ix_file_node
  on t_file (node)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_file_id_filesize
  on t_file (id, filesize)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_file_inblock_id
  on t_file (inblock, id)
  tablespace CMS_TRANSFERMGMT_INDX01;
