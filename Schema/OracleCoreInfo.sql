----------------------------------------------------------------------
-- Create tables

create table t_info_xfer_states
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   from_state		integer		not null,
   to_state		integer		not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_info_xfer_replicas
  (time_update		float		not null,
   node			integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_info_file_size_overview
  (time_update		float		not null,
   n_files		integer		not null,
   sz_total		integer		not null,
   sz_min		integer		not null,
   sz_max		integer		not null,
   sz_mean		integer		not null,
   sz_median		integer		not null);

create table t_info_file_size_histogram
  (time_update		float		not null,
   bin_low		integer		not null,
   bin_width		integer		not null,
   n_total		integer		not null,
   sz_total		integer		not null);

create table t_info_agent_status
  (time_update		float		not null,
   site			varchar (20)	not null,
   host			varchar (40)	not null,
   path			varchar (255)	not null,
   agent		varchar (20)	not null,
   worker		varchar (20)	not null,
   pid			integer		not null,
   live			char (1)	not null,
   state		varchar (20)	not null,
   value		integer		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_info_xfer_states
  add constraint pk_info_xfer_states
  primary key (from_node, to_node, from_state, to_state);

alter table t_info_xfer_states
  add constraint fk_info_xfer_states_from
  foreign key (from_node) references t_node (id);

alter table t_info_xfer_states
  add constraint fk_info_xfer_states_to
  foreign key (to_node) references t_node (id);


alter table t_info_xfer_replicas
  add constraint pk_info_xfer_replicas
  primary key (node, state);

alter table t_info_xfer_replicas
  add constraint fk_info_xfer_replicas_node
  foreign key (node) references t_node (id);
