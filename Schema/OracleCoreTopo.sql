-- PhEDEx ORACLE schema for core transfer topology.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: None.

----------------------------------------------------------------------
-- Drop old tables

drop table t_node;
drop table t_node_import;
drop table t_node_export;
drop table t_routing;

----------------------------------------------------------------------
-- Create new tables

create table t_node
  (name			varchar (20)	not null);

create table t_routing
  (timestamp		float		not null,
   from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   gateway		varchar (20)	not null,
   hops			integer		not null);

create table t_node_import
  (node			varchar (20)	not null,
   protocol		varchar (20)	not null,
   priority		integer		not null);

create table t_node_export
  (node			varchar (20)	not null,
   protocol		varchar (20)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_node
  add constraint pk_node
  primary key (name)
  using index tablespace INDX01;


alter table t_routing
  add constraint pk_routing
  primary key (from_node, to_node)
  using index tablespace INDX01;

alter table t_routing
  add constraint fk_routing_from_node
  foreign key (from_node) references t_node (name);

alter table t_routing
  add constraint fk_routing_to_node
  foreign key (to_node) references t_node (name);

alter table t_routing
  add constraint fk_routing_gateway
  foreign key (gateway) references t_node (name);


alter table t_node_import
  add constraint pk_node_import
  primary key (node, protocol)
  using index tablespace INDX01;

alter table t_node_import
  add constraint fk_node_import_node
  foreign key (node) references t_node (name);


alter table t_node_export
  add constraint pk_node_export
  primary key (node, protocol)
  using index tablespace INDX01;

alter table t_node_export
  add constraint fk_node_export_node
  foreign key (node) references t_node (name);

----------------------------------------------------------------------
-- Add indices

create index ix_routing_gateway
  on t_routing (gateway)
  tablespace INDX01;
