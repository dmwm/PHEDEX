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
   time_state		float		not null);

create table t_xfer_request
  (fileid		integer		not null,
   inblock		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   state		integer		not null,
   attempt		integer		not null,
   time_create		float		not null,
   time_expire		float		not null);

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
   time_expire		float		not null /*   request expiry time */);

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
   --
   time_expire		float,			  -- time when expires
   time_assign		float,			  -- time created
   time_request		float,			  -- time first wanted
   time_available	float,			  -- time exported
   time_xfer_start	float,			  -- time last xfer started
   time_xfer_end	float,			  -- time last xfer ended
   time_error_total	float,			  -- time in error state
   time_error_start	float,			  -- time last entered error
   time_error_end	float			  /* time to exit error state */);

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
   is_expire		integer		not null);

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
   confirm_weight	integer);

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
   penalty		float		not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_xfer_replica
  add constraint pk_xfer_replica
  primary key (id);

alter table t_xfer_replica
  add constraint uq_xfer_replica
  unique (fileid, node);

alter table t_xfer_replica
  add constraint fk_xfer_replica_fileid
  foreign key (fileid) references t_xfer_file (id);

alter table t_xfer_replica
  add constraint fk_xfer_replica_node
  foreign key (node) references t_node (id);


alter table t_xfer_request
  add constraint pk_xfer_request
  primary key (fileid, destination);

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
  primary key (fileid, to_node);

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
  foreign key (link); references t_link (id)

----------------------------------------------------------------------
-- Add indices

create index ix_xfer_replica_node
  on t_xfer_replica (node);

create index ix_xfer_replica_common
  on t_xfer_replica (node, state, fileid);


create index ix_xfer_state_from_node
  on t_xfer_state (from_node);

create index ix_xfer_state_to_node
  on t_xfer_state (to_node);

create index ix_xfer_state_to_state
  on t_xfer_state (to_state);

create index ix_xfer_state_fromto_state
  on t_xfer_state (from_node, fileid, to_state);

create index ix_xfer_state_fromto_pair
  on t_xfer_state (from_node, to_node);


----------------------------------------------------------------------
-- Modify storage options

alter table t_xfer_replica			enable row movement;
alter table t_xfer_request			enable row movement;
alter table t_xfer_state			enable row movement;
alter table t_xfer_tracking			enable row movement;

alter table t_xfer_replica			move initrans 8;
alter table t_xfer_request			move initrans 8;
alter table t_xfer_state			move initrans 8;
alter table t_xfer_tracking			move initrans 8;

alter index pk_xfer_replica			rebuild initrans 8;
alter index ix_xfer_replica_node		rebuild initrans 8;
alter index ix_xfer_replica_common		rebuild initrans 8;

alter index pk_xfer_state			rebuild initrans 8;
alter index ix_xfer_state_from_node		rebuild initrans 8;
alter index ix_xfer_state_to_node		rebuild initrans 8;
alter index ix_xfer_state_to_state		rebuild initrans 8;
alter index ix_xfer_state_fromto_state		rebuild initrans 8;
alter index ix_xfer_state_fromto_pair		rebuild initrans 8;
