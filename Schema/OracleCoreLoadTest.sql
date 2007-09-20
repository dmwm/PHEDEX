-- Schema for managing load tests

create table t_loadtest_param
  (src_dataset		number		not null, -- file source
   dest_dataset		number		not null, -- file destination
   dest_node		number		not null, -- node destination (source of injections)
   is_active		char(1)		not null, -- active or suspended
   dataset_size		integer		        , -- n blocks in a dataset, null for infinite
   dataset_close	char(1)		not null, -- close dataset when full
   block_size		integer		        , -- n files in a block, null for infinite
   block_close		char(1)         not null, -- close blocks when full
   rate			float		not null, -- injection rate in B/s
   inject_now		integer		not null, -- one-time injection files
   throttle_node	number			, -- don't inject more files if this node has enough to do
   time_create		float		not null, -- time started
   time_update		float		not null, -- last updated these params
   time_inject		float		        , -- last inection
   --
   constraint pk_loadtest_param
     primary key (src_dataset, dest_dataset, dest_node),
   --
   constraint fk_loadtest_param_ds
     foreign key (src_dataset) references t_dps_dataset (id),
   constraint fk_loadtest_param_dd
     foreign key (dest_dataset) references t_dps_dataset (id),
   constraint fk_loadtest_param_dest_node
     foreign key (dest_node) references t_adm_node (id),
   constraint fk_loadtest_param_throttle
     foreign key (throttle_node) references t_adm_node (id),
  --
   constraint uq_loadtest_param_dest
     unique (dest_dataset, dest_node),
  constraint ck_loadtest_param_active
     check (is_active in ('y', 'n')),
  constraint ck_loadtest_ds_size
     check (dataset_size is null or dataset_size >= 1),
  constraint ck_loadtest_ds_close
     check (dataset_close in ('y', 'n')),
  constraint ck_loadtest_b_size
     check (block_size is null or block_size >= 1),
  constraint ck_loadtest_b_close
     check (block_close in ('y', 'n')),
  constraint ck_loadtest_param_rate
     check (rate >= 0),
  constraint ck_loadtest_param_inject
     check (inject_now >= 0)
);
