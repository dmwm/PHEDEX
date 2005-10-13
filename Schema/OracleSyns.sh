#!/bin/sh

##H Recreate synonyms from tables in master account.
##H
##H Usage: OracleSyns.sh MASTER MASTER/MPASS@DB ACCOUNT/APASS@DB
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and MPASS it's password.  ACCOUNT/APASS should be similar
##H pair for the account into which synonyms should be created
##H (cms_transfermgmt_reader/_writer).  Both arguments will be
##H passed to "sqlplus" as such.
##H
##H Issues "drop synonym"/"create synonym" statements for all
##H tables as appropriate.  All previous synonyms are removed
##H and fresh ones are created from master table list.

if [ $# -ne 3 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

master="$1" master_connect="$2" target_connect="$3"

scan_objects() {
  (echo "set lines 1000 pages 0;"; echo ${1+"$@"}) |
  sqlplus -S "$master_connect" |
  awk '/^(T|SEQ|IX|FK|PK|UQ)_[A-Z0-9_]+/ {print $1, $2} {}'
}

# First drop all existing synonyms
(echo "set lines 1000;";
 echo "set pages 0;";
 echo "select synonym_name from user_synonyms;") |
 sqlplus -S "$target_connect" |
 awk '/^(T|SEQ)_[A-Z0-9_]+/ {print $1} {}' |
 while read tab; do
    echo "drop synonym $tab;"
 done |
 sqlplus -S "$target_connect"

# Now recreate synonyms from master tables
scan_objects "select table_name from user_tables;" |
 while read t; do echo "create synonym $t for $master.$t;"; done |
 sqlplus -S "$target_connect"

scan_objects "select sequence_name from user_sequences;" |
 while read t; do echo "create synonym $t for $master.$t;"; done |
 sqlplus -S "$target_connect"
