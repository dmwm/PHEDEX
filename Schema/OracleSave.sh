#!/bin/sh

##H Rename all existing tables, constraints and indices.
##H
##H Usage: OracleSave.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H Renames all tables, constraints and indices to t_old_*.

if [ $# -ne 1 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1"

# Rename them
for object in constraint:constraints index:indexes table:tables; do
  objname=$(echo $object | sed 's/:.*//')
  objtable=$(echo $object | sed 's/.*://')
  (echo "set lines 1000;";
   echo "set pages 0;";
   echo "select ${objname}_name from user_$objtable;") |
   sqlplus -S "$connect" |
   awk '/^T_[A-Z0-9_]+/ {print $1} {}' |
   while read name; do
      newname="$(echo "$name" | sed 's/^T_/T_OLD_/')"
      echo "rename $objname $name to $newname;"
   done |
   sqlplus -S "$connect"
done
