----------------------------------------------------------------------
-- Create sequences

create sequence seq_agent;

----------------------------------------------------------------------
-- Create tables

create table t_agent
  (id			integer		not null,
   name			varchar (100)	not null,
   --
   constraint pk_agent
     primary key (id),
   --
   constraint uq_agent_name
     unique (name));


create table t_agent_message
  (node			integer		not null,
   agent		integer		not null,
   message		varchar (20)	not null,
   time_apply		float		not null,
   --
   constraint fk_agent_message_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_agent_message_agent
     foreign key (agent) references t_agent (id)
     on delete cascade);

/* t_agent_status.state:
 *   1 = agent is up and running
 */
create table t_agent_status
  (node			integer		not null,
   agent		integer		not null,
   label		varchar (100)	not null,
   worker_id		varchar (100)	not null,
   host_name		varchar (100)	not null,
   directory_path	varchar (100)	not null,
   process_id		integer		not null,
   state		char (1)	not null,
   queue_pending	integer		not null,
   queue_received	integer		not null,
   queue_work		integer		not null,
   queue_completed	integer		not null,
   queue_bad		integer		not null,
   queue_outgoing	integer		not null,
   time_update		float		not null,
   --
   constraint pk_agent_status
     primary key (node, agent, label, worker_id),
   --
   constraint fk_agent_status_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_agent_status_agent
     foreign key (agent) references t_agent (id)
     on delete cascade);


create table t_agent_version
  (node			integer		not null,
   agent		integer		not null,
   time_update		float		not null,
   filename		varchar (100)	not null,
   filesize		integer,
   checksum		varchar (100),
   release		varchar (100),
   revision		varchar (100),
   tag			varchar (100),
   --
   constraint pk_agent_version
     primary key (node, agent, filename),
   --
   constraint fk_agent_version_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_agent_version_agent
     foreign key (agent) references t_agent (id)
     on delete cascade);


create table t_agent_log
  (time_update		float		not null,
   reason		varchar (100)	not null,
   user_name		varchar (100)	not null,
   host_name		varchar (100)	not null,
   process_id		integer		not null,
   working_directory	varchar (200)	not null,
   state_directory	varchar (200)	not null,
   message		clob		not null);

----------------------------------------------------------------------
-- Create indices

create index ix_agent_message
  on t_agent_message (node, agent);

create index ix_agent_message_agent
  on t_agent_message (agent);

create index ix_agent_status_agent
  on t_agent_status (agent);

create index ix_agent_version_agent
  on t_agent_version (agent);
