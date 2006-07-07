----------------------------------------------------------------------
-- Create sequences

create sequence seq_xfer_replica;

----------------------------------------------------------------------
-- Create tables

-- priority in block destination and file request, confirmation:
--   0 = "now", 1 = "as soon as you can", 2 = "whenever you can"

-- priority in transfers: (priority-level) * 2 + (for-me ? 1 : 0)
--   0 = now, destined for my site
--   1 = now, destined for someone else
--   2 = quicky, destined for my site
--   :

create table t_xfer_replica
  (id			integer		not null,
   fileid		integer		not null,
   node			integer		not null,
   state		integer		not null,
   time_create		float		not null,
   time_state		float		not null)
  partition by list (node)
  (partition node_dummy values (-1))
  initrans 8;

create table t_xfer_request
  (fileid		integer		not null,
   inblock		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   state		integer		not null,
   attempt		integer		not null,
   time_create		float		not null,
   time_expire		float		not null)
  partition by list (destination)
  (partition dest_dummy values (-1))
  initrans 8;

create table t_xfer_path
  (destination		integer		not null,  -- final destination
   fileid		integer		not null,  -- for which file
   hop			integer		not null,  -- hop from destination
   src_node		integer		not null,  -- original replica owner
   from_node		integer		not null,  -- from which node
   to_node		integer		not null,  -- to which node
   priority		integer		not null,  -- priority
   local_boost		integer		not null,  -- local transfer priority
   cost			float		not null,  -- hop cost
   total_cost		float		not null,  -- total path cost
   penalty		float		not null,  -- path penalty
   time_request		float		not null,  -- request creation time
   time_confirm		float		not null,  -- last path build time
   time_expire		float		not null)  -- request expiry time
  initrans 8;

create table t_xfer_state
  (fileid		integer		not null, -- file
   errors		integer		not null, -- errors so far
   priority		integer		not null, -- see at the top
   weight		integer		not null, -- see t_xfer_confirmation
   age			float		not null, -- earliest activated confirm
   --
   from_replica		integer		not null, -- xref t_xfer_replica
   from_node		integer		not null, -- node transfer is from
   from_state		integer		not null, -- state at source
   --
   to_node		integer		not null, -- node transfer is to
   to_state		integer		not null, -- state at destination
   --
   to_protocols		varchar (1000),		  -- protocols accepted
   to_pfn		varchar (1000),		  -- destination pfn
   from_pfn		varchar (1000),		  -- source pfn
   last_error		varchar (4000),		  -- last error message
   --
   time_expire		float,			  -- time when expires
   time_assign		float,			  -- time created
   time_request		float,			  -- time first wanted
   time_available	float,			  -- time exported
   time_xfer_start	float,			  -- time last xfer started
   time_xfer_end	float,			  -- time last xfer ended
   time_error_total	float,			  -- time in error state
   time_error_start	float,			  -- time last entered error
   time_error_end	float)			  -- time to exit error state
  partition by list (from_node)
  (partition from_dummy values (-1))
  initrans 8;

create table t_xfer_tracking
  (timestamp		float		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   priority		integer		not null,
   fileid		integer		not null,
   is_avail		integer		not null,
   is_try		integer		not null,
   is_done		integer		not null,
   is_fail		integer		not null,
   is_expire		integer		not null)
  initrans 8;

create table t_xfer_delete
  (fileid		integer		not null,  -- for which file
   node			integer		not null,  -- at which node
   time_request		float		not null,  -- time at request
   time_complete	float		not null   /* time at completed */);

create table t_link_histogram
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
   -- statistics for timebin period from t_xfer_tracking
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
   -- statistics for t_xfer_path during/at end of this bin
   confirm_files	integer, -- t_xfer_path
   confirm_bytes	integer,
   confirm_weight	integer,
   -- 
   -- statistics from t_link_param calculated at the end of this cycle
   param_rate		float,
   param_latency	float);

create table t_dest_histogram
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
   idle_bytes		integer);

-- FIXME: expand on this for everything that defines the value
create table t_link_param
  (link			integer		not null,
   time_update		float		not null,
   time_span		integer,
   pend_bytes		float,
   done_bytes		float,
   try_bytes		float,
   xfer_rate		float,
   xfer_latency		float);

