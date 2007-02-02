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

# Update privileges for all roles and tables.  Note that some tables
# have restricted access: t_node_neighbour and t_subscription can be
# modified only by the admin account, most t_info_* tables can only
# be updated by the central agents at CERN (as a precaution to avoid
# sites accidentally overloading the database by running agents they
# should not be running).
#
# The assumption here is that nobody except few selected admins have
# access privileges to the admin account, and all sites use roles to
# gain modification access to tables; the reader account has read-only
# access to all the tables.
for role in \
  $((echo "select granted_role from user_role_privs;") |
    sqlplus -S "$connect" | awk '/PHEDEX/ { print $1 } {}'); do
  echo; echo; echo "-- role $role"
  echo "set feedback off;"
  echo "grant $role to $writer;"

  for table in \
    $((echo "select table_name from user_tables;"
       echo "select sequence_name from user_sequences;") |
      sqlplus -S "$connect" | awk '/^(T|SEQ)_[A-Z0-9_]+/ { print $1 } {}'); do

    case $table:$role in
      T_AUTH*:* )
        # Invisible to all but admin
        ;;

      T_*:*CERN* | \
      T_*AGENT*:* | \
      T_XFER_CATALOGUE:* | \
      T_XFER_DELETE:* | \
      T_XFER_ERROR:* | \
      T_XFER_REPLICA:* | \
      T_XFER_SINK:* | \
      T_XFER_SOURCE:* | \
      T_XFER_TASK*:* )
        # Select, update, insert and delete
        echo; echo "grant select on $table to $reader;"
	echo "grant select on $table to $writer;"
	echo "grant delete, insert, select, update on $table to $role;" ;;

#      T_XFER_FILE:* )
#        # Select, update and insert
#        echo; echo "grant select on $table to $reader;"
#        echo "grant select on $table to $writer;"
#	echo "grant insert, select, update on $table to $role;" ;;
#
#      T_DPS_BLOCK_DEST:* )
#        # Select and update, but no insert
#        echo; echo "grant select on $table to $reader;"
#        echo "grant select on $table to $writer;"
#	echo "grant select, update on $table to $role;" ;;

      T_*:* )
        # Select only
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;" ;;

      SEQ_*:* )
        # Everybody can change all sequences
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;"
        echo "grant select, alter on $table to $role;" ;;
    esac
  done
done | sqlplus -S "$connect"
