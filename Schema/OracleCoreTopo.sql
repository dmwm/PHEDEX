-- PhEDEx ORACLE schema for core transfer topology.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: None.

----------------------------------------------------------------------
-- Drop old tables

drop table t_nodes;
drop table t_node_imports;
drop table t_node_exports;
drop table t_routing;

----------------------------------------------------------------------
-- Create new tables

create table t_nodes
  (name			varchar (20)	not null);

create table t_routing
  (timestamp		float		not null,
   from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   gateway		varchar (20)	not null,
   hops			integer		not null);

create table t_node_imports
  (node			varchar (20)	not null,
   protocol		varchar (20)	not null,
   priority		integer		not null);

create table t_node_exports
  (node			varchar (20)	not null,
   protocol		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_nodes
  add constraint pk_nodes
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_routing
  add constraint pk_routing
  primary key (from_node, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_routing
  add constraint fk_routing_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_routing
  add constraint fk_routing_to_node
  foreign key (to_node) references t_nodes (name);

alter table t_routing
  add constraint fk_routing_gateway
  foreign key (gateway) references t_nodes (name);


alter table t_node_imports
  add constraint pk_node_imports
  primary key (node, protocol)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_node_imports
  add constraint fk_node_imports_node
  foreign key (node) references t_nodes (name);


alter table t_node_exports
  add constraint pk_node_exports
  primary key (node, protocol)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_node_exports
  add constraint fk_node_exports_node
  foreign key (node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

create index ix_routing_gateway
  on t_routing (gateway)
  tablespace CMS_TRANSFERMGMT_INDX01;
