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
    sqlplus -S "$connect" | awk '/SITE_/ { print $1 } {}'); do
  echo; echo; echo "-- role $role"
  echo "grant $role to $writer;"

  for table in \
    $((echo "select table_name from user_tables;") |
      sqlplus -S "$connect" | awk '/^T_[A-Z0-9_]+/ { print $1 } {}'); do

    case $table:$role in
      T_AUTH*:* )
        # Invisible to all but admin
        ;;

      T_INFO_AGENT_STATUS:* | \
      T_INFO*:SITE_CERN | \
      T_DBS*:SITE_CERN | \
      T_DLS*:SITE_CERN | \
      T_REQUEST*:SITE_CERN | \
      T_BLOCK_*:SITE_CERN )
        # Restricted update
        echo; echo "grant select on $table to $reader;"
        echo "grant alter, delete, insert, select, update on $table to $role;" ;;

      T_SUBSCRIPTION:* | \
      T_NODE*:* | \
      T_INFO*:* | \
      T_DBS*:* | \
      T_DLS*:* | \
      T_REQUEST*:* | \
      T_BLOCK_*:* )
        # Read-only (see also restricted update above)
        echo; echo "grant select on $table to $reader;"
      	echo "grant select on $table to $role;" ;;

      *:* )
        # General update
        echo; echo "grant select on $table to $reader;"
      	echo "grant alter, delete, insert, select, update on $table to $role;" ;;
    esac
  done
done | sqlplus -S "$connect"
