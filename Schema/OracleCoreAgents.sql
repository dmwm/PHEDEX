----------------------------------------------------------------------
-- Create sequences

create sequence seq_agent;

----------------------------------------------------------------------
-- Create tables

create table t_agent
  (id			integer		not null,
   name			varchar (100)	not null);

create table t_agent_message
  (node			integer		not null,
   agent		integer		not null,
   message		varchar (20)	not null,
   time_apply		float		not null);

create table t_agent_status
  (node			integer		not null,
   agent		integer		not null,
   state		char (1)	not null,
   time_update		float		not null);

create table t_agent_version
  (node			integer		not null,
   agent		integer		not null,
   time_update		float		not null,
   filename		varchar (100)	not null,
   filesize		integer,
   checksum		varchar (100),
   release		varchar (100),
   revision		varchar (100),
   tag			varchar (100));

----------------------------------------------------------------------
-- Add constraints

alter table t_agent
  add constraint pk_agent
  primary key (id);

alter table t_agent
  add constraint uq_agent_name
  unique (name);


alter table t_agent_message
  add constraint fk_agent_message_node
  foreign key (node) references t_node (id);

alter table t_agent_message
  add constraint fk_agent_message_agent
  foreign key (agent) references t_agent (id);


alter table t_agent_status
  add constraint pk_agent_status
  primary key (node, agent);

alter table t_agent_status
  add constraint fk_agent_status_node
  foreign key (node) references t_node (id);

alter table t_agent_status
  add constraint fk_agent_status_agent
  foreign key (agent) references t_agent (id);


alter table t_agent_version
  add constraint pk_agent_version
  primary key (node, agent, filename);

alter table t_agent_version
  add constraint fk_agent_version_node
  foreign key (node) references t_node (id);

alter table t_agent_version
  add constraint fk_agent_version_agent
  foreign key (agent) references t_agent (id);

----------------------------------------------------------------------
-- Add indices

create index ix_agent_message
  on t_agent_message (node, agent);
