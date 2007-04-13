#!/bin/sh

##H Usage:
##H   OracleInitRole.sh DBPARAM:SECTION KEY-DIRECTORY/USERCERT-FILE SITE-NAME [NODE[,NODE...]]
##H
##H Where:
##H DBPARAM         is the database parameter file with
##H                   the contact information
##H SECTION         is the name of the section to pick
##H                   out, plus the name to pick out
##H                   from KEY-DIRECTORY; "/Admin" is
##H                   appended automatically
##H KEY-DIRECTORY   is the directory where keys are held;
##H                   it is assumed that Details/SECTION
##H                   will contain the necessary info;
##H                   unencrypted passwords are stored
##H                   in Details/USERCERT-FILE
##H USERCERT-FILE   name of the user certificate file in
##H                   KEY-DIRECTORY, formed as e-mail
##H                   address
##H SITE-NAME       is the name of the site (e.g. "CERN")
##H NODE[,NODE...]  comma-separated list of node names
##H
##H NODE is optional.  If it is not provided no nodes or site
##H information will be added to the DB.  This is only for the case of
##H providing DB access to persons not interested in doing transfers.
##H (e.g. for ProdAgents using the PhEDEx micro client).  In this case
##H SITE-NAME is just some descriptive string for the purpose of the
##H database role.

[ $# != 3 ] && [ $# != 4] && { echo "Insufficient parameters." 1>&2; exit 1; }

dbparam="$(echo $1 | sed 's/:.*//')"
section="$(echo $1 | sed 's/.*://')"
keydir="$(dirname $2)"
usercert="$(basename $2)"
sitename="$3"
nodes="$4"

[ -z "$dbparam"  ] && { echo "Insufficient parameters." 1>&2; exit 1; }
[ -z "$section"  ] && { echo "Insufficient parameters." 1>&2; exit 1; }
[ -z "$keydir"   ] && { echo "Insufficient parameters." 1>&2; exit 1; }
[ -z "$usercert" ] && { echo "Insufficient parameters." 1>&2; exit 1; }
[ -z "$sitename" ] && { echo "Insufficient parameters." 1>&2; exit 1; }


[ -f "$dbparam"  ] ||
   { echo "$dbparam: no such file" 1>&2; exit 1; }
[ -d "$keydir"   ] ||
   { echo "$keydir: no such directory" 1>&2; exit 1; }
[ -f "$keydir/$usercert" ] ||
   { echo "$keydir/$usercert: no such file" 1>&2; exit 1; }
case $usercert in *@* ) ;; * )
   { echo "$usercert is not an e-mail address" 1>&2; exit 1; } ;;
esac
case $sitename in *_* )
   { echo "$sitename cannot contain _" 1>&2; exit 1; } ;;
esac

home=$(dirname $0)/..

sitename_uc="$(echo $sitename | tr '[:lower:]' '[:upper:]')"

role_dn="$(openssl x509 -in $keydir/$usercert -noout -subject | sed 's/^subject= //')"
role_email="$usercert"
role_passwd="$($home/Utilities/WordMunger)"
role_section="$(echo $section | cut -c1-4 | tr '[:lower:]' '[:upper:]')"
role_name="PHEDEX_${sitename_uc}_${role_section}"
role_name_lc="$(echo $role_name | tr '[:upper:]' '[:lower:]')"

ora_master="$($home/Utilities/OracleConnectId -db $dbparam:$section/Admin)"
ora_reader="$($home/Utilities/OracleConnectId -db $dbparam:$section/Reader)"
ora_writer="$($home/Utilities/OracleConnectId -db $dbparam:$section/CERN)"
case $ora_master in */*@* ) ;; * )
  echo "$dbparam:$section/Admin: database contact not defined" 1>&2; exit 1;;
esac
case $ora_reader in */*@* ) ;; * )
  echo "$dbparam:$section/Reader: database contact not defined" 1>&2; exit 1;;
esac
case $ora_writer in */*@* ) ;; * )
  echo "$dbparam:$section/Writer: database contact not defined" 1>&2; exit 1;;
esac

$home/Schema/OracleNewRole.sh "$ora_master" "$role_name" "$role_passwd"

if [ "$nodes" ]; then
$home/Utilities/ImportSites -db $dbparam:$section/Admin /dev/stdin <<EOF
site:  '$sitename'
email: '$role_email'
dn:    '$role_dn'
role:  '$role_name'
nodes: '$nodes'
EOF
fi

$home/Schema/OraclePrivs.sh "$ora_master" \
  "$(echo $ora_reader | sed 's|/.*||')" \
  "$(echo $ora_writer | sed 's|/.*||')"
(echo "Section            $section/$sitename_uc"
 echo "Interface          Oracle"
 echo "Database           $(echo $ora_writer | sed 's|.*@||')"
 echo "AuthDBUsername     $(echo $ora_writer | sed 's|/.*||')"
 echo "AuthDBPassword     $(echo $ora_writer | sed 's|.*/||; s|@.*||')"
 echo "AuthRole           $role_name_lc"
 echo "AuthRolePassword   $role_passwd"
 echo "ConnectionLife     86400"
 echo "LogConnection      on"
 echo "LogSQL             off") \
  > Details/$role_name_lc

mkdir -p Output
(echo "Subject: PhEDEx authentication role for $section/$sitename_uc";
 echo "From: cms-phedex-admins@cern.ch";
 echo "Cc: cms-phedex-admins@cern.ch";
 echo "To: $role_email";
 echo;
 echo "Hello $role_email";
 echo "($role_dn),"; echo;
 echo "Below is an authentication data for your PhEDEx database connection";
 echo "for database $section/$sitename_uc using authentication role $role_name.";
 echo;
 echo "Please store the information in DBParam file, using Schema/DBParam.Site";
 echo "as your example.  Please keep this information secure: do not store it";
 echo "in CVS or anywhere someone else might be able to read it.  Should you";
 echo "accidentally make the information public, please contact PhEDEx admins";
 echo "as soon as you can at cms-phedex-developers@cern.ch.  Thank you.";
 echo;
 echo "You can copy and paste the section between '====' lines in shell on a";
 echo "computer which has access to your private certificate part, typically";
 echo "in ~/.globus/userkey.pem."
 echo; echo "====";
 echo "cat << "\\"END_OF_DATA | /usr/bin/openssl smime -decrypt -in /dev/stdin -recip ~/.globus/usercert.pem -inkey ~/.globus/userkey.pem"
 /usr/bin/openssl smime -encrypt -in Details/$role_name_lc $keydir/$usercert
 echo "END_OF_DATA";
 echo "====";
 echo;
 echo "Yours truly,";
 echo "  PhEDEx administrators";
 echo "  (cms-phedex-developers@cern.ch)") \
  > "Output/${role_name_lc}:${role_email}"
