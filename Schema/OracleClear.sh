#!/bin/sh

##H Remove all Oracle data objects.
##H
##H Usage: OracleClear.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.

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

scan_objects "select sequence_name from user_sequences;" |
  while read name; do echo "drop sequence $name;"; done |
  sqlplus -S "$connect"

scan_objects "select constraint_name, table_name from user_constraints;" |
  while read name tab; do echo "alter table $tab drop constraint $name;"; done |
  sqlplus -S "$connect"

scan_objects "select table_name from user_tables;" |
  while read name; do echo "drop table $name;"; done |
  sqlplus -S "$connect"

scan_objects "select index_name from user_indexes;" |
  while read name; do echo "drop index $name;"; done |
  sqlplus -S "$connect"
