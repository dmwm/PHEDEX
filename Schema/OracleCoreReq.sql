----------------------------------------------------------------------
-- Create tables

create sequence seq_req_type;
create sequence seq_req_request;
create sequence seq_req_comments;

/* Type of request */
create table t_req_type
  (id			integer		not null,
   name			varchar(100)	not null,
   --
   constraint pk_req_type
     primary key (id),
   --
   constraint uk_req_type_name
     unique (name)
);
/* Fixed data for types */
insert into t_req_type (id, name)
  values (seq_req_type.nextval, 'xfer');
insert into t_req_type (id, name)
   values (seq_req_type.nextval, 'delete');
insert into t_req_type (id, name)
   values (seq_req_type.nextval, 'invalidate');


/* Main request table */
create table t_req_request
  (id			integer		not null,
   type			integer		not null,
   created_by		integer		not null,  -- who created the request
   time_create		float		not null,
   comments		integer			,
   --
   constraint pk_req_request
     primary key (id),
   --
   constraint fk_req_request_created_by
     foreign key (created_by) references t_adm_client (id)
   /* comments fk created below */
);


/* DBS info */
create table t_req_dbs
  (request		integer		not null,
   name			varchar (1000)	not null,
   dbs_id		integer			,
   --
   constraint pk_req_dbs
     primary key (request, name),
   --
   constraint fk_req_dbs_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_dbs_dbs_id
     foreign key (dbs_id) references t_dps_dbs (id)
     on delete set null);


/* Dataset info */
create table t_req_dataset
  (request		integer		not null,
   name			varchar (1000)	not null,
   dataset_id		integer			,
   --
   constraint pk_req_dataset
     primary key (request, name),
   --
   constraint fk_req_dataset_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_dataset_ds_id
     foreign key (dataset_id) references t_dps_dataset (id)
     on delete set null);


/* Block info */
create table t_req_block
  (request		integer		not null,
   name			varchar (1000)	not null,
   block_id		integer			,
   --
   constraint pk_req_block
     primary key (request, name),
   --
   constraint fk_req_block_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_block_b_id
     foreign key (block_id) references t_dps_block (id)
     on delete set null);


-- WARNING: FUTURE/UNUSED. I have no idea why this is here, it's not referenced
-- anywhere in the code. TW
/* File info */
create table t_req_file
  (request		integer		not null,
   name			varchar (1000)	not null,
   file_id		integer			,
   --
   constraint pk_req_file
     primary key (request, name),
   --
   constraint fk_req_file_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_file_f_id
     foreign key (file_id) references t_dps_file (id)
     on delete set null);


/* Node info
 *   parameters:
 *     point: 's' for source node, 'd' for dest node, NULL for irrelevant for request
 */
create table t_req_node
  (request		integer		not null,
   node			integer		not null,
   point		char(1)			,
   --
   constraint pk_req_node
     primary key (request, node),
   --
   constraint fk_req_node_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_node_n_id
     foreign key (node) references t_adm_node (id),
   --
   constraint ck_req_node_point
     check (point in ('s', 'd')));


/* Request approval/disapproval */
create table t_req_decision
  (request		integer		not null,
   node			integer		not null,
   decision		char(1)		not null, -- 'y' for approved, 'n' for refused
   decided_by		integer		not null, -- who decided
   time_decided		float		not null,
   comments		integer			,
   --
   constraint pk_req_decision_node
     primary key (request, node),
   --
   constraint fk_req_decision_node
     foreign key (request, node) references t_req_node (request, node)
     on delete cascade,
   constraint fk_req_decision_by
     foreign key (decided_by) references t_adm_client (id),
   /* comments fk created below */
   --
   constraint ck_req_decision_decision
     check (decision in ('y', 'n')));


/* Request comments */
/* Note "comment" is an Oracle reserved word */
create table t_req_comments
  (id			integer		not null,
   request		integer		not null,
   comments_by		integer		not null,
   comments		varchar (4000)	not null,
   time_comments	integer		not null,
   --
   constraint pk_req_comments
     primary key (id),
   --
   constraint fk_req_comments_request
     foreign key (request) references t_req_request (id)
     on delete cascade,
   constraint fk_req_comments_by
     foreign key (comments_by) references t_adm_client (id));


/* Transfer request info.  type 'xfer' 
 *    parameters:
 *     priority:  integer 0-inf, transfer priority
 *     is_custodial:  'y' for custodial data, 'n' for not
 *     is_move:   'y' for move, 'n' for replication
 *     is_static: 'y' for fixed data size, 'n' for growing data subscription
 *     is_distributed:  'y' for distribution among nodes, 'n' for all data to all nodes
 *     user_group:  which group this request is for
 *     time_start: the start time for dataset transfers, NULL for all blocks in dataset
 *     data:  text of user's actual request (unresolved globs)
 */
