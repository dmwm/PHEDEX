----------------------------------------------------------------------
-- Create tables

create table t_info_xfer_tasks
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   from_state		integer		not null,
   to_state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_info_xfer_tasks
     primary key (from_node, to_node, from_state, to_state),
   --
   constraint fk_info_xfer_tasks_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_info_xfer_tasks_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade);


create table t_info_xfer_replicas
  (time_update		float		not null,
   node			integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_info_xfer_replicas
     primary key (node, state),
   --
   constraint fk_info_xfer_replicas_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

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

----------------------------------------------------------------------
-- Create indices

create index ix_info_xfer_tasks_to
  on t_info_xfer_tasks (to_node);
