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
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
  cvs login # password is "98passwd"
  cvs co PHEDEX

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
    "mysqlcatalog_mysql://phedex:phedex@cmslcgco04/phedexcat");

(If use an XML catalogue you must *never* run parallel updates!  Any
other catalogue, mysql or rls, supports them.)

See README-Managers.txt for description of NodeManager.

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

See also Custom/CERN/V2-CERN-Environ.sh.

** Create state and log directories for your agent

Create directories parallel to the "PHEDEX" directory created above
with the CVS checkout:

  mkdir -p incoming/transfer logs

** Make sure you have certificate

The example agent uses globus-url-copy to copy the files.  CMS at CERN
uses the castorgrid.cern.ch service, so you need to set up things so
that you can access files from there.  We do not yet have information
on what needs to be done to access files from other sites.

** Run the agent

  nohup PHEDEX/Toolkit/Transfer/FileDownload		\
	-db devdb					\
	-dbuser cms_transfermgmt_writer			\
	-dbpass threebagsfull				\
  	-state incoming/transfer			\
	-node TEST_Transfer				\
	-backend Globus					\
	-command globus-url-copy,-p,10,-tcp-bs,4194304	\
	-pfndest /your/pfn/script_from_above		\
	-wanted 50G					\
	-batch-files 50					\
	-batch-size 10G					\
	-jobs 10					\
	>> logs/transfer 2>&1 </dev/null &

See also Custom/CERN/V2-CERN-{Start,Stop}.sh.  See optimisation guide
for further hints on good parameter combinations to use.

** Run agent status reflector

We recommend that whenever you run agents, you also run InfoDropStatus.
You will want to point it to your "incoming" directory above.  See
Custom/CERN/V2-CERN-Start.sh for details.

** Monitor your agent

Keep an eye on the log.  If you see lines that match "stats:.*failed",
you have trouble.

** Get some data assigned to your node

You need to subscribe to data by entering a subscription into
t_subscriptions, and data will be allocated to your site.  Just
how to do this is beyond this document.

* Customising the agent

As shown above, you can use a different command for the transfer;
the default is to use bare "globus-url-copy src dest".  Options to
"globus-url-copy" should be separated with commas.  You can also use
SRM backend with "-backend SRM".  This is probably the most efficient
transfer method.

A good use of "-command" in initial testing is to say "-command echo"
or "-command true".  The former will simply print out the file names
instead of copying, the second does zero-cost non-transfer, allowing
you to short-circuit transfers completely out and test the rest of
your setup.  (You will then need to reset all file states back to
zero or one in the database!)

You can also develop your own backend to the download agent.  See
Toolkit/Common/UtilsDownload{Globus,SRM}.pm for examples.

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

4) Make sure you are batching transfers.  This should alwawys work with
SRM interface, and should provide substantial performance improvement.
It will work with Globus backend only if you don't modify the file name
part in the transfer.  Use "-batch-files" and "-batch-size" options to
select suitable batch limits, the former sets the maximum number of
files in one transfer, the latter the maximum number of bytes.  Batch
is closed when either limit is exceeded.

5) Make sure you are marking enough data "wanted".  We recommend 50-100GB
sliding window: use "-wanted 50G" option.  If your agent regularly
underruns data, you are probably transferring as much as the remote tape
system is able to deliver.  In that case you may need to increase your
sliding wanted window, but please do not increase the window beyond
100 GB without consultation on the cms-phedex-developers@cern.ch list.
You can see if your agent is running out of data by monitoring the
"Transferable" column in the "Transfer state" web page.  If that drops
to naught, your agent has run out of data to transfer.

6) Make sure you are using good options to globus-url-copy.  Try something
like shown in the example above.

7) If batching isn't enough or doesn't work for you, make sure you are
transferring enough data in parallel.  We recommend 5-10 parallel workers
to avoid connection overheads and to parallelise catalogue operations:
use "-jobs 10".  Note however that parallel streaming writes to the same
file system have been reported to cause serious file system fragmentation
on certain Linux file systems.

8) Monitor for serialisation with "watch ps xwwf", it shows your process
tree in real time.  You should be seeing substantial amounts of time
spent in "globus-url-copy" or "srmcp"; if not, something else is
serialiasing transfers, and you'll see which command it is.

9) In theory, same rule applies to catalogue operations.  Let us know if
you have a problem here.  Using more parallel commands ("-jobs 100") may
help, but then again, you may cause rather a storm at the catalogue
server -- but note the warnings on parallel file transfers in point 7.
