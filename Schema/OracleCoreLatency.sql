/* Block-level latency log information for blocks currently in transfer.*/
create table t_status_block_latency
  (time_update		float		not null,
   destination		integer		not null,
   block		integer		not null, -- block id
   files		integer		not null, -- number of files
   bytes		integer		not null, -- block size in bytes
   priority		integer		not null, -- t_dps_block_dest priority
   is_custodial		char (1)	not null, -- t_dps_block_dest custodial
   time_subscription	float		not null, -- time block was subscribed
   block_create		float		not null, -- time the block was created
   block_close		float		        , -- time the block was closed
   latest_replica	float			, -- time when a file was most recently replicated
   last_replica		float			, -- time when the final file replica in the block was replicated
   last_suspend		float			, -- time the block was last observed suspended
   partial_suspend_time	float			, -- seconds the block was suspended since the creation of the latest replica
   total_suspend_time	float			, -- seconds the block was suspended since the start of the transfer
   latency		float			, -- current latency for this block
   --
   constraint pk_status_block_latency
     primary key (destination,block),
   --
   constraint fk_status2_block_latency_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint fk_status2_block_latency_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint ck_status2_block_latency_cust
     check (is_custodial in ('y', 'n'))
  );

create index ix_status_block_latency_update
  on t_status_block_latency (time_update);

create index ix_status_block_latency_dest
  on t_status_block_latency (destination);

create index ix_status_block_latency_block
  on t_status_block_latency (block);

/* File-level latency log information for files currently in transfer.*/
create table t_status_file_arrive
  (time_update		float		not null,
   destination		integer		not null, -- destination node id
   fileid		integer			, -- file id, can be NULL for invalidated files
   inblock		integer		not null, -- block id
   filesize		integer 	not null, -- file size in bytes
   priority		integer			, -- task priority
   is_custodial		char (1)		, -- task custodiality
   time_request		float			, -- timestamp of the first time the file was activated for transfer by FileRouter
   time_route		float			, -- timestamp of the first time that a valid transfer path was created by FileRouter
   time_assign		float			, -- timestamp of the first time that a transfer task was created by FileIssue
   time_export		float			, -- timestamp of the first time was exported for transfer (staged at source Buffer, or same as assigned time for T2s)
   attempts		integer			, -- number of transfer attempts TODO-force not null and only log files with at least one transfer attempt?
   time_first_attempt	float			, -- timestamp of the first transfer attempt TODO-force not null and only log files with at least one transfer attempt?
   time_latest_attempt	float			, -- timestamp of the most recent transfer attempt TODO-force not null and only log files with at least one transfer attempt?
   time_on_buffer	float			, -- timestamp of the successful WAN transfer attempt (to Buffer for T1 nodes)
   time_at_destination	float			, -- timestamp of arrival on destination node (same as before for T2 nodes, or migration time for T1s)
   --
   constraint fk_status_file_arrive_blkltn
     foreign key (destination, inblock)
      references t_status_block_latency (destination, block)
      on delete cascade,
   --
   constraint fk_status_file_arrive_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint fk_status_file_arrive_file
     foreign key (fileid) references t_dps_file (id)
     on delete set null,
   --
   constraint fk_status_file_arrive_block
     foreign key (inblock) references t_dps_block (id)
     on delete cascade,
   --
   constraint ck_status_file_arrive_cust
     check (is_custodial in ('y', 'n'))
  );

create index ix_status_file_arrive_blkltn
  on t_status_file_arrive (destination, inblock);

create index ix_status_file_arrive_update
  on t_status_file_arrive (time_update);

create index ix_status_file_arrive_dest
  on t_status_file_arrive (destination);

create index ix_status_file_arrive_block
  on t_status_file_arrive (inblock);

create index ix_status_file_arrive_file
  on t_status_file_arrive (fileid);


