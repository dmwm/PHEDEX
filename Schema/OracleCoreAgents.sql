-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_agents;
drop table t_agent_messages;
drop table t_agent_status;

----------------------------------------------------------------------
-- Create new tables

create table t_agents
  (name			varchar (20)	not null);

create table t_agent_messages
  (timestamp		float		not null,
   node			varchar (20)	not null,
   agent		varchar (20)	not null,
   message		varchar (20)	not null);

create table t_agent_status
  (timestamp		float		not null,
   node			varchar (20)	not null,
   agent		varchar (20)	not null,
   state		char (1)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_agents
  add constraint pk_agents
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_agent_messages
  add constraint fk_agent_messages_node
  foreign key (node) references t_nodes (name);

alter table t_agent_messages
  add constraint fk_agent_messages_agent
  foreign key (agent) references t_agents (name);


alter table t_agent_status
  add constraint pk_agent_status
  primary key (node, agent)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_agent_status
  add constraint fk_agent_status_node
  foreign key (node) references t_nodes (name);

alter table t_agent_status
  add constraint fk_agent_status_agent
  foreign key (agent) references t_agents (name);

----------------------------------------------------------------------
-- Add indices

create index ix_agent_messages
  on t_agent_messages (node, agent)
  tablespace CMS_TRANSFERMGMT_INDX01;
