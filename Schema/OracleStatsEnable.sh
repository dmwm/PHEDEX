#!/bin/sh

##H Enable monitoring on all tables.
##H
##H Usage: OracleStatsEnable.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H Enables monitoring for all tables and indices.

if [ $# -ne 1 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1"
scan_objects() {
  (echo "set lines 1000;"; echo "set pages 0;"; echo ${1+"$@"}) |
  sqlplus -S "$connect" |
  awk '/^X?(T|SEQ|IX|FK|PK|UQ)_[A-Z0-9_]+/ {print $1, $2} {}'
}

# FIXME: Doesn't work.
# (echo "exec dbms_stats.alter_schema_tab_monitoring ('$schema', true);") |
#  sqlplus -S "$connect"

# Enable monitoring on all tables and indices
scan_objects "select table_name from user_tables;" |
  while read name; do echo "alter table $name monitoring;"; done |
  sqlplus -S "$connect"

scan_objects "select index_name from user_indexes;" |
  while read name; do echo "alter index $name monitoring usage;"; done |
  sqlplus -S "$connect"
