Node Testbed deployment and user guide
========================================

1. Introduction
---------------

The goal of this document is to enable developers to set up a local, self
contained PhEDEx testbed system in which they can set up nodes, start agents,
create files and test their own agents in their local environment without
having to register new components with the global CMS distribution system.

It is possible to set up a testbed network of PhEDEx distribution nodes on a 
single machine. The nodes manage Storage Elements which are simply local 
directories, copying files between them using cp. Files are registered in a 
testbed-global POOL XML catalogue (i.e. just an easily accessible file). 
Currently updates into an Oracle Transfer Management Database are used.

This document details the deployment and use of such a testbed system.



2. Deployment
-------------

This section details the process of setting up a simple testbed, with a simple 
source of data, a simple sink of data and the management infrastructure needed 
to link agents together.



2a. Requirements
----------------

To actually run the testbed:

Linux rh73 machine with gcc32
FIXME: Need to build FC tools locally.
AFS access to CERN (for POOL File Catalogue tools)
Perl (with Perl DBI DBD::Oracle and/or DBD::MySQL installed)
MySQL
Oracle

Naturally these can both be the same machine, but they don't have to be…



2b. Setup environment and download tools
----------------------------------------

Begin to create the testbed directory structure. On your chosen testbed machine-

export NODETESTBED=/NodeTestbed [ or whatever your chosen location is
mkdir $NODETESTBED
cd $NODETESTBED

export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
cvs login
#	[ password is 98passwd ]
cvs co PHEDEX

setenv POOL_CATALOG mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat
setenv PATH ${PATH}:${NODETESTBED}/AgentToolkitExamples/NodeTestbed
setenv PATH ${PATH}:${NODETESTBED}/AgentToolkitExamples/Managers
setenv PATH /afs/cern.ch/sw/lcg/app/spi/scram:${PATH}
cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_5
eval `scram runtime -csh`
cd -

You'll need to set the environment variables whenever you use the testbed.



2c. MySQL POOL catalog
----------------------

Assuming mysql is running- create a POOL MySQL database called phedexcat
 (schema at pool.cern.ch), for user phedex, password phedex. We also need to
define the metadata schema

FCcreateMetaDataSpec -F -m
        "(Content,string),(DBoid,string),(DataType,string),
        (FileCategory,string),(Flags,string),(dataset,string),
        (jobid,string),(owner,string),(runid,string)"



2d. Oracle TMDB deployment
--------------------------

The Oracle TMDB schema can be found at $NODETESTBED/AgentDocs/V2OracleSchema.sql. Note that this schema is for the main TMDB at CERN: you will only need to create tables and indices, not grant priveleges to extra users or create synonyms.

Note that you need Perl DBI, and DBD:Oracle installed as well.


2e. Deploying a simple node
---------------------------

Now we need to create a node using a few management files:

cp ${NODETESTBED}/AgentToolkitExamples/NodeTestbed/DeployNode .
cp ${NODETESTBED}/AgentToolkitExamples/NodeTestbed/*template .

DeployNode 
-node First 
-base ${NODETESTBED} 
-db <your Oracle TNS name> 
-dbuser <your Oracle user> 
-dbpass <your Oracle password>
-cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

This script creates a simple directory structure for a node, with space for
scripts, logs, working and file storage (called SE). It deploys the agent code
necessary to run the node, and generates start.sh and stop.sh scripts that
should be used to start and stop the node's agents.

The node created is capable of the minimal functionality required for a 
generic PhEDEx node. It can download files to it's own SE-space from other
nodes. It can also act as a source of data by handling the local injection
of files into distribution.



2f. Deploying a neighbouring node
---------------------------------

A network isn't really a network with only one node, so let's deploy another

DeployNode
-node Second
-base ${NODETESTBED}
-db <your Oracle TNS name>
-dbuser <your Oracle user>
-dbpass <your Oracle password>
-cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

To form a distribution link between them we need to initialise two routes in
their respective routing tables. We can do this by

NodeManager.pl new-neighbours 
-name First 
-neighbours Second 
-db Oracle:<your Oracle TNS name> 
-user <your Oracle user>
-pass <your Oracle pass>



2g. Deploying a management node
-------------------------------

Movement of data through the PhEDEx system as a whole relies on the action
management agents that handle allocation of files by subscription information,
and that handle the determination of the best route through the system.

We can set up a management node for our testbed

DeployNode
-node GLOBAL
-management
-base ${NODETESTBED}
-db <your Oracle TNS name>
-dbuser <your Oracle user>
-dbpass <your Oracle password>
-cat mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat



2h. Starting the nodes up
-------------------------

. GLOBAL/start.sh
. First/start.sh
. Second/start.sh



2i. Shutting the nodes down
---------------------------

. GLOBAL/stop.sh
. First/stop.sh
. Second/stop.sh



3. Use
------

3a. Making test data available at a simple source node
------------------------------------------------------

Now create some test files residing at the simple source node: make sure that 
$POOL_CATALOG is set, then

cd /NodeTestbed/TestbedSource1/SE
mkdir NodeTestbedSet
cd NodeTestbedSet
CreateTestFiles
5
First
<contact string>
<user>
<password>

The CreateTestFiles script (in the NodeTestbedToolkit dir) acts as a simple fake 
source of data, generating some testfiles, registering them with the file 
catalogue and then entering them into the TMDB.



3a'. Cleaning up- removing test data from a node
------------------------------------------------

To remove test data from the system
	
[ FIXME: This actually doesn't work at the moment! ]

cd /NodeTestbed/TestbedSource1/SE
DeleteTestFiles
<contact string>
<user>
<password>		



3b. Subscribing a node to certain data streams
----------------------------------------------

CreateTestFiles adds a metadata tag to each file it creates in the TMDB- in 
t_replica_metadata it sets the key POOL_dataset to NodeTestbedSet. A sink can 
subscribe to a set of datasets by making an entry in the TMDB t_subscriptions 
table [this functionality will be offered by a web page].

In an SQL client

insert into t_subscriptions values ('Second','NodeTestbedSet');

As all the agents are running, the files should- after a few seconds- be 
picked up and transferred.



3c. Monitoring what's going on
------------------------------

The only method for doing this at the moment is at a very low level- by
watching log files. This method will be replaced by the web interface asap-
the same web interface as is used by the production system.

You can monitor the progress with

tail -f First/logs/*
tail -f GLOBAL/logs/*
tail -f Second/logs/*

but you may need to be pretty quick off the mark :o) After the files have been
transferred you should see them in Second/SE[/NodeTestbedSet/TestbedFile*]
