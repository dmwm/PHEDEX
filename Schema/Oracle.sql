-- create primary key into index tablespace
-- create indices for foreign keys, otherwise locks entire table on update
-- index/hash organised table (iot) for t_routing, t_replica_state?
-- www.cern.ch/it-db -> Oracle @ CERN -> Sessions -> pdb01/cms -> login
-- explain plan for ...
-- @?/rdbms/admin/utilxpls.sql
-- desc dbms_stats (in oradoc)
-- analyze
-- set timing on
-- oradoc.cern.ch
-- sqlplus / l / 16 / del / &foo
-- create trigger for transfer history






--  as cms_transfermgmt

create table t_nodes
	(node_name		varchar (20)	not null,
	 host_string		varchar (50),
	 catalogue_contact	varchar (1000),
	 primary key		(node_name));

-- create table t_nodes
--         (node_name              varchar (20)    not null,
--         host_string            varchar (50),
--          catalogue_contact      varchar (1000);
-- ALTERTTABLE T_NODES ADD CONSTRAINT T_NODE_PK PRIMARY KEY (NODE_NAME) TABLESPACE XXXX;

create table t_routing
	(from_node		varchar (20)	not null,
	 to_node		varchar (20)	not null,
	 gateway		varchar (20)	not null,
	 timestamp		integer		not null,
	 hops			integer		not null,
	 primary key		(from_node, to_node),
	 foreign key		(from_node) references t_nodes (node_name),
	 foreign key		(to_node) references t_nodes (node_name),
	 foreign key		(gateway) references t_nodes (node_name));

create table t_agents
	(name			varchar (20)	not null,
	 primary key		(name));
create table t_config_messages
	(node			varchar (20)	not null,
	 message		varchar (20)	not null,
	 timestamp		integer		not null,
	 foreign key		(node) references t_nodes (node_name));
create table t_lookup
	(node			varchar (20)	not null,
	 agent			varchar (20)	not null,
	 state			char (1)	not null,
	 last_contact		integer		not null,
	 primary key		(node, agent),
	 foreign key		(node) references t_nodes (node_name),
	 foreign key		(agent) references t_agents (name));

create table t_files_for_transfer
	(guid			char (36)	not null,
	 source_node		varchar (20)	not null,
	 primary key		(guid),
	 foreign key		(source_node) references t_nodes (node_name));
create table t_replica_metadata
	(guid			char (36)	not null,
	 attribute		varchar (1000)	not null,
	 value			varchar (1000),
	 primary key		(guid, attribute),
	 foreign key		(guid) references t_files_for_transfer (guid));
create table t_subscriptions
	(destination		varchar (20),
	 stream			varchar (1000)	not null);
create table t_destinations
	(guid			char (36)	not null,
	 destination_node	varchar (20)	not null,
	 time_stamp		integer		not null,
	 primary key		(guid, destination_node),
	 foreign key		(guid) references t_files_for_transfer (guid),
	 foreign key		(destination_node) references t_nodes (node_name));

create table t_replica_state
	(guid			char (36)	not null,
	 node			varchar (20)	not null,
	 insert_time_stamp	integer		not null,
	 state			integer		not null,
	 time_stamp		integer		not null,
	 local_state		integer		not null,
	 local_time_stamp	integer		not null,
	 primary key		(guid, node),
	 foreign key		(guid) references t_files_for_transfer (guid),
	 foreign key		(node) references t_nodes (node_name));
create table t_transfer_state
	(guid			char (36)	not null,
	 from_node		varchar (20)	not null,
	 to_node		varchar (20)	not null,
	 from_state		integer		not null,
	 to_state		integer		not null,
	 from_time_stamp	integer		not null,
	 to_time_stamp		integer		not null,
	 insert_time_stamp	integer		not null,
	 primary key		(guid, to_node),
	 foreign key		(guid) references t_files_for_transfer (guid),
	 foreign key		(from_node) references t_nodes (node_name),
	 foreign key		(to_node) references t_nodes (node_name));
create table t_transfer_history
	(guid			char(36)	not null,
	 from_node		varchar(20)	not null,
	 to_node		varchar(20)	not null,
	 old_state		integer		not null,
	 new_state		integer		not null,
	 delta			float		not null,
	 time			integer		not null,
	 foreign key		(guid) references t_files_for_transfer (guid),
	 foreign key		(from_node) references t_nodes (node_name),
	 foreign key		(to_node) references t_nodes (node_name));

commit;

grant select on t_agents		to cms_transfermgmt_reader;
grant select on t_config_messages	to cms_transfermgmt_reader;
grant select on t_destinations		to cms_transfermgmt_reader;
grant select on t_files_for_transfer	to cms_transfermgmt_reader;
grant select on t_lookup		to cms_transfermgmt_reader;
grant select on t_nodes			to cms_transfermgmt_reader;
grant select on t_replica_metadata	to cms_transfermgmt_reader;
grant select on t_replica_state		to cms_transfermgmt_reader;
grant select on t_routing		to cms_transfermgmt_reader;
grant select on t_subscriptions		to cms_transfermgmt_reader;
grant select on t_transfer_state	to cms_transfermgmt_reader;
grant select on t_transfer_history	to cms_transfermgmt_reader;

grant alter, delete, insert, select, update on t_agents			to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_config_messages	to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_destinations		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_files_for_transfer	to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_lookup			to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_nodes			to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_replica_metadata	to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_replica_state		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_routing		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_subscriptions		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_transfer_state		to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_transfer_history	to cms_transfermgmt_writer;

--  as cms_transfermgmt_reader and cms_transfermgmt_writer

create synonym t_agents			for cms_transfermgmt.t_agents;
create synonym t_config_messsages	for cms_transfermgmt.t_config_messages;
create synonym t_destinations		for cms_transfermgmt.t_destinations;
create synonym t_files_for_transfer	for cms_transfermgmt.t_files_for_transfer;
create synonym t_lookup			for cms_transfermgmt.t_lookup;
create synonym t_nodes			for cms_transfermgmt.t_nodes;
create synonym t_replica_metadata	for cms_transfermgmt.t_replica_metadata;
create synonym t_replica_state		for cms_transfermgmt.t_replica_state;
create synonym t_routing		for cms_transfermgmt.t_routing;
create synonym t_subscriptions		for cms_transfermgmt.t_subscriptions;
create synonym t_transfer_state		for cms_transfermgmt.t_transfer_state;
create synonym t_transfer_history	for cms_transfermgmt.t_transfer_history;
