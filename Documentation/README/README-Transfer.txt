* Using the example transfer agent

This document explains briefly how to use the example transfer agent.
It is a simple but fully functional transfer agent.  It uses
globus-url-copy to copy files from source to destination, and
automatically maintains catalogue coherence: if the source and
destination nodes use the same catalogue such as RLS, it simply adds
replica information.  If the catalogues are different, the file meta
data information is automatically copied between the catalogues.

To use the agent you will need to:
 * Get the agent tools
 * Get your nodes registered in V2 database
 * Write a script that maps URLs to your site-local name
 * Set up your environment
 * Create state and log directories for your agent
 * Make sure you have certificate
 * Run the agent
 * Monitor your agent

You can also customise the agent to some degree.

** Get the agent tools

  mkdir -p /some/new/place
  cd /some/new/place
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/TMAgents
  cvs login # password is "98passwd"
  cvs co -d scripts TMAgents/AgentToolkitExamples

** Get yourself registered in V2 database

You need to first register your node in the V2 database.  You need to
know the node name, a host key, and the POOL catalogue contact string
for your site.  The node name is an arbitrary label for your transfer
node, usually something like "FNAL_Transfer".  The host string is a
key that identifies all the files in the catalogue belonging to your
site.  Typically it is the name of the host (e.g. host name part of
"sfn://host/file" type names), or some other unique portion of the
path.

  insert into t_nodes values ("TEST_Transfer", "/data/files/",
    "xmlcatalog_file:/data/files/catalog.xml");

(Note that using an XML catalogue means you *must* not run parallel
transfer agents!  Any other catalogue, mysql or rls, can.)

See Managers/readme (a RTF document) description of NodeManager.pl.

** Decide the destination location for your files

In this case, we will use local disk, /data/files.  Obviously for a
real site you will want something better, e.g. files on a storage
element, such as "sfn://myhost.world.xyz/cms".

** Write a script that maps URLs to your site-local name

There is ExamplePFNScript as an example of such a script.  Normally
you would remove some initial part of the incoming path, make sure the
destination directory exists, and append the rest of the path.  The
example script rewrites sfn://castorgrid.cern.ch/castor/cern.ch into
/data/test/files.

Note that longer-term you will receive files from more than one
source, so somewhat more sophisticated logic is required.

** Set up your environment

You need to have POOL tools (1.6.2 or later) and ORACLE set up
correctly.  At CERN the magic incantations are:

  eval `cd /some/where/POOL_1_6_2; scram -arch rh73_gcc32 runtime -sh`
  . /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

See also DropBox/V[12]-CERN-Environ.sh.

** Create state and log directories for your agent

Create directories parallel to the "scripts" directory created above
with the CVS checkout:

  mkdir state logs

** Make sure you have certificate

The example agent uses globus-url-copy to copy the files.  CMS at CERN
uses the castorgrid.cern.ch service, so you need to set up things so
that you can access files from there.  We do not yet have information
on what needs to be done to access files from other sites.

** Run the agent

  nohup scripts/DropBox/ExampleTransfer -state state \
	-db devdb9 \
	-node TEST_Transfer \
	-pfndest /your/pfn/script_from_above \
	>> logs/ 2>&1 </dev/null &

See also DropBox/V[12]-CERN-{Start,Stop}.sh.

** Monitor your agent

Keep an eye on the log.  If you see lines that match "stats:.*failed",
you have trouble.

** Get some data assigned to your node

Beyond the scope of this description.  See Managers/readme (a RTF
document) description of Managers/Allocator.pl and
Managers/ReallocationManager.pl.

* Customising the agent

If "globus-url-copy src dest" isn't the right thing to do for your
site, you can either use a different command.  Say if you'd like to
use "foo src dest", give the options "-pass -cpcmd,foo" to the master
ExampleTransfer.  If you'd like to use "foo -option -other src dest",
pass "-pass -cpcmd,foo,-option,-other" -- you get the idea.

A good use of this is for initial testing of your agent setup is to
use "-pass -cpcmd,echo".  This will cause the transfer slaves to
simply echo the file names they copy instead of doing any copying.
This will allow you to short-circuit that part of the chain, and lets
you test the rest of the setup.  (You will then need to go to the
database and reset the file states back to "1"!)

If ExampleTransferSlave simply doesn't cut it for you, the next
alternative is to replace it.  You should be able to continue to use
the master, and simply replace the slave.  You do that by copying
ExampleTransferSlave to /your/program, edit it to do what it needs to
do, and then pass the option "-worker /your/program" to the master.
If you need to pass the slave options, use "-pass value[,value...]"
option with the master.

Note that the ExampleTransferSlave automatically replaces "sfn:"
prefix with "gsiftp:" before invoking globus-url-copy.  The file still
goes into the catalogues with the "sfn:" prefix.
