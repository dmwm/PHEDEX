create table t_dps_subs_param 
  (id                   integer       not null,
   request	        integer               ,
   priority    	 	integer       not null,
   is_custodial	 	char (1)      not null,
   user_group	 	integer       not null,
   original    	 	char (1)      not null,
   time_create		float	      not null,
   --
   constraint pk_dps_subs_param
     primary key (id),
   --
   constraint fk_dps_subs_param_request
     foreign key (request) references t_req_request (id)
     on delete set null,
   --
   constraint fk_dps_subs_param_group
     foreign key (user_group) references t_adm_group (id),
   --
   constraint ck_dps_subs_param_custodial
     check (is_custodial in ('y', 'n')),
   --
   constraint ck_dps_subs_param_original
     check (original in ('y', 'n')));

create sequence seq_dps_subs_param;

create index ix_dps_subs_param_request
  on t_dps_subs_param (request);

create index ix_dps_subs_param_group
  on t_dps_subs_param (user_group);

create table t_dps_subs_dataset
  (destination          integer         not null,
   dataset              integer		not null,
   param		integer		not null,
   is_move		char (1)        not null,
   time_create          float           not null,
   time_fill_after      float                   , -- subscribe blocks created after this time
   time_suspend_until   float			,
   time_complete        float			,
   time_done            float			,
   --
   constraint pk_dps_subs_dataset
     primary key (destination, dataset),
   --
   constraint fk_dps_subs_dataset_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_dps_subs_dataset_ds
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_subs_dataset_param
     foreign key (param) references t_dps_subs_param (id),
   --
   constraint ck_dps_subs_dataset_move     
     check (is_move in ('y', 'n')));

create index ix_dps_subs_dataset_dest
  on t_dps_subs_dataset (destination);

create index ix_dps_subs_dataset_ds
  on t_dps_subs_dataset (dataset);

create index ix_dps_subs_dataset_param
  on t_dps_subs_dataset (param);

create table t_dps_subs_block
  (destination          integer		not null,
   dataset		integer		not null,
   block                integer		not null,
   param		integer		not null,
   is_move              char (1)        not null,
   time_create          float           not null,
   time_suspend_until   float			,
   time_complete        float			,
   time_done            float			,
   --
   constraint pk_dps_subs_block
     primary key (destination, block),
   --
   constraint fk_dps_subs_block_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_dps_subs_block_block
     foreign key (dataset, block) references t_dps_block (dataset, id)
     on delete cascade,
   --
   constraint fk_dps_subs_block_param
     foreign key (param) references t_dps_subs_param (id),
   --
   constraint ck_dps_subs_block_move 
     check (is_move in ('y', 'n')));

create index ix_dps_subs_block_dest
  on t_dps_subs_block (destination);

create index ix_dps_subs_block_ds
  on t_dps_subs_block (dataset);

create index ix_dps_subs_block_b
  on t_dps_subs_block (block);

create index ix_dps_subs_block_param
  on t_dps_subs_block (param);
