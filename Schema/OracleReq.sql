-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_request_file_status;
drop table t_request_file;
drop table t_request_drop;
drop table t_request_data;
drop table t_request_subscription;
drop table t_request_operation;
drop table t_request;

----------------------------------------------------------------------
-- Create new tables

create table t_request
  (name			varchar (100)	not null);

create table t_request_operation
  (request		varchar (100)	not null,
   timestamp		float		not null,
   identity		varchar (100)	not null,
   operation		varchar (20)	not null);

create table t_request_subscription
  (request		varchar (100)	not null,
   timestamp		float		not null,
   operation		varchar (20)	not null,
   destination		varchar (20));

create table t_request_data
  (request		varchar (100)	not null,
   timestamp		float		not null,
   operation		varchar (20)	not null,
   selection		varchar (1000));

create table t_request_drop
  (request		varchar (100)	not null,
   drop_name		varchar (200)	not null,
   drop_category	varchar (20)	not null);

create table t_request_file
  (request		varchar (100)	not null,
   guid			char (36)	not null,
   drop_name		varchar (200)	not null);

create table t_request_file_status
  (request		varchar (100)	not null,
   guid			char (36)	not null,
   location		varchar (20)	not null,
   is_available		char (1)	not null,
   is_pending		char (1)	not null,
   is_transferred	char (1)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_request
  add constraint t_request_pk
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_request_operation
  add constraint t_request_operation_fk_req
  foreign key (request) references t_request (name);


alter table t_request_subscription
  add constraint t_request_subscription_fk_req
  foreign key (request) references t_request (name);


alter table t_request_data
  add constraint t_request_data_fk_req
  foreign key (request) references t_request (name);


alter table t_request_drop
  add constraint t_request_drop_pk
  primary key (request, drop_name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_request_drop
  add constraint t_request_drop_fk_req
  foreign key (request) references t_request (name);


alter table t_request_file
  add constraint t_request_file_pk
  primary key (request, guid)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_request_file
  add constraint t_request_file_fk_req
  foreign key (request) references t_request (name);


alter table t_request_file_status
  add constraint t_request_file_status_pk
  primary key (request, guid, location)
  using index tablesapce CMS_TRANSFERMGMT_INDX01;

alter table t_request_file_status
  add constraint t_request_file_status_fk_req
  foreign key (request) references t_request (name);

----------------------------------------------------------------------
-- Add indices

