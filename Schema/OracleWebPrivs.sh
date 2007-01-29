#!/bin/sh

##H Grant appropriate priviliges to the website role
##H
##H Usage: OraclePrivs.sh MASTER/PASS@DB WEBROLE
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The first argument will be passed
##H to "sqlplus" as such.
##H
##H WEBROLE is the role created for the website
##H
##H Issues "grant" statements for all tables as appropriate.  Run
##H this script after defining new tables to update privileges.

if [ $# -ne 2 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1" webrole="$2"

for table in \
  $((echo "select table_name from user_tables;"
     echo "select sequence_name from user_sequences;") |
    sqlplus -S "$connect" | awk '/^(T|SEQ)_[A-Z0-9_]+/ { print $1 } {}'); do

    case $table in
    T_AUTH*:* )
      # Invisible to all but admin
      ;;

    T_REQ_* | \
    T_ADM_* | \
    T_DPS_SUBSCRIPTION )
      # Select, update, insert and delete
      echo;
      echo "grant delete, insert, select, update on $table to $webrole;" ;;

    T_* )
      # Select only
      echo;
      echo "grant select on $table to $webrole;" ;;

    SEQ_* )
      # Everybody can change all sequences
      echo;
      echo "grant select, alter on $table to $webrole;" ;;
  esac
done | sqlplus -S "$connect"
