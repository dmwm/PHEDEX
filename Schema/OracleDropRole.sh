#!/bin/sh

##H Drop obsolete access role.
##H
##H Usage: OracleDropRole.sh MASTER/PASS@DB ROLE_NAME
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The first argument will be passed
##H to "sqlplus" as such.
##H
##H ROLE_NAME should be the name of the old role to drop
##H

if [ $# -ne 2 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi
 echo "Dropping role $2"
 echo "drop role $2;" | sqlplus -S "$1"

