----------------------------------------------------------------------
-- Create sequences

create sequence seq_dps_file;

----------------------------------------------------------------------
-- Create tables

create table t_dps_file
  (id			integer		not null,
   node			integer		not null,
   inblock		integer		not null,
   logical_name		varchar (1000)	not null,
   checksum		varchar (1000)	not null,
   filesize		integer		not null,
   time_create		float		not null);

create table t_xfer_file
  (id			integer		not null,
   inblock		integer		not null,
   logical_name		varchar (1000)	not null,
   checksum		varchar (1000)	not null,
   filesize		integer		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_dps_file
  add constraint pk_dps_file
  primary key (id)
  using index tablespace INDX01;

alter table t_dps_file
  add constraint uq_dps_file_logical_name
  unique (logical_name);

alter table t_dps_file
  add constraint fk_dps_file_node
  foreign key (node) references t_node (id);

alter table t_dps_file
  add constraint fk_dps_file_inblock
  foreign key (inblock) references t_dps_block (id);


alter table t_xfer_file
  add constraint pk_xfer_file
  primary key (id)
  using index tablespace INDX01;

alter table t_xfer_file
  add constraint uq_xfer_file_logical_name
  unique (logical_name);

alter table t_xfer_file
  add constraint fk_xfer_file_id
  foreign key (id) references t_dps_file (id);

alter table t_xfer_file
  add constraint fk_xfer_file_inblock
  foreign key (inblock) references t_dps_block (id);

----------------------------------------------------------------------
-- Add indices

create index ix_dps_file_node
  on t_dps_file (node)
  tablespace INDX01;

create index ix_dps_file_id_filesize
  on t_dps_file (id, filesize)
  tablespace INDX01;

create index ix_dps_file_inblock_id
  on t_dps_file (inblock, id)
  tablespace INDX01;


create index ix_xfer_file_id_filesize
  on t_xfer_file (id, filesize)
  tablespace INDX01;

create index ix_xfer_file_inblock_id
  on t_xfer_file (inblock, id)
  tablespace INDX01;
