#!/bin/bash
# Developer Testbed Setup

if [ -z $PHEDEX_ROOT ]; then
  echo "PHEDEX_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi
if [ -z $PHEDEX_DBPARAM ]; then
  echo "PHEDEX_DBPARAM not set, are you sure you sourced the environment?"
  exit 0
fi

export PHEDEX=$PHEDEX_ROOT

PHEDEX_SQLPLUS="sqlplus $($PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM)"
PHEDEX_SQLPLUS_MASKED=`echo $PHEDEX_SQLPLUS | sed -e 's%/.*@%/(password-masked)@%'`
echo "Connection attempted as: $PHEDEX_SQLPLUS_MASKED"
i=`echo 'select sysdate from dual;' | $PHEDEX_SQLPLUS 2>/dev/null | grep -c SYSDATE`
if [ $i -gt 0 ]; then
  echo "Your database connection is good..."
else
  echo "Cannot connect to your database (status=$i)"
  echo "Connection attempted as: $PHEDEX_SQLPLUS_MASKED"
  echo "(your TNS_ADMIN is $TNS_ADMIN, in case that matters)"
  echo "(Oh, and your sqlplus is in `which sqlplus`)"
  exit 0
fi

i=1
echo -n "Inserting groups: "
for group in physicists managers operators administrators experts other
do
  echo -n "$group "
  echo "insert into t_adm_group (id,name) values ($i,'$group');" | $PHEDEX_SQLPLUS >/dev/null
  i=`expr $i + 1`
done
echo "post-setup completed for groups"
