Node Testbed deployment and user guide
========================================

1. Introduction
---------------

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


2b. MySQL POOL catalog
----------------------

Assuming mysql is running- create a POOL MySQL database called phedexcat
 (schema at pool.cern.ch), for user phedex, password phedex.



2b. Oracle TMDB Installation
----------------------------

Eek.




2b. Setup environment and download tools
----------------------------------------

Begin to create the testbed directory structure. On your chosen testbed machine-

	setenv NODETESTBED /NodeTestbed [ or whatever your chosen location is
	mkdir $NODETESTBED
	cd $NODETESTBED

	setenv CVSROOT \
:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/TMAgents
	
	cvs login
		[ password is 98passwd ]
	cvs co AgentToolkitExamples
	cd AgentToolkitExamples/NodeTestbed
	setenv POOL_CATALOG xmlcatalog_file:$NODETESTBED/TestbedCatalogue.xml
	setenv PATH ${PATH}:${NODETESTBED}/AgentToolkitExamples/NodeTestbed
	setenv PATH ${PATH}:${NODETESTBED}/AgentToolkitExamples/Managers
	setenv PATH /afs/cern.ch/sw/lcg/app/spi/scram:${PATH}
	cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_5
	eval `scram runtime -csh`
	cd -

You'll need to set the environment variables whenever you use the testbed…




2c. Deploying a simple (not full-functionality) source node
-----------------------------------------------------------

Now create a node. First we define the directory structure

	cd $NODETESTBED
	mkdir TestbedSource1
	mkdir TestbedSource1/scripts
	mkdir TestbedSource1/logs
	mkdir TestbedSource1/work
	mkdir TestbedSource1/SE

Now register the node with the TMDB: in an SQL client

	NodeManager.pl add-node \\
		-name TBSource1 \\
		-host $NODETESTBED/TestbedSource1/SE \\
		-cat xmlcatalog_file:$NODETESTBED/TestbedCatalogue.xml \\
		-db 'mysql:database=V2TMDB;host=<host>' \\
		-user phedex \\
		-password phedex 

DB contact strings are of the form mysql:database=V2TMDB;host=<host> for mysql, 
or Oracle:<db tns name>, or Oracle:(complete connection string) for Oracle.

[ These are basically inserted into a Perl DBI connect method call- so there are 
other methods by which you could contact databases (e.g. Oracle… ). See the Perl 
DBI, and DBD::MySQL and DBD::Oracle documentation for further details. ]



2d. Deploying a simple sink node
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

	NodeManager.pl add-node \\
		-name TBSink1 \\
		-host $NODETESTBED/TestbedSink1/SE \\
		-cat xmlcatalog_file:$NODETESTBED/TestbedCatalogue.xml \\
		-db  'mysql:database=V2TMDB;host=<host>' \\
		-user phedex \\
		-password phedex 

Now create a route between the two

	NodeManager.pl new-neighbours \\
		-name TBSink1 \\
		-neighbours TBSource1 \\
		-db 'mysql:database=V2TMDB;host=<host>' \\
		-user phedex \\
		-password phedex

Now deploy the transfer agent

	cd TestbedSink1/scripts
	cp $NODETESTBED/AgentToolkitExamples/Dropbox/ExampleTransfer* .

This will copy over two scripts: one is a master agent that handles the querying 
of the TMDB for new guids for transfer- it manages a pool of instances of the 
other script, each of which handles a given transfer.

Now register the agent with the TMDB
	
	NodeManager.pl add-agent \\
		-name TBSink_Transfer \\
		-db 'mysql:database=V2TMDB;host=<host>' \\
		-user phedex \\
		-password phedex

[ To do.. add description of deployment of routing agent… ]



2e. Deploying a simple management node
--------------------------------------

Create a simple management node with allocator agent. First define the directory 
structure

	cd $NODETESTBED
	mkdir TestbedManagement
	mkdir TestbedManagement/scripts
	mkdir TestbedManagement/logs
	mkdir TestbedManagement/work

Note that the management node has no storage space, no SE.

Now register the node with the TMDB: in an SQL client

	NodeManager.pl add-node \\
		-name TBManagement \\
		-host . \\
		-cat . \\
		-db 'mysql:database=V2TMDB;host=<host>' \\
		-user phedex \\
		-password phedex


[ To do… need to allow null entries here… ]

Now deploy the management script

	cd TestbedManagement/scripts
	cp $NODETESTBED/AgentToolkitExamples/Managers/Allocator.pl .



3. One-time Use
---------------



3a. Making test data available at a simple source node
------------------------------------------------------

Now create some test files residing at the simple source node: make sure that 
$POOL_CATALOG is set to xmlcatalog_file:$NODETESTBED/TestbedCatalogue.xml, then

	cd /NodeTestbed/TestbedSource1/SE
	CreateTestFiles \\
		5 \\
		TBSource1 \\
		'mysql:database=phedexcat;host=<host>' \\
		phedex \\
		phedex

The CreateTestFiles script (in the NodeTestbedToolkit dir) acts as a simple fake 
source of data, generating some testfiles, registering them with the file 
catalogue and then entering them into the TMDB.



3a'. Cleaning up- removing test data from a node
------------------------------------------------

To remove test data from the system
	
	cd /NodeTestbed/TestbedSource1/SE
	DeleteTestFiles \\
'mysql:database=V2TMDB;host=<host>' \\
phedex \\
phedex		



3b. Subscribing a sink node to certain data streams
---------------------------------------------------

CreateTestFiles adds a metadata tag to each file it creates in the TMDB- in 
t_replica_metadata it sets the key POOL_dataset to NodeTestbedSet. A sink can 
subscribe to a set of datasets by making an entry in the TMDB t_subscriptions 
table [this functionality will be offered by a web page].

In an SQL client

	insert into t_subscriptions values ('TBSink1','NodeTestbedSet');



3b. Using the allocator agent to allocate files to a sink node
--------------------------------------------------------------

We can run the allocator once to pick up the new files and allocate them to the 
sink based on the subscription information in the TMDB.

	cd /NodeTestbed/TestbedManagement/scripts
./Allocator.pl -once -period 1 \\
-w $NODETESTBED/TestbedManagement/work \\
-db 'mysql:database=V2TMDB;host=<host>' \\
-user phedex \\
-passwd phedex \\
-no-updates
	
This runs the allocator agent once without making any updates on the TMDB… it 
should display a log indicating that it found and allocated the 5 new files 
created above. Note that if we hadn't made a subscription above, and if we 
hadn't specified no-updates, the allocator would make a blank entry in the 
subscriptions table to warn a (human) distribution manager that a new dataset 
had entered distribution and needed toe be allocated to a destination…


3c. Using transfer agents to transfer data to a simple sink node
----------------------------------------------------------------



4. Steady-state use
-------------------
