-- PhEDEx ORACLE schema for agent operations.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: OracleDSB.sql

----------------------------------------------------------------------
-- Create new tables

create sequence seq_request_id;

create table t_request
  (id			integer		not null,
   name			varchar (100)	not null);

create table t_request_operation
  (timestamp		float		not null,
   request		integer		not null,
   identity		varchar (100)	not null,
   operation		varchar (20)	not null);

create table t_request_subscription
  (timestamp		float		not null,
   request		integer		not null,
   operation		varchar (20)	not null,
   destination		varchar (20));

create table t_request_dataspec
  (timestamp		float		not null,
   request		integer		not null,
   operation		varchar (20)	not null,
   owner		varchar (1000),
   dataset		varchar (1000),
   block		varchar (2000));

create table t_request_status
  (timestamp		float		not null,
   request		integer		not null,
   block		varchar (200)	not null,
   destination		varchar (20)	not null,
   dbs_isopen		char (1),
   dbs_files		integer,
   dbs_bytes		integer,
   tmdb_isopen		char (1),
   tmdb_files		integer,
   tmdb_bytes		integer,
   dest_files		integer,
   dest_bytes		integer,
   common_files		integer,
   dbs_only_files	integer,
   tmdb_only_files	integer);

----------------------------------------------------------------------
-- Add constraints

alter table t_request
  add constraint pk_request
  primary key (id)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_request
  add constraint uq_request_name
  unique (name);


alter table t_request_operation
  add constraint fk_request_operation_req
  foreign key (request) references t_request (id);


alter table t_request_subscription
  add constraint fk_request_subscription_req
  foreign key (request) references t_request (id);


alter table t_request_dataspec
  add constraint fk_request_dataspec_req
  foreign key (request) references t_request (id);


alter table t_request_status
  add constraint fk_request_status_req
  foreign key (request) references t_request (id);

alter table t_request_status
  add constraint pk_request_status
  primary key (request, block, destination)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

----------------------------------------------------------------------
-- Add indices

create index ix_request_operation_req
  on t_request_operation (request)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_request_subscription_req
  on t_request_subscription (request)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_request_dataspec_req
  on t_request_dataspec (request)
  tablespace CMS_TRANSFERMGMT_INDX01;


create index ix_request_status_req
  on t_request_status (request)
  tablespace CMS_TRANSFERMGMT_INDX01;
