----------------------------------------------------------------------
-- Create sequences

create sequence seq_node;

----------------------------------------------------------------------
-- Create tables

create table t_node
  (id			integer		not null,
   name			varchar (20)	not null);

create table t_node_neighbour
  (from_node		integer		not null,
   to_node		integer		not null,
   distance		integer		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_node
  add constraint pk_node
  primary key (id)
  using index tablespace INDX01;

alter table t_node
  add constraint uq_node_name
  unique (name);


alter table t_node_neighbour
  add constraint pk_node_neighbour
  primary key (from_node, to_node)
  using index tablespace INDX01;

alter table t_node_neighbour
  add constraint fk_node_neighbour_from
  foreign key (from_node) references t_node (id);

alter table t_node_neighbour
  add constraint fk_node_neighbour_to
  foreign key (to_node) references t_node (id);