/* Block-level latency for completed blocks */
create table t_history_block_latency
  (time_update          float           not null,
   destination          integer         not null,
   block                integer                 , -- block id, can be null if block remvoed
   files                integer         not null, -- number of files
   bytes                integer         not null, -- block size in bytes
   priority             integer         not null, -- t_dps_block_dest priority
   is_custodial         char (1)        not null, -- t_dps_block_dest custodial
   time_subscription    float           not null, -- time block was subscribed
   block_create         float           not null, -- time the block was created
   block_close          float           not null, -- time the block was closed
   first_request        float                   , -- time block was first routed (t_xfer_request appeared)
   first_replica        float                   , -- time the first file was replicated
   percent25_replica    float                   , -- time the 25th-percentile file was replicated
   percent50_replica    float                   , -- time the 50th-percentile file was replicated
   percent75_replica    float                   , -- time the 75th-percentile file was replicated
   percent95_replica    float                   , -- time the 95th-percentile file was replicated
   last_replica         float                   , -- time the last file was replicated
   total_suspend_time   float                   , -- seconds the block was suspended since the start of the transfer
   latency              float                   , -- current latency for this block
   --
   constraint fk_history_block_latency_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint fk_history_block_latency_block
     foreign key (block) references t_dps_block (id)
     on delete set null,
   --
   constraint ck_history_block_latency_cust
     check (is_custodial in ('y', 'n'))
  );

create index ix_history_block_latency_subs
  on t_history_block_latency (time_subscription);

create index ix_history_block_latency_up
  on t_history_block_latency (time_update);

create index ix_history_block_latency_dest
  on t_history_block_latency (destination);

create index ix_history_block_latency_block
  on t_history_block_latency (block);

/* File-level latency log information for files in completed blocks.*/
create table t_history_file_arrive
  (time_subscription	float		not null,
   time_update		float		not null,
   destination		integer		not null, -- destination node id
   fileid		integer			, -- file id, can be NULL for invalidated files
   inblock		integer		not null, -- block id
   filesize		integer 	not null, -- file size in bytes
   priority		integer			, -- task priority
   is_custodial		char (1)		, -- task custodiality
   time_request		float			, -- timestamp of the first time the file was activated for transfer by FileRouter
   time_route		float			, -- timestamp of the first time that a valid transfer path was created by FileRouter
   time_assign		float			, -- timestamp of the first time that a transfer task was created by FileIssue
   time_export		float			, -- timestamp of the first time was exported for transfer (staged at source Buffer, or same as assigned time for T2s)
   attempts		integer			, -- number of transfer attempts TODO-force not null and only log files with at least one transfer attempt?
   time_first_attempt	float			, -- timestamp of the first transfer attempt TODO-force not null and only log files with at least one transfer attempt?
   time_latest_attempt	float			, -- timestamp of the most recent transfer attempt TODO-force not null and only log files with at least one transfer attempt?
   time_on_buffer	float			, -- timestamp of the successful WAN transfer attempt (to Buffer for T1 nodes)
   time_at_destination	float			, -- timestamp of arrival on destination node (same as before for T2 nodes, or migration time for T1s)
   --
   constraint fk_history_file_arrive_dest
     foreign key (destination) references t_adm_node (id),
   --
   constraint fk_history_file_arrive_file
     foreign key (fileid) references t_dps_file (id)
     on delete set null,
   --
   constraint fk_history_file_arrive_block
     foreign key (inblock) references t_dps_block (id)
     on delete cascade,
   --
   constraint ck_history_file_arrive_cust
     check (is_custodial in ('y', 'n'))
  );


create index ix_history_file_arrive_subs
  on t_history_file_arrive (time_subscription);

create index ix_history_file_arrive_up
  on t_history_file_arrive (time_update);

create index ix_history_file_arrive_dest
  on t_history_file_arrive (destination);

create index ix_history_file_arrive_block
  on t_history_file_arrive (inblock);

create index ix_history_file_arrive_file
  on t_history_file_arrive (fileid);