----------------------------------------------------------------------
-- Add constraints

alter table t_xfer_replica
  add constraint pk_xfer_replica
  primary key (id);

alter table t_xfer_replica
  add constraint uq_xfer_replica
  unique (node, fileid);

alter table t_xfer_replica
  add constraint fk_xfer_replica_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_replica
  add constraint fk_xfer_replica_node
  foreign key (node) references t_node (id);


alter table t_xfer_request
  add constraint pk_xfer_request
  primary key (destination, fileid);

alter table t_xfer_request
  add constraint fk_xfer_request_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_request
  add constraint fk_xfer_request_inblock
  foreign key (inblock) references t_dps_block (id);

alter table t_xfer_request
  add constraint fk_xfer_request_dest
  foreign key (destination) references t_node (id);


alter table t_xfer_path
  add constraint pk_xfer_path
  primary key (destination, fileid, hop);

alter table t_xfer_path
  add constraint fk_xfer_path_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_path
  add constraint fk_xfer_path_dest
  foreign key (destination) references t_node (id);

alter table t_xfer_path
  add constraint fk_xfer_path_src
  foreign key (src_node) references t_node (id);

alter table t_xfer_path
  add constraint fk_xfer_path_from
  foreign key (from_node) references t_node (id);

alter table t_xfer_path
  add constraint fk_xfer_path_to
  foreign key (to_node) references t_node (id);


alter table t_xfer_state
  add constraint pk_xfer_state
  primary key (to_node, fileid);

alter table t_xfer_state
  add constraint fk_xfer_state_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_state
  add constraint fk_xfer_state_replica
  foreign key (from_replica) references t_xfer_replica (id);

alter table t_xfer_state
  add constraint fk_xfer_state_from
  foreign key (from_node) references t_node (id);

alter table t_xfer_state
  add constraint fk_xfer_state_to
  foreign key (to_node) references t_node (id);


alter table t_xfer_tracking
  add constraint fk_xfer_tracking_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_tracking
  add constraint fk_xfer_tracking_from
  foreign key (from_node) references t_node (id);

alter table t_xfer_tracking
  add constraint fk_xfer_tracking_to
  foreign key (to_node) references t_node (id);


alter table t_link_histogram
  add constraint pk_link_histogram
  primary key (timebin, to_node, from_node, priority);

alter table t_link_histogram
  add constraint fk_link_histogram_from
  foreign key (from_node) references t_node (id);

alter table t_link_histogram
  add constraint fk_link_histogram_to
  foreign key (to_node) references t_node (id);


alter table t_dest_histogram
  add constraint pk_dest_histogram
  primary key (timebin, node);

alter table t_dest_histogram
  add constraint fk_dest_histogram_node
  foreign key (node) references t_node (id);

alter table t_link_param
  add constraint pk_link_param
  primary key (link);

alter table t_link_param
  add constraint fk_link_param_link
  foreign key (link) references t_link (id);

----------------------------------------------------------------------
-- Add indices

create index ix_xfer_request_inblock
  on t_xfer_request (inblock);

--
create index ix_xfer_path_to
  on t_xfer_path (to_node);

create index ix_xfer_path_tofile
  on t_xfer_path (to_node, fileid);

create index ix_xfer_path_srcfrom
  on t_xfer_path (src_node, from_node);

--
create index ix_xfer_state_from_node
  on t_xfer_state (from_node);

create index ix_xfer_state_to_node
  on t_xfer_state (to_node);

create index ix_xfer_state_from_replica
   on t_xfer_state (from_replica);

--
create index ix_xfer_tracking
 on t_xfer_tracking (fileid, from_node, to_node);

----------------------------------------------------------------------
-- Modify storage options

alter table t_xfer_replica			enable row movement;
alter table t_xfer_request			enable row movement;
alter table t_xfer_path				enable row movement;
alter table t_xfer_state			enable row movement;
alter table t_xfer_tracking			enable row movement;

alter index pk_xfer_replica			rebuild initrans 8;

alter index pk_xfer_state			rebuild initrans 8;
alter index ix_xfer_state_from_node		rebuild initrans 8;
alter index ix_xfer_state_to_node		rebuild initrans 8;
alter index ix_xfer_tracking			rebuild initrans 8;
