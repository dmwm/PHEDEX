-- PhEDEx ORACLE schema for agent operations.
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Create new tables

create table t_agent
  (name			varchar (20)	not null);

create table t_agent_message
  (timestamp		float		not null,
   node			varchar (20)	not null,
   agent		varchar (20)	not null,
   message		varchar (20)	not null);

create table t_agent_status
  (timestamp		float		not null,
   node			varchar (20)	not null,
   agent		varchar (20)	not null,
   state		char (1)	not null);

create table t_agent_version
  (timestamp		float		not null,
   node			varchar (20)	not null,
   agent		varchar (20)	not null,
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
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_agent_message
  add constraint fk_agent_message_node
  foreign key (node) references t_node (name);

alter table t_agent_message
  add constraint fk_agent_message_agent
  foreign key (agent) references t_agent (name);


alter table t_agent_status
  add constraint pk_agent_status
  primary key (node, agent)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_agent_status
  add constraint fk_agent_status_node
  foreign key (node) references t_node (name);

alter table t_agent_status
  add constraint fk_agent_status_agent
  foreign key (agent) references t_agent (name);


alter table t_agent_version
  add constraint pk_agent_version
  primary key (node, agent, filename)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_agent_version
  add constraint fk_agent_version_node
  foreign key (node) references t_node (name);

alter table t_agent_version
  add constraint fk_agent_version_agent
  foreign key (agent) references t_agent (name);

----------------------------------------------------------------------
-- Add indices

create index ix_agent_message
  on t_agent_message (node, agent)
  tablespace CMS_TRANSFERMGMT_INDX01;
