----------------------------------------------------------------------
-- Create tables

/* FIXME: Consider using compressed table here, see
   Tom Kyte's Effective Oracle By Design, chapter 7.
   See also the same chapter, "Compress Auditing or
   Transaction History" for swapping partitions.
   Also test if index-organised table is good. */
create table t_history_link_events
  (timebin		float		not null,
   timewidth		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   -- statistics for timebin period from t_xfer_task
   avail_files		integer, -- became available
   avail_bytes		integer,
   done_files		integer, -- successfully transferred
   done_bytes		integer,
   try_files		integer, -- attempts
   try_bytes		integer,
   fail_files		integer, -- attempts that errored out
   fail_bytes		integer,
   expire_files		integer, -- attempts that expired
   expire_bytes		integer,
   --
   constraint pk_history_link_events
     primary key (timebin, to_node, from_node, priority),
   --
   constraint fk_history_link_events_from
     foreign key (from_node) references t_adm_node (id),
   --
   constraint fk_history_link_events_to
     foreign key (to_node) references t_adm_node (id));


/* FIXME: Consider using compressed table here, see
   Tom Kyte's Effective Oracle By Design, chapter 7.
   See also the same chapter, "Compress Auditing or
   Transaction History" for swapping partitions.
   Also test if index-organised table is good. */
create table t_history_link_stats
  (timebin		float		not null,
   timewidth		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   --
   -- statistics for t_xfer_state during/at end of this timebin
   pend_files		integer, -- all files
   pend_bytes		integer,
   wait_files		integer, -- waiting (not in transfer, error) files
   wait_bytes		integer,
   cool_files		integer, -- cooling off (in error)
   cool_bytes		integer,
   ready_files		integer, -- available for download
   ready_bytes		integer,
   xfer_files		integer, -- in transfer
   xfer_bytes		integer,
   --
   -- statistics for t_xfer_path during/at end of this bin
   confirm_files	integer, -- t_xfer_path
   confirm_bytes	integer,
   confirm_weight	integer,
   -- 
   -- statistics from t_link_param calculated at the end of this cycle
   param_rate		float,
   param_latency	float,
   --
   constraint pk_history_link_stats
     primary key (timebin, to_node, from_node, priority),
   --
   constraint fk_history_link_stats_from
     foreign key (from_node) references t_adm_node (id),
   --
   constraint fk_history_link_stats_to
     foreign key (to_node) references t_adm_node (id));

/* See comments above for t_history_link_*. */
create table t_history_dest
  (timebin		float		not null,
   timewidth		float		not null,
   node			integer		not null,
   dest_files		integer, -- t_dps_block_dest -> files
   dest_bytes		integer,
   src_files		integer, -- t_dps_file.node
   src_bytes		integer,
   node_files		integer, -- t_xfer_replica
   node_bytes		integer,
   request_files	integer, -- t_xfer_request
   request_bytes	integer,
   idle_files		integer,
   idle_bytes		integer,
   --
   constraint pk_history_dest
     primary key (timebin, node),
   --
   constraint fk_history_dest_node
     foreign key (node) references t_adm_node (id));

/* Statistics for block destinations. */
create table t_status_block_dest
  (time_update		float		not null,
   destination		integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_block_dest
     primary key (destination, state),
   --
   constraint fk_status_block_dest_node
     foreign key (destination) references t_adm_node (id)
     on delete cascade);

/* Statistics for file origins. */
create table t_status_file
  (time_update		float		not null,
   node			integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_file
     primary key (node),
   --
   constraint fk_status_file_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

/* Statistics for replicas. */
create table t_status_replica
  (time_update		float		not null,
   node			integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_replica
     primary key (node, state),
   --
   constraint fk_status_replica_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

/* Statistics for transfer requests. */
create table t_status_request
  (time_update		float		not null,
   destination		integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_request
     primary key (destination, state),
   --
   constraint fk_status_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade);

/* Statistics for transfer paths. */
create table t_status_path
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   is_valid		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_path
     primary key (from_node, to_node, priority, is_valid),
   --
   constraint fk_status_path_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_path_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade);

/* Statistics for transfer tasks. */
create table t_status_task
  (time_update		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   --
   constraint pk_status_task
     primary key (from_node, to_node, priority, state),
   --
   constraint fk_status_task_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_task_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade);

/* File size statistics (histogram + overview). */
create table t_status_file_size_overview
  (time_update		float		not null,
   n_files		integer		not null,
   sz_total		integer		not null,
   sz_min		integer		not null,
   sz_max		integer		not null,
   sz_mean		integer		not null,
   sz_median		integer		not null);

create table t_status_file_size_histogram
  (time_update		float		not null,
   bin_low		integer		not null,
   bin_width		integer		not null,
   n_total		integer		not null,
   sz_total		integer		not null);

/* Log for user actions - lifecycle of data at a node
   actions:  0 - request data
             1 - subscribe data
             3 - delete data
*/
create table t_log_user_action
  (time_update		float		not null,
   action		integer		not null,
   identity		integer		not null,
   node			integer		not null,
   dataset		integer,
   block		integer,
   --
   constraint uk_status_user_action
     unique (time_update, action, identity, node, dataset, block),
   --
   constraint fk_status_user_action_identity
     foreign key (identity) references t_adm_identity (id),
   --
   constraint fk_status_user_action_node
     foreign key (node) references t_adm_node (id),
   --
   constraint fk_status_user_action_dataset
     foreign key (dataset) references t_dps_dataset (id),
   --
   constraint fk_status_user_action_block
     foreign key (block) references t_dps_block (id),
   --
   constraint ck_status_user_action_ref
     check (not (block is null and dataset is null)
            and not (block is not null and dataset is not null)));
  
  
   

----------------------------------------------------------------------
-- Create indices

create index ix_history_link_events_from
  on t_history_link_events (from_node);

create index ix_history_link_events_to
  on t_history_link_events (to_node);

--
create index ix_history_link_stats_from
  on t_history_link_stats (from_node);

create index ix_history_link_stats_to
  on t_history_link_stats (to_node);

--
create index ix_history_dest_node
  on t_history_dest (node);

--
create index ix_status_task_to
  on t_status_task (to_node);

--
create index ix_status_path_to
  on t_status_path (to_node);

--
create index ix_log_user_action_identity
  on t_log_user_action (identity);

create index ix_log_user_action_node
  on t_log_user_action (node);

create index ix_log_user_action_dataset
  on t_log_user_action (dataset);

create index ix_log_user_action_block
  on t_log_user_action (block);
