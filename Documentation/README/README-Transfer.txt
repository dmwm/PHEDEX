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

There is FileDownloadDest as an example of such a script.  Normally
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

See also DropBox/V2-CERN-Environ.sh.

** Create state and log directories for your agent

Create directories parallel to the "scripts" directory created above
with the CVS checkout:

  mkdir -p incoming/transfer logs

** Make sure you have certificate

The example agent uses globus-url-copy to copy the files.  CMS at CERN
uses the castorgrid.cern.ch service, so you need to set up things so
that you can access files from there.  We do not yet have information
on what needs to be done to access files from other sites.

** Run the agent

  nohup scripts/DropBox/FileDownload		\
  	-state incoming/state			\
	-node TEST_Transfer			\
	-pfndest /your/pfn/script_from_above	\
	-workers 2				\
	-wanted 1G				\
	-db devdb9				\
	-dbuser cms_transfermgmt_writer		\
	-dbpass threebagsfull			\
	>> logs/ 2>&1 </dev/null &

See also DropBox/V2-CERN-{Start,Stop}.sh.  Note that for real transfer
agent you should be using different parametres, see optimisation guide
below.

** Run agent status reflector

We recommend that whenever you run agents, you also run InfoDropStatus.
You will want to point it to your "incoming" directory above.  See
V2-CERN-Start.sh for details.

** Monitor your agent

Keep an eye on the log.  If you see lines that match "stats:.*failed",
you have trouble.

** Get some data assigned to your node

You need to subscribe to data by entering a subscription into
t_subscriptions, and data will be allocated to your site.  Just
how to do this is beyond this document.

* Customising the agent

If "globus-url-copy src dest" isn't the right thing to do for your
site, you can either use a different command.  Say if you'd like to
use "foo src dest", give the options "-pass -cpcmd,foo" to the master
FileDownloadSlave.  If you'd like to use "foo -option -other src dest",
pass "-pass -cpcmd,foo,-option,-other" -- you get the idea.  If you
want to pass options to the "cpcmd", i.e. globus-url-copy, you need
to quote one layer of commas, like this:
  -pass '-cpcmd,globus-url-copy\,-p\,10\,-tcp-bs\,4194304'
(note the single quotes and backslashes).

A good use of this is for initial testing of your agent setup is to
use "-pass -cpcmd,echo".  This will cause the transfer slaves to
simply echo the file names they copy instead of doing any copying.
This will allow you to short-circuit that part of the chain, and lets
you test the rest of the setup.  (You will then need to go to the
database and reset the file states back to "1"!)

If FileDownloadSlave simply doesn't cut it for you, the next
alternative is to replace it.  You should be able to continue to use
the master, and simply replace the slave.  You do that by copying
FileDownloadDesst to /your/program, edit it to do what it needs to
do, and then pass the option "-worker /your/program" to the master.
If you need to pass the slave options, use "-pass value[,value...]"
option with the master.

Note that the FileDownloadSlave automatically replaces "sfn:" prefix
with "gsiftp:" before invoking globus-url-copy.  The file still goes
into the catalogues with the "sfn:" prefix.

* Optimising transfer performance

FileDownload should be able to reliably transfer files at your raw
network link bandwidth.  If it doesn't, optimisation is required.
Here are some hints to optimise the performance.

1) Make sure you are running the latest version of the agent.  From
time to time we fix bugs and performance issues.

2) Look at the right numbers.   Your perceived transfer rate is listed
on the "Transfer rate" monitor page at http://cern.ch/cms-project-phedex
(follow link to "Agent State").  If your agent has been up for at least
an hour, look under "aggregate rate".  That's how much data your agent
ransferred in the time.  The other rates indicate how good a PhEDEx-
citizen your agent is, showing times from when the file was marked
available to when your agent completed the transfer.  Monitor these
values to see what you are really getting out.  At the top of the page
you see the data rate out from CERN, it usually correlates well with our
transfers.  Look at similar numbers from your network monitoring.

3) Make sure your transfers aren't failing too often.  The "Other" column
in "Transfer state" monitor page is usually files whose transfer has gone
wrong.  If you are faced with unreliable networks, please contact the
developers at cms-project-phedex@cern.ch to get in touch with those who
are working in this area.

4) Make sure you are marking enough data "wanted".  We recommend 100GB
sliding window: use "-wanted 100G" option.  If your agent regularly
underruns data, you are probably transferring as much as the remote tape
system is able to deliver.  In that case you may need to increase your
sliding wanted window, but please do not increase the window beyond
100 GB without consultation on the cms-phedex-developers@cern.ch list.

5) Make sure you are using good options to globus-url-copy.  Try something
like: "-pass '-cpcmd,globus-url-copy\,-p\,10\,-tcp-bs\,4194304'" (note the
single quotes and backslashes).

6) Make sure you are transferring enough data in parallel.  We recommend
5-10 parallel workers to avoid connection overheads: use "-workers 10".
With 10 workers you should regularly see at least 20 files marked "In
Transfer" on the monitor page, peaking at 40.  If you are seeing less
than that, something else is serialising your transfers.

7) Make sure FileDownloadDest runs quickly enough.  This is one reason
transfers may get serialised.  If you've done all you can to speed this
up, and still have serialisation problem, do let us know.  You can find
out what your agents are doing with "watch ps xwwf", it shows you the
process tree in real time.  You should be seeing lots of time being spent
in "globus-url-copy", if not, you probably have a serialisation issue and
you'll known which command it is.

8) In theory, same rule applies to catalogue operations.  Let us know if
you have a problem here.
