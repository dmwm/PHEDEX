#!/bin/sh

##H Dump schema statistics.
##H
##H Usage: OracleStatsShow.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H Shows schema statistics

if [ $# -ne 1 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1"

(echo "set lines 1000"; echo "set pages 1000";
 # echo "exec dbms_stats.flush_database_monitoring_info();"

 echo "select table_name, inserts, updates, deletes," \
      " timestamp, truncated, drop_segments" \
      " from user_tab_modifications;"

 echo "select index_name, num_rows, distinct_keys," \
      " leaf_blocks, clustering_factor, blevel," \
      " avg_leaf_blocks_per_key from user_indexes" \
      " order by index_name;") |
  sqlplus -S "$connect"
