----------------------------------------------------------------------
-- Create tables

create sequence seq_req_request;
create sequence seq_req_action;
create sequence seq_req_action_attr;

create table t_req_request
  (id			integer		not null,
   name			varchar (1000)	not null,
   creator		integer		not null,
   state		integer		not null);

create table t_req_action
  (id			integer		not null,
   request		integer		not null,
   action		varchar (100)	not null,
   client		integer		not null,
   time_apply		float		not null);

create table t_req_action_attr
  (id			integer		not null,
   action		integer		not null,
   name			varchar (1000)	not null,
   value		varchar (1000));

create table t_req_task
  (id			integer		not null,
   action		integer		not null,
   person		integer		not null,
   time_create		float		not null);

create table t_req_info
  (request		integer		not null,
   time_update		float		not null);

create table t_req_info_dest
  (request		integer		not null,
   destination		integer		not null);

create table t_req_info_dataset
  (request		integer		not null,
   dbs			varchar (1000)	not null,
   dataset		varchar (1000)	not null,
   dbs_isknown		char (1)	not null,
   dps_isknown		char (1)	not null);

create table t_req_info_block
  (request		integer		not null,
   dbs			varchar (1000)	not null,
   dataset		varchar (1000)	not null,
   block		varchar (1000)	not null,
   dbs_isknown		char (1)	not null,
   dps_isknown		char (1)	not null,
   --
   dbs_isopen		char (1),
   dbs_files		integer,
   dbs_bytes		integer,
   dbs_only_files	integer,
   dbs_only_bytes	integer,
   --
   dps_isopen		char (1),
   dps_files		integer,
   dps_bytes		integer,
   dps_only_files	integer,
   dps_only_bytes	integer);

----------------------------------------------------------------------
-- Add constraints

alter table t_req_request
  add constraint pk_req_request
  primary key (id);

alter table t_req_request
  add constraint uq_req_request_name
  unique (name);

alter table t_req_request
  add constraint fk_req_request_creator
  foreign key (creator) references t_adm_client (id);


alter table t_req_action
  add constraint pk_req_action
  primary key (id);

alter table t_req_action
  add constraint fk_req_action_request
  foreign key (request) references t_req_request (id);

alter table t_req_action
  add constraint fk_req_action_client
  foreign key (client) references t_adm_client (id);


alter table t_req_action_attr
  add constraint pk_req_action_attr
  primary key (id);

alter table t_req_action_attr
  add constraint fk_req_action_attr_action
  foreign key (action) references t_req_action (id);


alter table t_req_task
  add constraint pk_req_task
  primary key (id);

alter table t_req_task
  add constraint fk_req_task_action
  foreign key (action) references t_req_action (id);

alter table t_req_task
  add constraint fk_req_task_person
  foreign key (person) references t_adm_identity (id);


alter table t_req_info
  add constraint pk_req_info
  primary key (request);

alter table t_req_info
  add constraint fk_req_info_request
  foreign key (request) references t_req_request (id);


alter table t_req_info_dataset
  add constraint pk_req_info_dataset
  primary key (request, dbs, dataset);

alter table t_req_info_dataset
  add constraint fk_req_info_dataset_req
  foreign key (request) references t_req_request (id);


alter table t_req_info_block
  add constraint pk_req_info_block
  primary key (request, dbs, dataset, block);

alter table t_req_info_block
  add constraint fk_req_info_block_req
  foreign key (request) references t_req_request (id);

----------------------------------------------------------------------
-- Add indices

create index ix_req_request_creator
  on t_req_request (creator);


create index ix_req_action_request
  on t_req_action (request);

create index ix_req_action_client
  on t_req_action (client);


create index ix_req_action_attr_action
  on t_req_action_attr (action);


create index ix_req_task_action
  on t_req_task (action);

create index ix_req_task_person
  on t_req_task (person);
