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

setenv NODETESTBED /NodeTestbed [ or whatever your chosen location is
mkdir $NODETESTBED
cd $NODETESTBED

setenv CVSROOT :pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/TMAgents
	
cvs login
#	[ password is 98passwd ]
cvs co AgentToolkitExamples
cd AgentToolkitExamples/NodeTestbed
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


2e. Deploying a simple source node
----------------------------------

Now create a node. First we define the directory structure

cd $NODETESTBED
mkdir TestbedSource1
mkdir TestbedSource1/scripts
mkdir TestbedSource1/logs
mkdir TestbedSource1/work
mkdir TestbedSource1/SE

Now register the node with the TMDB: in an SQL client

NodeManager.pl add-node \
-name TBSource1 \
-cat $POOL_CATALOG \
-host $NODETESTBED/TestbedSource1/SE \
-db <contact string> \
-user <user> \
-password <password> 

DB contact strings are of the form mysql:database=V2TMDB;host=<host> for mysql, 
or Oracle:<db tns name>, or Oracle:(complete connection string) for Oracle.

[ These are basically inserted into a Perl DBI connect method call- so there are 
other methods by which you could contact databases (e.g. Oracle… ). See the Perl 
DBI, and DBD::MySQL and DBD::Oracle documentation for further details. ]

Now we need to deploy a routing agent that will maintain our routing tables for 
this node

cd $NODETESTBED/TestbedSource1/scripts
cp $NODETESTBED/AgentToolkitExamples/Routing/Node-Router.pl .

and add this agent to the TMDB

NodeManager.pl add-agent \
-name Source1_Router \
-db <contact string> \
-user <user> \
-password <password>

We then need to start the router running

./Node-Router.pl -node TestbedSource1 
-db <Oracle tns name only>
-w $NODETESTBED/TestbedSource1/work 
-dbuser <user> 
-dbpasswd <password> 
>& $NODETESTBED/TestbedSource1/logs/log &

Now we need to create the chain of agents that will handle the injection of data
into distribution at this node.

cp $NODETESTBED/AgentToolkitExamples/DropBox/DropTMDBPublisher .
cp $NODETESTBED/AgentToolkitExamples/DropBox/DropCatPublisher . 
cp $NODETESTBED/AgentToolkitExamples/DropBox/DropXMLPublisher .
cp $NODETESTBED/AgentToolkitExamples/DropBox/DropFileCheck .
cp $NODETESTBED/AgentToolkitExamples/DropBox/Utils* .

Then create the script start.sh, with content:

#!/bin/sh

export PHEDEX_BASE=<your path to testbed>
export PHEDEX_STATE=${PHEDEX_BASE}/work
export PHEDEX_TMDB=<db tns nams>
export PHEDEX_USER=<db user>
export PHEDEX_PASS=<db password>
export PHEDEX_LOGS=../logs
export PHEDEX_NODE=TestbedSource1
export PHEDEX_CATALOGUE=mysqlcatalog_mysql://phedex:phedex@localhost/phedexcat

# Set general entry point.  Don't mess it unless we have to, we don't
# want to change this if there happens to be drops going on.
[ -e $PHEDEX_STATE/entry       ] || ln -s xml $PHEDEX_STATE/entry
[ -e $PHEDEX_STATE/xml         ] || mkdir -p $PHEDEX_STATE/xml
[ -e $PHEDEX_STATE/exist       ] || mkdir -p $PHEDEX_STATE/exist
[ -e $PHEDEX_STATE/cat         ] || mkdir -p $PHEDEX_STATE/cat
[ -e $PHEDEX_STATE/tmdb        ] || mkdir -p $PHEDEX_STATE/tmdb

[ -e $PHEDEX_STATE/export      ] || mkdir -p $PHEDEX_STATE/export

# Update catalogue entries
nohup `dirname $0`/DropXMLUpdate                \
        -in ${PHEDEX_STATE}/xml                 \
        -out ${PHEDEX_STATE}/exist              \
        -wait 7                                 \
        >> ${PHEDEX_LOGS}/xml 2>&1 </dev/null &

# Check the files actually exist and have non-zero size
nohup `dirname $0`/DropFileCheck          \
        -in ${PHEDEX_STATE}/exist               \
        -out ${PHEDEX_STATE}/cat                \
        -wait 7                                 \
        >> ${PHEDEX_LOGS}/exist 2>&1 </dev/null &

# Publish into catalog.
nohup `dirname $0`/DropCatPublisher             \
    -catalogue ${PHEDEX_CATALOGUE}              \
    -in ${PHEDEX_STATE}/cat                     \
    -out ${PHEDEX_STATE}/tmdb           \
    -wait 7                                     \
    >> ${PHEDEX_LOGS}/cat 2>&1 </dev/null &

# Publish into TMDB
nohup `dirname $0`/DropTMDBPublisher            \
    -db "${PHEDEX_TMDB}"                        \
    -dbuser ${PHEDEX_USER}              \
    -dbpass ${PHEDEX_PASS}                      \
    -in ${PHEDEX_STATE}/tmdb            \
    -node ${PHEDEX_NODE}                        \
    -version 2                          \
    -wait 7                                     \
    >> ${PHEDEX_LOGS}/tmdb 2>&1 </dev/null &

# Export-side agents
nohup `dirname $0`/FileDiskExport             \
        -state ${PHEDEX_STATE}/export           \
        -node ${PHEDEX_NODE}                    \
        -db "${PHEDEX_TMDB}"                    \
        -dbuser ${PHEDEX_USER}                \
        -dbpass ${PHEDEX_PASS}                  \
        -wait 7                                 \
        >> ${PHEDEX_LOGS}/export 2>&1 </dev/null &


# script ends here ...

then run it with

bash
. start.sh

You can also create the script stop.sh, containing

#!/bin/sh
export PHEDEX_STATE=<your path to testbed>/work
ls -d $PHEDEX_STATE/* | xargs -i touch '{}'/stop

Any drops placed at the head of the chain- in 
$NODETESTBED/TestbedSource1/work/entry/inbox- will get injected into
distribution.



2f. Deploying a simple sink node
--------------------------------

Now create a simple sink node with a transfer agent. First define the directory 
structure

cd $NODETESTBED
mkdir TestbedSink1
mkdir TestbedSink1/scripts
mkdir TestbedSink1/logs
mkdir TestbedSink1/work
mkdir TestbedSink1/SE

Now register the node with the TMDB: in an SQL client

NodeManager.pl add-node \
-name TestbedSink1 \
-host $NODETESTBED/TestbedSink1/SE \
-cat $POOL_CATALOG \
-db <contact string> \
-user <user> \
-password <user> 

Now create a route between the two

NodeManager.pl new-neighbours \\
-name TestbedSink1 \
-neighbours TestbedSource1 \
-db <contact string> \
-user <user> \
-password <password>

Now deploy the transfer agent

cd TestbedSink1/scripts
cp $NODETESTBED/AgentToolkitExamples/DropBox/FileDownload* .

This will copy over two scripts: one is a master agent that handles the querying 
of the TMDB for new guids for transfer- it manages a pool of instances of the 
other script, each of which handles a given transfer. We also need to define a
script that creates local pfns- in this case you need to edit the file
FileDownloadDest to map files onto your local Sink1 SE directory. The following
shows how I had to do it

diff FileDownloadDest~ FileDownloadDest
19c19
< local=/data/test/files/$subpath/$dataset/$owner/$lfn
---
> local=/data/barrass/TestbedSink1/SE/$subpath/$dataset/$owner/$lfn

[ FIXME: echo at end changed so it doesn't read file:$local as well! ]

Now register the agent with the TMDB
	
NodeManager.pl add-agent \
-name TestbedSink1_Transfer \
-db <contact string> \
-user <user> \\
-password <password>

And again we need to deploy a routing agent that will maintain our routing tables for
this node

cd $NODETESTBED/TestbedSink1/scripts
cp $NODETESTBED/AgentToolkitExamples/Routing/Node-Router.pl .

and add this agent to the TMDB

NodeManager.pl add-agent \
-name Sink1_Router \
-db <contact string> \
-user <user> \
-password <password>

We then need to start the router running

./Node-Router.pl -node TestbedSink1
-db <Oracle tns name only>
-w $NODETESTBED/TestbedSource1/work
-dbuser <user>
-dbpasswd <password>
>& $NODETESTBED/TestbedSink1/logs/log &

and also the transfer agent

./FileDownload 
-state $NODETESTBED/TestbedSink1/work/inbox 
-db <tns name> 
-dbuser <user>
-dbpass <password>
-pfndest FileDownloadDest 
-node TestbedSink1 
-wanted 100G 
-pass -cpcmd,cp
>& $NODETESTBED/TestbedSink1/logs/transferlog &



2g. Deploying a simple management node
--------------------------------------

Create a simple management node with a allocating and file routing agents. First define the directory 
structure

cd $NODETESTBED
mkdir TestbedManagement
mkdir TestbedManagement/scripts
mkdir TestbedManagement/logs
mkdir TestbedManagement/work
mkdir TestbedManagement/work/inbox

Note that the management node has no storage space, no SE.

Now register the node with the TMDB: in an SQL client

NodeManager.pl add-node \
-name GLOBAL \
-host nohost \
-cat nocat \
-db <contact string> \
-user <user> \
-password <user>

Now deploy the management scripts

cd TestbedManagement/scripts
cp $NODETESTBED/AgentToolkitExamples/Managers/Allocator.pl .
cp $NODETESTBED/AgentToolkitExamples/DropBox/FileRouter .
cp $NODETESTBED/AgentToolkitExamples/DropBox/Utils* .

and start them up

./Allocator.pl
-db <Oracle tns name only>
-user <user>
-password <password>
-w $NODETESTBED/TestbedManagement/work
>& $NODETESTBED/TestbedManagement/logs/log &

./FileRouter
-db <Oracle tns name only>
-dbuser <user>
-dbpass {password}
-node GLOBAL
-state $NODETESTBED/TestbedManagement/work/inbox
>& $NODETESTBED/TestbedManagement/logs/routerlog &




3. One-time Use
---------------



3a. Making test data available at a simple source node
------------------------------------------------------

Now create some test files residing at the simple source node: make sure that 
$POOL_CATALOG is set, then

cd /NodeTestbed/TestbedSource1/SE
CreateTestFiles
5
TestbedSource1
<contact string>
<user>
<password>

The CreateTestFiles script (in the NodeTestbedToolkit dir) acts as a simple fake 
source of data, generating some testfiles, registering them with the file 
catalogue and then entering them into the TMDB.



3a'. Cleaning up- removing test data from a node
------------------------------------------------

To remove test data from the system
	
cd /NodeTestbed/TestbedSource1/SE
DeleteTestFiles
<contact string>
<user>
<password>		



3b. Subscribing a sink node to certain data streams
---------------------------------------------------

CreateTestFiles adds a metadata tag to each file it creates in the TMDB- in 
t_replica_metadata it sets the key POOL_dataset to NodeTestbedSet. A sink can 
subscribe to a set of datasets by making an entry in the TMDB t_subscriptions 
table [this functionality will be offered by a web page].

In an SQL client

insert into t_subscriptions values ('TestbedSink1','NodeTestbedSet');

As all the agents are running, the files should- after a few seconds- be 
picked up and transferred.



4. Steady-state use
-------------------
