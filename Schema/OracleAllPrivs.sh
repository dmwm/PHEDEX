#!/bin/sh

##H Reapply foreign account privileges to all schema tables
##H and sequences.  Gives privileges blindly -- do not use
##H this with PhEDEx production schema!
##H
##H Usage: OracleAllPrivs.sh MASTER/PASS@DB OTHER
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The first argument will be passed
##H to "sqlplus" as such.
##H
##H OTHER should be the foreign account to receive modify rights.
##H
##H Issues "grant" statements for schema objects as appropriate.

if [ $# -ne 2 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1" other="$2"

for t in \
  $((echo "select table_name from user_tables;") |
    sqlplus -S "$connect" | awk '/^T_[A-Z0-9_]+/ { print $1 } {}'); do
  echo "grant alter, delete, insert, select, update on $t to $other;"
done | sqlplus -S "$connect"

for t in \
  $((echo "select sequence_name from user_sequences;") |
    sqlplus -S "$connect" | awk '/^SEQ_[A-Z0-9_]+/ { print $1 } {}'); do
  echo "grant alter, select on $t to $other;"
done | sqlplus -S "$connect"
