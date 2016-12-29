----------------------------------------------------------------------
-- Create tables

create table t_dps_file_invalidate
  (request              integer, -- FIXME set not null,
   fileid		integer		not null,
   block		integer		not null,
   dataset		integer		not null,
   node			integer		not null,
   time_request		float		not null,
   time_complete	float,
   --
   constraint pk_dps_file_invalidate
     primary key (fileid, node),
   --
   constraint fk_dps_file_invalidate_request
     foreign key (request) references t_req_request (id)
 	on delete set null,
   --
   constraint fk_dps_file_invalidate_file
     foreign key (fileid) references t_dps_file (id)
     on delete cascade,
   --
   constraint fk_dps_file_invalidate_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_dps_file_invalidate_dataset
     foreign key (dataset) references t_dps_dataset (id)
     on delete cascade,
   --
   constraint fk_dps_file_invalidate_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

----------------------------------------------------------------------
-- Create indices

-- t_dps_file_invalidate
create index ix_dps_file_invalidate_req
  on t_dps_file_invalidate (request);
create index ix_dps_file_invalidate_bk
  on t_dps_file_invalidate (block);
create index ix_dps_file_invalidate_ds
  on t_dps_file_invalidate (dataset);
create index ix_dps_file_invalidate_node
  on t_dps_file_invalidate (node);
