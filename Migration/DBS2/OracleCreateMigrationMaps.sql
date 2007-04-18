create table t_migration_dataset_map (
  old		varchar(4000),
  new		varchar(4000),
  --
  constraint pk_migration_dataset_map
    primary key (old, new),
  --
  constraint uq_migration_dataset_map_old
    unique (old),
  constraint uq_migration_dataset_map_new
    unique (new)
);

create table t_migration_block_map (
  old		varchar(4000),
  new		varchar(4000),
  --
  constraint pk_migration_block_map
    primary key (old, new),
  --
  constraint uq_migration_block_map_old
    unique (old),
  constraint uq_migration_block_map_new
    unique (new)
);
