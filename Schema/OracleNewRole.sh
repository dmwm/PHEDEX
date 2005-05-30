#!/bin/sh

##H Create new access role for a site.
##H
##H Usage: OracleNewRole.sh MASTER/PASS@DB ROLE_NAME ROLE_PASS
##H
##H MASTER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The first argument will be passed
##H to "sqlplus" as such.
##H
##H ROLE_NAME should be the name of the new role, and ROLE_PASS
##H its password.
##H
##H You should run "OraclePrivs.sh" afterwards to refresh access
##H privileges.

if [ $# -ne 3 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

echo "create role $2 identified by $3;" | sqlplus -S "$1"
