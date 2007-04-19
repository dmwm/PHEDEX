create table t_migration_dataset_map (
  old		varchar(400),
  new		varchar(400),
  --
  constraint uq_migration_dataset_map
    unique (old, new),
  --
  constraint uq_migration_dataset_map_old
    unique (old)
);

create table t_migration_block_map (
  old		varchar(400),
  new		varchar(400),
  --
  constraint uq_migration_block_map
    unique (old, new),
  --
  constraint uq_migration_block_map_old
    unique (old),
  constraint uq_migration_block_map_new
    unique (new)
);
