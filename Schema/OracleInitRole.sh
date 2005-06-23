#!/bin/sh

##H Usage:
##H   ApplyRole DBPARAM SECTION KEY-DIRECTORY USERCERT-FILE SITE-NAME
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

dbparam="$1"
section="$2"
keydir="$3"
usercert="$4"
sitename="$5"

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

home=$(dirname $0)/..

role_dn="$(grid-cert-info -subject -file $keydir/$usercert)"
role_email="$usercert"
role_passwd="$($home/Utilities/WordMunger)"
role_name="SITE_$(echo $sitename | tr '[:lower:]' '[:upper:]')"
role_name_lc="$(echo $role_name | tr '[:upper:]' '[:lower:]')"

ora_master="$($home/Schema/OracleConnectId -db $dbparam:$section/Admin)"
ora_reader="$($home/Schema/OracleConnectId -db $dbparam:$section/Reader)"
ora_writer="$($home/Schema/OracleConnectId -db $dbparam:$section/CERN)"
case $ora_master in */*@* ) ;; * )
  echo "$dbparam:$section/Admin: database contact not defined" 1>&2; exit 1;;
esac
case $ora_reader in */*@* ) ;; * )
  echo "$dbparam:$section/Reader: database contact not defined" 1>&2; exit 1;;
esac
case $ora_writer in */*@* ) ;; * )
  echo "$dbparam:$section/Writer: database contact not defined" 1>&2; exit 1;;
esac

$home/Schema/OracleNewRole.sh "$ora_master" "$role_name" "$role_pass"
echo "insert into t_authorisation values" \
     "(`date +%s`,'$role_name','$role_email','$role_dn');" |
  sqlplus -S "$ora_master"
$home/Schema/OraclePrivs.sh "$ora_master" \
  "$(echo $ora_reader | sed 's|/.*||')" \
  "$(echo $ora_writer | sed 's|/.*||')"
(echo "AuthDBPassword     $(echo $ora_writer | sed 's|.*/||; s|@.*||')"
 echo "AuthRole           $role_name_lc"
 echo "AuthRolePassword   $role_passwd") \
  > $keydir/Details/$role_name_lc

mkdir -p $keydir/Output
(echo "Hello $role_email ($role_dn),"; echo;
 echo "Below is an authentication data for your PhEDEx database connection";
 echo "for database $section/$(echo $sitename | tr '[:lower:]' '[:upper:]')" \
      "using authentication role $role_name.";
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
 echo "cat << "\\"END_OF_DATA | openssl smime -decrypt -in /dev/stdin -recip ~/.globus/usercert.pem -inkey ~/.globus/userkey.pem"
 openssl smime -encrypt -in $keydir/Details/$role_name_lc $keydir/$usercert
 echo "END_OF_DATA";
 echo "====";
 echo;
 echo "Yours truly,";
 echo "  PhEDEx administrators";
 echo "  (cms-phedex-developers@cern.ch)") \
  > "$keydir/Output/$role_email"
