----------------------------------------------------------------------
-- Create sequences

create sequence seq_xfer_replica;
create sequence seq_xfer_task;

----------------------------------------------------------------------
-- Create tables

create table t_xfer_catalogue
  (node			integer		not null,
   rule_index		integer		not null,
   rule_type		varchar (10)	not null,
   protocol		varchar (20)	not null,
   path_match		varchar (1000)	not null,
   result_expr		varchar (1000)	not null,
   chain		varchar (20),
   destination_match	varchar (40),
   --
   constraint pk_xfer_catalogue
     primary key (node, rule_index),
   --
   constraint fk_xfer_catalogue_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_xfer_catalogue_type
     check (rule_type in ('lfn-to-pfn', 'pfn-to-lfn')));

create table t_xfer_source
  (from_node		integer		not null,
   to_node		integer		not null,
   protocols		varchar (1000)	not null,
   time_update		float		not null,
   --
   constraint pk_xfer_source
     primary key (from_node, to_node),
   --
   constraint fk_xfer_source_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_source_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade);

create table t_xfer_sink
  (from_node		integer		not null,
   to_node		integer		not null,
   protocols		varchar (1000)	not null,
   time_update		float		not null,
   --
   constraint pk_xfer_sink
     primary key (from_node, to_node),
   --
   constraint fk_xfer_sink_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_sink_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade);

create table t_xfer_delete
  (fileid		integer		not null,  -- for which file
   node			integer		not null,  -- at which node
   time_request		float		not null,  -- time at request
   time_complete	float		not null,  -- time at completed
   --
   constraint pk_xfer_delete
     primary key (fileid, node),
   --
   constraint fk_xfer_delete_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_delete_node
     foreign key (node) references t_adm_node (id)
     on delete cascade)
 enable row movement;

-- priority in block destination and file request, confirmation:
--   0 = "now", 1 = "as soon as you can", 2 = "whenever you can"

-- priority in transfers: (priority-level) * 2 + (for-me ? 1 : 0)
--   0 = now, destined for my site
--   1 = now, destined for someone else
--   2 = quicky, destined for my site
--   :

create table t_xfer_replica
  (id			integer		not null,
   node			integer		not null,
   fileid		integer		not null,
   state		integer		not null,
   time_create		float		not null,
   time_state		float		not null,
   --
   constraint pk_xfer_replica
     primary key (id),
   --
   constraint uq_xfer_replica_key
     unique (node, fileid),
   --
   constraint fk_xfer_replica_node
     foreign key (node) references t_adm_node (id),
   --
   constraint fk_xfer_replica_fileid
     foreign key (fileid) references t_xfer_file (id))
  --
  partition by list (node)
    (partition node_dummy values (-1))
  enable row movement;

create table t_xfer_request
  (fileid		integer		not null,
   inblock		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   state		integer		not null,
   attempt		integer		not null,
   time_create		float		not null,
   time_expire		float		not null,
   --
   constraint pk_xfer_request
     primary key (destination, fileid),
   --
   constraint fk_xfer_request_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_request_inblock
     foreign key (inblock) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_xfer_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade)
  --
  partition by list (destination)
    (partition dest_dummy values (-1))
  enable row movement;

