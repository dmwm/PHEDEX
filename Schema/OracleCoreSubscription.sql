create table t_dps_subs_param 
  (id                   integer       not null,
   request	        integer               ,
   priority    	 	integer       not null,
   is_move     	 	char (1)      not null,
   is_custodial	 	char (1)      not null,
   user_group	 	integer               ,
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
     foreign key (user_group) references t_adm_group (id)
     on delete set null,
   --
   constraint ck_dps_subs_param_move
     check (is_move in ('y', 'n')),
   --
   constraint ck_dps_subs_param_custodial
     check (is_custodial in ('y', 'n')),
   --
   constraint ck_dps_subs_param_original
     check (original in ('y', 'n')));


create table t_dps_subs_dataset
  (destination          integer         not null,
   dataset              integer		not null,
   param               integer		not null,
   time_create          float           not null,
   time_update          float           not null,
   time_suspend_until   float			,
   time_complete        float			,
   time_done            float			,
   --
   constraint pk_dps_subs_dataset
     primary key (destination, dataset),
   --
   constraint fk_dps_subs_dataset_ds
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_subs_dataset_param
     foreign key (param) references t_dps_subs_param (id));


create table t_dps_subs_block
  (destination          integer		not null,
   dataset		integer		not null,
   block                integer		not null,
   param		integer		not null,
   time_create          float           not null,
   time_update          float           not null,
   time_suspend_until   float			,
   time_complete        float			,
   time_done            float			,
   --
   constraint pk_dps_subs_block
     primary key (destination, block),
   --
   constraint fk_dps_subs_block_block
     foreign key (dataset, block) references t_dps_block (dataset, id)
     on delete cascade,
   --
   constraint fk_dps_subs_block_param
     foreign key (param) references t_dps_subs_param (id));
