#!/bin/bash
# Developer Testbed Setup - 2 node LoadTest

# This file describes the setup of a developer Testbed with a 2 node
# LoadTest.  This setup, when running, will create continuous activity
# for the transfer system.  Other PhEDEx components (deletions, block
# verification) are not tested under this setup, so other means must
# be used to test those.

# This file is written as a bash script but may not run correctly
# as-is.  The developer should understand what each of the commands
# here does and execute them "by hand".

# Compared to other software systems in CMS, PhEDEx is particularily
# difficult to test.  It requires a free database schema for the
# developer (or an organized method of sharing one), as well as a
# machine to run the agents.  This setup will run the logical aspects
# of the transfer management system however the actual interaction
# between PhEDEx and grid-transfer tools is not tested.  This setup is
# good for testing changes to transfer task allocation throughout all
# parts of the system, as well as library changes and other core
# behaviors (such as daemon running and event loops).

# The expected end result of this procedure is a fully deployed PhEDEx
# schema, central agents, and 2 site node agents which will transfer
# /LoadTestSink/LoadTestSink/$node datasets to each other at a fake
# rate of 100 MB/s for as long as these agents are running.

if [ -z $TESTBED_ROOT ]; then
  echo "TESTBED_ROOT not set, are you sure you sourced the environment?"
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

export PHEDEX=$PHEDEX_ROOT
export LIFECYCLE=$PHEDEX/Testbed/LifeCycle
PHEDEX_SQLPLUS="sqlplus $($PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM)"
# Minimal sanity-check on the DBPARAM and contents:
if [ `echo $PHEDEX_DBPARAM | egrep -ic 'prod|dev|debug|admin'` -gt 0 ]; then
  echo "Your DBParam appears to be unsafe?"
  echo "(It has one of 'prod|dev|debug|admin' in it, so I don't trust it)"
  exit 0
fi
if [ `echo $PHEDEX_SQLPLUS | egrep -ic 'devdb10'` -eq 0 ]; then
  echo "Your DBParam appears to be unsafe?"
  echo "('devdb10 does not appear in your connection string, so I don't trust it)"
  exit 0
fi

 echo "Connection attempted as: $PHEDEX_SQLPLUS"
i=`echo 'select sysdate from dual;' | $PHEDEX_SQLPLUS 2>/dev/null | grep -c SYSDATE`
if [ $i -gt 0 ]; then
  echo "Your database connection is good..."
else
  echo "Cannot connect to your database (status=$i)"
  echo "Connection attempted as: $PHEDEX_SQLPLUS"
  echo "(your TNS_ADMIN is $TNS_ADMIN, in case that matters)"
  echo "(Oh, and your sqlplus is in `which sqlplus`)"
  exit 0
fi

# Create nodes / links
# T0 node (for central agents to run)
$PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name T0_Test_MSS -kind MSS \
                         -technology Castor -se-name srm-t0.nowhere.cern.ch
$PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name T0_Test_Buffer -kind Buffer \
                         -technology Castor -se-name srm-t0.nowhere.cern.ch
$PHEDEX/Utilities/LinkNew -db $PHEDEX_DBPARAM T0_Test_MSS T0_Test_Buffer:L/1 

# Create one TX_Test nodes
$PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name TX_Test1_MSS -kind MSS\
			-technology Other -se-name srm-test0.nowhere.cern.ch
$PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name TX_Test1_Buffer -kind Buffer \
			-technology Other -se-name srm-test0.nowhere.cern.ch

# TX_Test node links
echo TX_Test1_Buffer to T0_Buffer
$PHEDEX/Utilities/LinkNew -db $PHEDEX_DBPARAM T0_Test_Buffer TX_Test1_Buffer:R/2
echo TX_Test1_Buffer to TX_Test1_MSS
$PHEDEX/Utilities/LinkNew -db $PHEDEX_DBPARAM TX_Test1_Buffer TX_Test1_MSS:L/1

(
  echo '$PhEDEx::Lifecycle{NodeIDs} ='
  echo '{'
  echo '# This is for convenience. Make sure it corresponds to t_adm_nodes!'
  echo '# Prefer to cache this here for debugging purposes, when not updating TMDB'
  echo "select name, id from t_adm_node order by id;" | $PHEDEX_SQLPLUS | \
	egrep '^T' | awk '{ print "    "$1" => "$2"," }'
  echo '};'
  echo ' '
  echo '1;'
) | tee $LIFECYCLE/2NodeLifecycleNodes.pl

echo 2-node setup completed