create table t_xfer_path
  (destination		integer		not null,  -- final destination
   fileid		integer		not null,  -- for which file
   hop			integer		not null,  -- hop from destination
   src_node		integer		not null,  -- original replica owner
   from_node		integer		not null,  -- from which node
   to_node		integer		not null,  -- to which node
   priority		integer		not null,  -- priority
   is_local		integer		not null,  -- local transfer priority
   is_valid		integer		not null,  -- route is acceptable
   cost			float		not null,  -- hop cost
   total_cost		float		not null,  -- total path cost
   penalty		float		not null,  -- path penalty
   time_request		float		not null,  -- request creation time
   time_confirm		float		not null,  -- last path build time
   time_expire		float		not null,  -- request expiry time
   --
   constraint pk_xfer_path
     primary key (destination, fileid, hop),
   --
   constraint fk_xfer_path_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_path_src
     foreign key (src_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade)
  --
  partition by list (to_node)
    (partition to_dummy values (-1))
  enable row movement;

create table t_xfer_newpath as select * from t_xfer_path where 1=0;

/* FIXME: Consider using clustered table for t_xfer_task*, see
   Tom Kyte's Effective Oracle by Design, chapter 7. */
create table t_xfer_task
  (id			integer		not null, -- xfer id
   fileid		integer		not null, -- xref t_xfer_file
   from_replica		integer		not null, -- xref t_xfer_replica
   priority		integer		not null, -- see at the top
   rank			integer		not null, -- current order rank
   from_node		integer		not null, -- node transfer is from
   to_node		integer		not null, -- node transfer is to
   from_pfn		varchar (1000)	not null, -- source pfn
   to_pfn		varchar (1000)	not null, -- destination pfn
   time_expire		float		not null, -- time when expires
   time_assign		float		not null, -- time created
   --
   constraint pk_xfer_task
     primary key (id),
   --
   constraint uq_xfer_task_key
     unique (to_node, fileid),
   --
   constraint fk_xfer_task_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_task_replica
     foreign key (from_replica) references t_xfer_replica (id),
   --
   constraint fk_xfer_task_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_task_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade)
  --
  partition by list (to_node)
    (partition to_dummy values (-1))
  enable row movement;

create table t_xfer_task_export
  (task			integer		not null,
   time_update		float		not null,
   --
   constraint pk_xfer_task_export
     primary key (task),
   --
   constraint fk_xfer_task_export_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade)
  --
  organization index;

create table t_xfer_task_inxfer
  (task			integer		not null,
   time_update		float		not null,
   --
   constraint pk_xfer_task_inxfer
     primary key (task),
   --
   constraint fk_xfer_task_inxfer_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade)
  --
  organization index
  /* enable row movement */;

create table t_xfer_task_done
  (task			integer		not null,
   report_code		integer		not null,
   xfer_code		integer		not null,
   time_update		float		not null,
   is_done		char(1)		not null,
   --
   constraint pk_xfer_task_done
     primary key (task),
   --
   constraint fk_xfer_task_done_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade)
  --
  organization index;

create table t_xfer_task_harvest
  (task			integer		not null,
   --
   constraint pk_xfer_task_harvest
     primary key (task),
   --
   constraint fk_xfer_task_harvest_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade)
  --
  organization index;

create table t_xfer_error
  (to_node		integer		not null, -- node transfer is to
   from_node		integer		not null, -- node transfer is from
   fileid		integer		not null, -- xref t_xfer_file
   priority		integer		not null, -- see at the top
   time_assign		float		not null, -- time created
   time_expire		float		not null, -- time will expire
   time_export		float		not null, -- time exported
   time_inxfer		float		not null, -- time taken into transfer
   time_done		float		not null, -- time completed
   report_code		integer		not null, -- final report code
   xfer_code		integer		not null, -- transfer report code
   from_pfn		varchar (1000)	not null, -- source pfn
   to_pfn		varchar (1000)	not null, -- destination pfn
   log_xfer		clob,
   log_detail		clob,
   log_validate		clob,
   --
   constraint fk_xfer_export_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_export_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_export_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade)
  --
  partition by list (to_node)
    (partition to_dummy values (-1))
  enable row movement;

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

----------------------------------------------------------------------
-- Create indices

create index ix_xfer_source_to
  on t_xfer_source (to_node);

--
create index ix_xfer_sink_to
  on t_xfer_sink (to_node);

--
create index ix_xfer_delete_node
  on t_xfer_delete (node);

--
create index ix_xfer_replica_fileid
  on t_xfer_replica (fileid);

--
create index ix_xfer_request_inblock
  on t_xfer_request (inblock);

create index ix_xfer_request_fileid
  on t_xfer_request (fileid);

--
create index ix_xfer_path_fileid
  on t_xfer_path (fileid);

create index ix_xfer_path_to
  on t_xfer_path (to_node)
  local;

create index ix_xfer_path_src
  on t_xfer_path (src_node);

create index ix_xfer_path_from
  on t_xfer_path (from_node);

create index ix_xfer_path_tofile
  on t_xfer_path (to_node, fileid)
  local;

/*
create index ix_xfer_path_srcfrom
  on t_xfer_path (src_node, from_node);

create index ix_xfer_path_valid
  on t_xfer_path (is_valid);
*/

--
create index ix_xfer_task_from_node
  on t_xfer_task (from_node);

create index ix_xfer_task_to_node
  on t_xfer_task (to_node);

create index ix_xfer_task_from_replica
  on t_xfer_task (from_replica);

create index ix_xfer_task_fileid
  on t_xfer_task (fileid);

--
create index ix_xfer_error_from_node
  on t_xfer_error (from_node);

create index ix_xfer_error_to_node
  on t_xfer_error (to_node)
  local;

create index ix_xfer_error_fileid
  on t_xfer_error (fileid);

--
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
