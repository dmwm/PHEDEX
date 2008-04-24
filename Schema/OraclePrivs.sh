#!/bin/sh

##H Reapply reader/writer account privileges to all PhEDEx tables.
##H
##H Usage: OraclePrivs.sh MASTER/PASS@DB READER WRITER ROLE
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
##H
##H ROLE is optional; if it is given then only the specified has the
##H privileges updated

if [ $# -lt 3 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1" reader="$2" writer="$3" myrole="$4"

selectrole="select granted_role from user_role_privs"
if [ -n "$myrole" ]; then
  myrole=$(echo $myrole | tr '[:lower:]' '[:upper:]')
  selectrole="$selectrole where granted_role='$myrole'"
  echo "Updating privileges for $myrole"
fi

# Update privileges for all roles and tables.
# The assumption here is that nobody except few selected admins have
# access privileges to the admin account, and all sites use roles to
# gain modification access to tables; the reader account has read-only
# access to all the tables.
for role in \
  $((echo "$selectrole;") |
    sqlplus -S "$connect" | awk '/PHEDEX/ { print $1 } {}'); do
  echo; echo; echo "-- role $role"
  echo "set feedback off;"
  echo "grant $role to $writer;"

  for table in \
    $((echo "select table_name from user_tables;"
       echo "select sequence_name from user_sequences;") |
      sqlplus -S "$connect" | awk '/^(T|SEQ)_[A-Z0-9_]+/ { print $1 } {}'); do

    echo "revoke all on $table from $reader;"
    echo "revoke all on $table from $writer;"
    echo "revoke all on $table from $role;"

    case $table:$role in
      T_DVS_BLOCK:*_WEBSITE_* | \
      T_*:*_CERN_* | \
      T_REQ_*:*_WEBSITE_* | \
      T_ADM_*:*_WEBSITE_* | \
      T_LOADTEST_PARAM:*_WEBSITE_* | \
      T_DPS_SUBSCRIPTION:*_WEBSITE_* | \
      T_DPS_BLOCK_DELETE:*_WEBSITE_* | \
      T_AGENT*:* )
        # Select, update, insert and delete
        echo; echo "grant select on $table to $reader;"
	echo "grant select on $table to $writer;"
	echo "grant delete, insert, select, update on $table to $role;" ;;

      T_DPS_DATASET:*_WEBSITE_* )
	# Create only (For LoadTest injection creation)
        # Select, update, insert and delete
        echo; echo "grant select on $table to $reader;"
	echo "grant select on $table to $writer;"
	echo "grant insert, select on $table to $role;" ;;

      *:*_WEBSITE_* )
        # Select only
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;" ;;

      T_XFER_DELETE:* )
        # Select and update, but no insert
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;"
	echo "grant select, update on $table to $role;" ;;

      T_DVS_*:* | \
      T_STATUS_BLOCK_VERIFY*:* | \
      T_DPS_DBS:* | \
      T_DPS_BLOCK_ACTIVATE:* | \
      T_DPS_BLOCK:* | \
      T_DPS_DATASET:* | \
      T_DPS_FILE:* | \
      T_DPS_DBS:* | \
      T_XFER_FILE:* )
        # Select, update and insert
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;"
	echo "grant insert, select, update on $table to $role;" ;;

      T_XFER_PATH:* | \
      T_XFER_REQUEST:* | \
      T_XFER_TASK:* | \
      T_XFER_TASK_HARVEST:* )
        # Select only
        echo; echo "grant select on $table to $reader;"
        echo "grant select on $table to $writer;" ;;

      T_XFER_*:* )
        # Select, update, insert and delete
        echo; echo "grant select on $table to $reader;"
	echo "grant select on $table to $writer;"
	echo "grant delete, insert, select, update on $table to $role;" ;;

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
