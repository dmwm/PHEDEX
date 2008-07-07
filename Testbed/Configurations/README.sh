# Developer Testbed Setup - 4 node LoadTest

# This file describes the setup of a developer Testbed with a 4 node
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
# schema, central agents, and 4 site node agents which will transfer
# /LoadTestSink/LoadTestSink/$node datasets to each other at a fake
# rate of 100 MB/s for as long as these agents are running.

# Install PHEDEX
# see https://twiki.cern.ch/twiki/bin/view/CMS/PhedexAdminDocsInstallation#Software_Install

# checkout PHEDEX
#export CVSROOT=$USER@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
cvs co PHEDEX

# Get configuration
mkdir Config;
cp PHEDEX/Testbed/Configurations/* Config

# edit ConfigPart.Common and set
#   PHEDEX_BASE       :  your working directory
#   PHEDEX_INSTANCE   :  the database instance to use in your DBParam file
#   PHEDEX_VERSION    :  the version you installed via RPM
#   PHEDEX_OS_VERSION :  your machine architecture

# Set your environment
eval `PHEDEX/Utilities/Master -config Config/Config.Mgmt environ`
PHEDEX_SQLPLUS="sqlplus $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM)"

# Initialize schema
$PHEDEX_SQLPLUS @PHEDEX/Schema/OracleResetAll.sql < /dev/null
$PHEDEX_SQLPLUS @PHEDEX/Schema/OracleInit.sql < /dev/null

# Create nodes / links
# T0 node (for central agents to run)
PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name T0_CH_CERN_MSS -kind MSS \
                         -technology Castor -se-name srm.cern.ch
PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name T0_CH_CERN_Export -kind Buffer \
                         -technology Castor -se-name srm.cern.ch
PHEDEX/Utilities/LinkNew -db $PHEDEX_DBPARAM T0_CH_CERN_MSS T0_CH_CERN_Export:L/1 

# Create four TX_Test nodes
for ((i=1;i<=4;i+=1)); do
PHEDEX/Utilities/NodeNew -db $PHEDEX_DBPARAM -name TX_Test${i}_Buffer -kind Disk \
                         -technology Other -se-name srm.test${i}.ch
done

# TX_Test node links
for ((i=1;i<=4;i+=1)); do
    for ((j=$i+1;j<=4;j+=1)); do
	PHEDEX/Utilities/LinkNew -db $PHEDEX_DBPARAM TX_Test${i}_Buffer TX_Test${j}_Buffer:R/2
    done
done

# Inject source dataset for LoadTest, 1000 files
echo "insert into t_dps_dbs values (1, 'test', 'unknown', now());" | $PHEDEX_SQLPLUS < /dev/null
PHEDEX/Testbed/Setup/SetupData -db $PHEDEX_DBPARAM -label LoadTestSource -datasets 1 -blocks 100 -files 10

# Insert LoadTest destination datasets.  These are the datasets which
# are ever-growing with new randomized LFNs so that other nodes can
# subscribe to them and transfer an infinite amount of data
for ((i=1;i<=4;i+=1)); do
    node="TX_Test${i}_Buffer"
    dataset="/LoadTestSink/LoadTestSink/${node}"

    echo "creating LoadTest $dataset at $node";

    # this is the LoadTest destination dataset, which will be filled with files
    ( echo "insert into t_dps_dataset values (";
      echo "seq_dps_dataset.nextval, ";
      echo "(select id from t_dps_dbs where name = 'test'), ";
      echo "'$dataset', 'y', 'n', now(), now() );"
      echo;
      # this is the injection record, which gives the loadtest parameters
      echo "insert into t_loadtest_param values (";
      echo "(select id from t_dps_dataset where name like '/LoadTestSource/%'), ";
      echo "(select id from t_dps_dataset where name = '$dataset'), ";
      echo "(select id from t_adm_node where name = '$node'), ";
      echo "'y', NULL, 'n', 100, 'y', 100 * power(1024,2), 0, NULL, now(), now(), NULL );";
      echo;
      echo "commit;";
      echo;
    ) | $PHEDEX_SQLPLUS
done

# Subscribe every node to every other node's LoadTest
# This could also be done via the website.
for ((i=1;i<=4;i+=1)); do
    for ((j=1;j<=4;j+=1)); do
	[ "$i" = "$j" ] && continue;
	src="TX_Test${i}_Buffer"
	dest="TX_Test${j}_Buffer"
	dataset="/LoadTestSink/LoadTestSink/${src}"

	echo "Subscribing LoadTest for $src to $dest"
	(echo "insert into t_dps_subscription values (";
	 echo "NULL, ";
	 echo "(select id from t_dps_dataset where name = '$dataset'), ";
	 echo "NULL, ";
	 echo "(select id from t_adm_node where name = '$dest'), ";
	 echo "2, 'n', 'n', now(), NULL, NULL, NULL, NULL );"
	 echo;
	 echo "commit;";
	 echo;
	) | $PHEDEX_SQLPLUS
    done
done

# Start central agents
PHEDEX/Utilities/Master -config Config/Config.Mgmt start

# Start site agents
for ((i=1;i<=4;i+=1)); do
    node="TX_Test${i}_Buffer"
    PHEDEX_NODE=$node PHEDEX/Utilities/Master -config Config/Config.Site start
done

# Look at the logs
tail -f Testbed2_Mgmt/logs/*
tail -f Testbed2_TX*/logs/*

# Look at the website
# http://cmsdoc.cern.ch/cms/test/aprom/phedex/tbedii/Components::Status

# Do work
# emacs ...

# Restart agents
# PHEDEX/Utilities/Master -config Config/Config.Mgmt stop
# PHEDEX/Utilities/Master -config Config/Config.Mgmt start
