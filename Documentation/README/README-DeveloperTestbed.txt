THIS DOCUMENT IS OBSOLETE AND NEEDS TO BE UPDATED.  PLEASE IGNORE
THE INSTRUCTIONS BELOW FOR NOW.

* Setting up PhEDEx testbed

This document describes how to set up a local, stand-alone PhEDEx
testbed with multiple nodes, how to start and stop agents, create
test files and test the agents in a local environment without
having to register new components with the CMS production system.

It is possible to set up a testbed network of PhEDEx distribution
nodes entirely on a single machine.  The nodes manage storages which
are simply local directories, copying files between them using "cp".
Files are registered to a single MySQL catalogue shared among all
the testbed nodes.

The testbed uses separate Oracle Transfer Management Database.

** Related documents

README-Overview.txt explains where this document fits in.
README-Transfer.txt explains how to set up transfer agents.
README-Export.txt explains how to set up export agents.
README-Deployment.txt explains standard deployment.

**********************************************************************
** Deployment

This section details the process of setting up your testbed, with a
simple data source, simple data sink, and management infrastructure
required to link the agents together.  All of this can be on a single
machine, but doesn't have to be.

*** Requirements

You need:
  1) RedHat 7.3.x or Scientific Linux 3.x machine with GCC 3.2.3
  2) AFS access to POOL file catalogue tools.  You can use some
     other means, e.g. install them an easy installation tool
     such as xcmsi (http://www.cern.ch/cms-xcmsi), but in that
     case you have to adjust the node configuration files.
  3) Perl with DBI, DBD::Oracle and optionally DBD::mysql
  4) MySQL
  5) Oracle

*** Setup environment and download tools

Begin to create the testbed directory structure:

  # The commands below expect this to be set; choose your own
  TESTBED=/NodeTestbed

  # Create area
  mkdir -p $TESTBED
  cd $TESTBED

  # Get PhEDEx code
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
  cvs login # when prompted for password, type: 98passwd
  cvs co PHEDEX/{Toolkit,Schema,Utilities,Documentation/README,Testbed}

  # Get ready for using ORACLE
  . /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174


*** MySQL POOL catalogue

Install and get MySQL running on your testbed node.  Create a database
called "phedexcat" for user "phedex", password "phedex".  Load up the
initial schema and seed data from PHEDEX/Schema/FC-MySQL.sql".


*** Oracle TMDB deployment

The Oracle TMDB schema is in PHEDEX/Schema/Oracle*.sql.  You only need
to create the tables and indices, you don't need any of the privileges
or synonyms.  Execute command like this to load all the schema:
  (cd PHEDEX/Schema; sqlplus cms_transfermgmt_testbed9/password@devdb < OracleInit.sql)

Note that you need Perl DBI and DBD::Oracle installed as well.  The
README-Deployment.txt guide includes details on how to install them.


*** Deploying a simple node

To deploy a node you write a configuration file and then use an agent
master to manage the agents for that node.  Create the node tree
structure and the files with a utility we provide:

  PHEDEX/Utilities/DeployNode		\
    -node First				\
    -base $TESTBED			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>		\
    -cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

  PHEDEX/Utilities/NodeManager		\
    add-node				\
    -name First				\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>

  PHEDEX/Utilities/NodeManager		\
    add-export-protocol			\
    -name First				\
    -protocol cp			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>

This script creates a simple directory structure for a node, with
space for scripts, logs and file storage.  It deploys the agent
configuration file that you will use to start and stop the agents.

The node created is capable of the minimal functionality required
for a generic PhEDEx node.  It can download files to it's own
storage space from other nodes.  It can also act as file source
by injecting files into distribution, and make files available
for other nodes to download.


*** Deploying a neighbouring node

To create a network of nodes, let's deploy another one, this time
routed with the previous node:

  PHEDEX/Utilities/DeployNode		\
    -node Second			\
    -base $TESTBED			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>		\
    -cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

  PHEDEX/Utilities/NodeManager		\
    add-node				\
    -name Second			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>

  PHEDEX/Utilities/NodeManager		\
    add-import-protocol			\
    -name Second			\
    -protocol cp			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>


  PHEDEX/Utilities/NodeManager		\
    new-neigbours			\
    -name First				\
    -neighbours Second			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>


