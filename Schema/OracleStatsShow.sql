----------------------------------------------------------------------
-- Dump schema statistics for all tables and indices.

-- exec dbms_stats.flush_database_monitoring_info();

set lines 1000
set pages 1000

select
  table_name, inserts, updates, deletes,
  timestamp, truncated, drop_segments
from user_tab_modifications
order by table_name;

select
  index_name, num_rows, distinct_keys,
  leaf_blocks, clustering_factor, blevel,
  avg_leaf_blocks_per_key
from user_indexes
order by index_name;

select
  table_name, column_name, num_distinct,
  num_nulls, num_buckets, trunc(density,4)
from user_tab_col_statistics
where table_name in (select table_name from user_tables)
order by table_name, column_name;
