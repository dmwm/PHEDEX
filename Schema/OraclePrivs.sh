#!/bin/sh

##H Reapply reader/writer account privileges to all PhEDEx tables.
##H
##H Usage: OraclePrivs.sh MASTER/PASS@DB READER WRITER
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The first argument will be passed
##H to "sqlplus" as such.
##H
##H READER and WRITER should be the reader (cms_transfermgmt_reader)
##H and writer (cms_transfermgmt_writer) accounts, respectively.
##H
##H Issues "grant" statements for all tables as appropriate.  Run
##H this script after defining new tables to update privileges.

if [ $# -ne 3 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1" reader="$2" writer="$3"

# Query all tables
(echo "set lines 1000;";
 echo "set pages 0;";
 echo "select * from tab;") |
 sqlplus -S "$connect" |
 awk '/^T_[A-Z0-9_]+/ {print $1} {}' |
 while read tab; do
    echo "grant select on $tab to $reader;";
    echo "grant alter, delete, insert, select, update on $tab to $writer;";
 done |
 sqlplus -S "$connect"
