#!/bin/bash
# Developer Testbed Setup - (Re-)initialise the schema

#if [ -z $TESTBED_ROOT ]; then
#  echo "TESTBED_ROOT not set, are you sure you sourced the environment?"
#  exit 0
#fi
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
# Minimal sanity-check on the DBPARAM and contents:
if [ `echo $PHEDEX_DBPARAM | egrep -ic 'prod|dev|debug|admin'` -gt 0 ]; then
  echo "Your DBParam appears to be unsafe?"
  echo "(It has one of 'prod|dev|debug|admin' in it, so I don't trust it)"
  echo "If you really want to use the parameters you have set, edit this script and comment out the check."
  exit 0
fi
#if [ `echo $PHEDEX_SQLPLUS | egrep -ic 'devdb10'` -eq 0 ]; then
#  echo "Your DBParam appears to be unsafe?"
#  echo "('devdb10 does not appear in your connection string, so I don't trust it)"
#  echo "If you really want to use the parameters you have set, edit this script and comment out the check."
#  exit 0
#fi

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

# Initialize schema
$PHEDEX_SQLPLUS @$PHEDEX/Schema/OracleResetAll.sql < /dev/null
$PHEDEX_SQLPLUS @$PHEDEX/Schema/OracleInit.sql < /dev/null

echo "insert into t_dps_dbs values (1, 'test', 'unknown', now());" | $PHEDEX_SQLPLUS
echo "Schema successfully reset!"
