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
  (from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   gateway		varchar (20)	not null,
   hops			integer		not null,
   timestamp		float		not null);

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
  add constraint t_nodes_pk
  primary key (name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;


alter table t_routing
  add constraint t_routing_pk
  primary key (from_node, to_node)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_routing
  add constraint t_routing_fk_from_node
  foreign key (from_node) references t_nodes (name);

alter table t_routing
  add constraint t_routing_fk_to_node
  foreign key (to_node) references t_nodes (name);

alter table t_routing
  add constraint t_routing_fk_gateway
  foreign key (gateway) references t_nodes (name);


alter table t_node_imports
  add constraint t_node_imports_pk
  primary key (node, protocol)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_node_imports
  add constraint t_node_imports_fk_node
  foreign key (node) references t_nodes (name);


alter table t_node_exports
  add constraint t_node_exports_pk
  primary key (node, protocol)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

alter table t_node_exports
  add constraint t_node_exports_fk_node
  foreign key (node) references t_nodes (name);

----------------------------------------------------------------------
-- Add indices

create index t_routing_ix_gateway
  on t_routing (gateway)
  tablespace CMS_TRANSFERMGMT_INDX01;