create table t_req_xfer
  (request		integer		not null,
   priority		integer		not null,
   is_custodial		char(1)		not null,
   is_move		char(1)		not null,
   is_static		char(1)		not null,
   is_transient		char(1)		not null,
   is_distributed	char(1)		not null,
   user_group		integer		not null,
   time_start           float                   ,
   data			clob			,
   --
   constraint pk_req_xfer
     primary key (request),
   --
   constraint fk_req_xfer_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   --
   constraint fk_req_xfer_group
     foreign key (user_group) references t_adm_group (id),
   --
   constraint ck_req_xfer_custodial
     check (is_custodial in ('y', 'n')),
   constraint ck_req_xfer_move
     check (is_move in ('y', 'n')),
   constraint ck_req_xfer_static
     check (is_static in ('y', 'n')),
   constraint ck_req_xfer_transient
     check (is_transient in ('y', 'n')),
   constraint ck_req_xfer_distributed
     check (is_distributed in ('y', 'n'))
);


/* Delete request info.  type 'delete' 
 *   parameters:
 *     rm_subscriptions:  remove subscriptions, 'y' or 'n'
 *     data:  text of user's actual request (unresolved globs)
 */
create table t_req_delete
  (request		integer		not null,
   rm_subscriptions	char(1)		not null,
   data			clob			,
   --
   constraint pk_req_delete
     primary key (request),
   --
   constraint fk_req_delete_req
     foreign key (request) references t_req_request (id)
     on delete cascade,
   --
   constraint ck_req_delete_retransfer
     check (rm_subscriptions in ('y', 'n')));

create table t_dps_block_delete
  (request              integer,
   block		integer		not null,
   dataset		integer		not null,
   node			integer		not null,
   time_request		float		not null,
   time_complete	float,
   --
   constraint pk_dps_block_delete
     primary key (block, node),
   --
   constraint fk_dps_block_delete_request
     foreign key (request) references t_req_request (id)
 	on delete set null,
   --
   constraint fk_dps_block_delete_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_dps_block_delete_dataset
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_block_delete_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

/* Per-request statistics for data associated with the request */
create table t_req_size
  (request		integer		not null,
   datasets		integer		not null,
   blocks		integer		not null,
   files		integer		not null,
   bytes		integer		not null,
   time_update		integer		not null,
   --
   constraint pk_req_size
     primary key (request));

/* Per-node statistics for data associated with the request */
create table t_req_replica
  (request		integer		not null,
   node			integer		not null,
   src_files		integer		not null,
   src_bytes		integer		not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   time_create		float		not null,
   time_update		float		not null,
   --
   constraint pk_req_replica
     primary key (request, node),
   --
   constraint fk_req_replica_request
     foreign key (request, node) references t_req_node (request, node)
     on delete cascade);

----------------------------------------------------------------------
-- Create extra foreign keys

alter table t_req_request add constraint fk_req_rquest_comments
     foreign key (comments) references t_req_comments (id)
     on delete set null;
alter table t_req_decision add constraint fk_req_decision_comments
     foreign key (comments) references t_req_comments (id)
      on delete set null;


----------------------------------------------------------------------
-- Create indices

-- t_req_request
create index ix_req_request_by
  on t_req_request (created_by);

-- t_req_dbs
create index ix_req_dbs_name
  on t_req_dbs (name);
create index ix_req_dbs_dbs
  on t_req_dbs (dbs_id);

-- t_req_dataset
create index ix_req_dataset_name
  on t_req_dataset (name);
create index ix_req_dataset_dataset
  on t_req_dataset (dataset_id);

-- t_req_block
create index ix_req_block_name
  on t_req_block (name);
create index ix_req_block_block
  on t_req_block (block_id);

-- t_req_file
create index ix_req_file_name
  on t_req_file (name);
create index ix_req_file_file
  on t_req_file (file_id);

-- t_req_node
create index ix_req_node_node
  on t_req_node (node);

-- t_req_decision
create index ix_req_decision_node
  on t_req_decision (node);
create index ix_req_decision_by
  on t_req_decision (decided_by);

-- t_req_comments
create index ix_req_comments_request
  on t_req_comments (request);
create index ix_req_comments_by
  on t_req_comments (comments_by);

-- t_req_xfer
create index ix_req_xfer_group
  on t_req_xfer (user_group);

-- t_dps_block_delete
create index ix_dps_block_delete_req
  on t_dps_block_delete (request);
create index ix_dps_block_delete_ds
  on t_dps_block_delete (dataset);
create index ix_dps_block_delete_node
  on t_dps_block_delete (node);
