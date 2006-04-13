----------------------------------------------------------------------
-- Create sequences

create sequence seq_node;
create sequence seq_link;

----------------------------------------------------------------------
-- Create tables

create table t_node
  (id			integer		not null,
   name			varchar (20)	not null,
   bandwidth_cap	integer);

create table t_link
  (id			integer		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   distance		integer		not null,
   local_boost		integer		not null,
   bandwidth_cap	integer);

create table t_link_share
  (link			integer		not null,
   priority		integer		not null,
   share		integer		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_node
  add constraint pk_node
  primary key (id):

alter table t_node
  add constraint uq_node_name
  unique (name);

--
alter table t_link
  add constraint pk_link
  primary key (id);

alter table t_link
  add constraint uq_link_key
  unique (from_node, to_node);

alter table t_link
  add constraint fk_link_from
  foreign key (from_node) references t_node (id);

alter table t_link
  add constraint fk_link_to
  foreign key (to_node) references t_node (id);

--
alter table t_link_share
  add constraint pk_link_share
  primary key (link, priority);

alter table t_link_share
  add constraint fk_link_share_from
  foreign key (link) references t_link (id);
