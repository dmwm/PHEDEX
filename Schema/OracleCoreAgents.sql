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
  (node			varchar (20)	not null,
   agent		varchar (20)	not null,
   message		varchar (20)	not null,
   timestamp		float		not null);

create table t_agent_status
  (node			varchar (20)	not null,
   agent		varchar (20)	not null,
   state		char (1)	not null,
   timestamp		float		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_agents
  add constraint t_agents_pk
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_agent_messages
  add constraint t_agent_messages_fk_node
  foreign key (node) references t_nodes (name);

alter table t_agent_messages
  add constraint t_agent_messages_fk_agent
  foreign key (agent) references t_agents (name);


alter table t_agent_status
  add constraint t_agent_status_pk
  primary key (node, agent)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_agent_status
  add constraint t_agent_status_fk_node
  foreign key (node) references t_nodes (name);

alter table t_agent_status
  add constraint t_agent_status_fk_agent
  foreign key (agent) references t_agents (name);

----------------------------------------------------------------------
-- Add indices

