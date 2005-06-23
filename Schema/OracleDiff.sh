#!/bin/sh

##H Check migrated tables have same content as saved tables.
##H
##H Usage: OracleDiff.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H Prints each table, number of rows in new and old version,
##H and complains if the number of rows is different.

if [ $# -ne 1 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1"

scan_objects() {
  (echo "set lines 1000;"; echo "set pages 0;"; echo ${1+"$@"}) |
  sqlplus -S "$connect" |
  awk '/^(T|SEQ|IX|FK|PK|UQ)_[A-Z0-9_]+/ {print $1, $2} {}'
}

table_count() {
  (echo "set lines 1000;"; echo "set pages 0;";
   echo "select 'COUNT=' || count(*) from $1;") |
  sqlplus -S "$connect" |
  awk -F= '/^COUNT/ {print $2} {}'
}


# Rename tables and sequences
scan_objects "select table_name from user_tables;" |
  while read name; do
    case $name in T_* )
      new=$(table_count $name)
      old=$(table_count X$name)
      if [ X"$new" != X"$old" ]; then
	  echo "$name new=$new old=$old DIFFERENT"
      else
	  echo "$name new=$new old=$old OK"
      fi ;;
    esac
  done
