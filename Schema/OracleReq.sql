--  as cms_transfermgmt

drop table t_request_file_status;
drop table t_request_file;
drop table t_request_drop;
drop table t_request_data;
drop table t_request_subscription;
drop table t_request_operation;
drop table t_request;

create table t_request
  (request_name		varchar (100)	not null);

create table t_request_operation
  (request_name		varchar (100)	not null,
   time_stamp		float		not null,
   identity		varchar (100)	not null,
   operation		varchar (20)	not null);

create table t_request_subscription
  (request_name		varchar (100)	not null,
   time_stamp		float		not null,
   operation		varchar (20)	not null,
   destination		varchar (20));

create table t_request_data
  (request_name		varchar (100)	not null,
   time_stamp		float		not null,
   operation		varchar (20)	not null,
   selection		varchar (1000));

create table t_request_drop
  (request_name		varchar (100)	not null,
   drop_name		varchar (100)	not null,
   drop_category	varchar (20)	not null);

create table t_request_file
  (request_name		varchar (100)	not null,
   guid			char (36)	not null,
   drop_name		varchar (100)	not null);

create table t_request_file_status
  (request_name		varchar (100)	not null,
   guid			char (36)	not null,
   location		varchar (20)	not null,
   is_available		char (1)	not null,
   is_pending		char (1)	not null,
   is_transferred	char (1)	not null);

alter table t_request
  add constraint t_request_pk primary key (request_name)
  -- using index tablespace INDX01;
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_request_operation
  add constraint t_request_operation_fk_req
  foreign key (request_name) references t_request (request_name);

alter table t_request_subscription
  add constraint t_request_subscription_fk_req
  foreign key (request_name) references t_request (request_name);

alter table t_request_data
  add constraint t_request_data_fk_req
  foreign key (request_name) references t_request (request_name);

alter table t_request_drop
  add constraint t_request_drop_pk
  primary key (request_name, drop_name)
  -- using index tablespace INDX01;
  using index tablespace CMS_TRANSFERMGMT_INDX01;
alter table t_request_drop
  add constraint t_request_drop_fk_req
  foreign key (request_name) references t_request (request_name);

alter table t_request_file
  add constraint t_request_file_pk
  primary key (request_name, guid)
  -- using index tablespace INDX01;
  using index tablespace CMS_TRANSFERMGMT_INDX01;
alter table t_request_file
  add constraint t_request_file_fk_req
  foreign key (request_name) references t_request (request_name);

alter table t_request_file_status
  add constraint t_request_file_status_pk
  primary key (request_name, guid, location)
  -- using index tablespace INDX01;
  using index tablesapce CMS_TRANSFERMGMT_INDX01;
alter table t_request_file_status
  add constraint t_request_file_status_fk_req
  foreign key (request_name) references t_request (request_name);

commit;

grant select on t_request		to cms_transfermgmt_reader;
grant select on t_request_operation	to cms_transfermgmt_reader;
grant select on t_request_subscription	to cms_transfermgmt_reader;
grant select on t_request_data		to cms_transfermgmt_reader;
grant select on t_request_drop		to cms_transfermgmt_reader;
grant select on t_request_file		to cms_transfermgmt_reader;
grant select on t_request_file_status	to cms_transfermgmt_reader;

grant alter, delete, insert, select, update on t_request		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_operation	to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_subscription	to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_data		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_drop		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_file		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_request_file_status	to cms_transfermgmt_writer;

--  as cms_transfermgmt_reader and cms_transfermgmt_writer
create synonym t_request		for cms_transfermgmt.t_request;
create synonym t_request_operation	for cms_transfermgmt.t_request_operation;
create synonym t_request_subscription	for cms_transfermgmt.t_request_subscription;
create synonym t_request_data		for cms_transfermgmt.t_request_data;
create synonym t_request_drop		for cms_transfermgmt.t_request_drop;
create synonym t_request_file		for cms_transfermgmt.t_request_file;
create synonym t_request_file_status	for cms_transfermgmt.t_request_file_status;
