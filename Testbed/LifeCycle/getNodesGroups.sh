#!/bin/bash

if [ -z $LIFECYCLE ]; then
  echo "LIFECYCLE not set, are you sure you sourced the environment?"
  exit 0
fi
if [ -z $PHEDEX_ROOT ]; then
  echo "PHEDEX_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi
if [ -z $PHEDEX_DBPARAM ]; then
  echo "PHEDEX_DBPARAM not set, are you sure you sourced the environment?"
  exit 0
fi

PHEDEX_SQLPLUS="sqlplus $($PHEDEX_ROOT/Utilities/OracleConnectId -db $PHEDEX_DBPARAM)"
PHEDEX_SQLPLUS_CLEAN=`echo $PHEDEX_SQLPLUS | sed -e's%/.*@%/password-here@%'`
echo "Connection attempted as: $PHEDEX_SQLPLUS_CLEAN"
i=`echo 'select sysdate from dual;' | $PHEDEX_SQLPLUS 2>/dev/null | grep -c SYSDATE`
if [ $i -gt 0 ]; then
  echo "Your database connection is good..."
else
  echo "Cannot connect to your database (status=$i)"
  echo "Connection attempted as: $PHEDEX_SQLPLUS_CLEAN"
  echo "(your TNS_ADMIN is $TNS_ADMIN, in case that matters)"
  echo "(Oh, and your sqlplus is in `which sqlplus`)"
  exit 0
fi

LIFECYCLE_NODES=LifecycleNodes.pl
echo "Extract NODES into $LIFECYCLE_NODES"
(
  echo '$PhEDEx::Lifecycle{NodeIDs} ='
  echo '{'
  echo '# This is for convenience. Make sure it corresponds to t_adm_nodes!'
  echo '# Prefer to cache this here for debugging purposes, when not updating TMDB'
  echo "
        set linesize 132;
        select name, id from t_adm_node order by id;" | $PHEDEX_SQLPLUS | \
	egrep '^T' | awk '{ print "    "$1" => "$2"," }'
  echo '};'
  echo ' '
  echo '1;'
) | tee $LIFECYCLE_NODES

LIFECYCLE_GROUPS=LifecycleGroups.pl
echo "Extract GROUPS into $LIFECYCLE_GROUPS"
(
  echo '$PhEDEx::Lifecycle{GroupIDs} ='
  echo '{'
  echo '# This is for convenience. Make sure it corresponds to t_adm_group!'
  echo '# Prefer to cache this here for debugging purposes, when not updating TMDB'
  echo "select id, name from t_adm_group order by id;" | $PHEDEX_SQLPLUS | \
         egrep '^\s*[0-9]+\s*[A-Za-z0-9]*$' | awk '{ print "    "$2" => "$1"," }'
  echo '};'
  echo ' '
  echo '1;'
) | tee $LIFECYCLE_GROUPS

echo "All done!"