*** Deploying a management node

Data transfers through PhEDEx system as a whole rely on the action
of management agents that handle allocation of files by subscription
information, and that handle the best route through the system.

We can set up a management node for our testbed

  PHEDEX/Utilities/DeployNode		\
    -management				\
    -node GLOBAL			\
    -base $TESTBED			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>		\
    -cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

  PHEDEX/Utilities/NodeManager		\
    add-node				\
    -name GLOBAL			\
    -db <your-oracle-tns-name>		\
    -dbuser <your-oracle-user>		\
    -dbpass <your-oracle-pass>


*** Starting up the nodes

  PHEDEX/Utilities/Master -config $TESTBED/GLOBAL/node/Config start
  PHEDEX/Utilities/Master -config $TESTBED/First/node/Config start
  PHEDEX/Utilities/Master -config $TESTBED/Second/node/Config start


*** Shutting the nodes down

  PHEDEX/Utilities/Master -config $TESTBED/GLOBAL/node/Config stop
  PHEDEX/Utilities/Master -config $TESTBED/First/node/Config stop
  PHEDEX/Utilities/Master -config $TESTBED/Second/node/Config stop

**********************************************************************
** Use

*** Making test data available at a simple source node

Let's create some random file first.

  PHEDEX/Testbed/FileSources/CreateTestFiles $TESTBED/First/SE TestSet 5

Now, we need to make them available in the catalogue.

  eval $(PHEDEX/Utilities/Master -config $TESTBED/First/node/Config environ)
  for f in $TESTBED/First/SE/TestSet/*/*.xml; do
    FCpublish -d $PHEDEX_CATALOGUE -u file:$f
  done

OK, they are now known in the local catalogue of this node.  Let's
inject them into transfer.

  cp -rp $TESTBED/First/SE/TestSet/* $TESTBED/First/state/entry/inbox

*** Subscribing a node to certain data streams

CreateTestFiles creates files as necessary for registration into TMDB;
the CMS "owner" and "dataset" attributes are set to from the test set
name command line argument ("TestSet" above).  These can be used to
subscribe a data sink in the t_subscription table as follows:
  insert into t_subscription (owner, dataset, destination)
    values ('TestSet', 'TestSet', 'Second');

As all the agents are already running, the files should be picked up
for transfer and copied in a few seconds.

*** Monitoring what is going on.

The monitoring is currently rather low-level: look at the log files.
There is a web browser in Documentation/WebSite/cgi-bin/browser, but
it will require some adjusting to be able to access your private DB.

You can monitor progress with:
  tail -f $TESTBED/*/logs/*

Following the output requires a little bit of practise, especially
when the agents operate very quickly.  After the files have been
transferred you should see them in $TESTBED/Second/SE.

*** Cleaning up: removing test data from a node

  rm -fr $TESTBED/First/SE/*
  eval $(PHEDEX/Utilities/Master -config $TESTBED/First/Config environ)
  FCdeletePFN -u $PHEDEX_CATALOGUE -q "pfname like '/First/'"
  sqlplus cms_transfermgmt_testbed9/password@devdb
     delete from t_transfer_state where to_node = 'First';
     delete from t_replica_state where node = 'First';

  # FIXME: THIS DOESN'T WORK RIGHT NOW
  # PHEDEX/Testbed/FileSource/DeleteTestFiles $TESTBED/First/SE TestSet 5

*** Clearing up the database

  # FIXME: Simplify
  eval $(PHEDEX/Utilities/Master -config $TESTBED/First/Config environ)
  sqlplus cms_transfermgmt_testbed9/password@devdb
     delete from t_replica_state;
     delete from t_transfer_state;
     delete from t_transfer_history;
     delete from t_transfer_summary;
     delete from t_destination;
     delete from t_file_attributes;
     delete from t_file;
     delete from t_block;
     delete from t_block_replica;
     delete from t_subscription;

  # Or to apply the sledge-hammer in PHEDEX/Schema:
  sqlplus cms_transfermgmt_testbed9/password@devdb < OracleReset.sql
  sqlplus cms_transfermgmt_testbed9/password@devdb < OracleInit.sql
