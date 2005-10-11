set lines 1000 pages 1000
select
  used.tablespace_name,
  trunc(used.bytes / (1024*1024), 2) used_megabytes, used.blocks,
  trunc(free.bytes / (1024*1024), 2) free_megabytes, free.blocks
from (select tablespace_name, sum(bytes) bytes, sum(blocks) blocks
      from user_extents group by tablespace_name) used
join (select tablespace_name, sum(bytes) bytes, sum(blocks) blocks
      from user_free_space group by tablespace_name) free
  on used.tablespace_name = free.tablespace_name
order by free.bytes asc, used.bytes desc;
