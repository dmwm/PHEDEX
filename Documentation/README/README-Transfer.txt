* Using the download agent

This document explains briefly how to use the download agent.  It is
a fairly capable agent that supports several data transfer backends
such as globus-url-copy, srmcp and dccp.  It talks to site-specific
glue scripts to talk to the file catalogue.  It is assumed that are
you are using a catalogue local to your site, though you can also
share one with other sites.  However do note that you should not use
EDG RLS catalogue, these tools will most likely kill it in no time.

This document does not explain how to deploy a node; please refer
to relevant documentation (mainly README-Deployment.txt) for those
details.  This document only explains how to use the FileDownload
agent.

Once your node is deployed, you will need the following for downloads:
 * A script to determine the download destination at your site
 * A script to verify the download completed successfully
 * A script to clean up failed downloads
 * A script to publish downloaded files to your local catalogue

It is assumed that you already know which transfer method you wish
to use (globus-url-copy or srmcp) and the infrastructure for using
these exists.  You should first check that hand copies of files
using these tools succceed.

We also assume your local catalogue is up and running.  This must be
a relational POOL catalogue (MySQL, ORACLE), not a XML catalogue, but
can and should be shared with PubDB.  The files in this catalogue
should be registered with PFNs that are directly usable with your
analysis jobs, which probably are different from transfer PFNs.  For
example at CERN catalogue contains paths of the form
   rfio:/castor/cern.ch/cms/PCP04/<owner>/<dataset>/<lfn>
whereas transfers are made using PFNs of the form
   gsiftp://castorgrid.cern.ch/castor/cern.ch/cms/PCP04/...
   srm://www.cern.ch/castor/cern.ch/cms/PCP04/...

Your site-local scripts need to perform such remappings.

**********************************************************************
** Prepraration

*** Decide the destination location for your files

Let's assume you will be copying your files to the storage area
   /data/files/<owner>/<dataset>/<lfn>

This is mapped to your analysis jobs as dcap:/data/files/... and
to your gridftp servers as gsiftp://host.site.edu/data/files/...

*** Write a script that maps URLs to your site-local name

Write a "DownloadDest" script that produces the TURL (transfer URL)
name for the destination at your site.  In this case the path should
be gsiftp://host.site.edu/data/files/<owner>/<dataset>/<lfn>.  The
script gets all the necessary values as command line arguments, in
the form of "argument=value", and must print out the path after
making sure the destination directory exists.

Good examples available:
  Custom/CERN/FileDownloadDest
  Testbed/Standalone/NodeDownloadDest

You do also get the source file's PFN as "pfn=..." argument,
but it's generally not wise to rely on those: various sites
use different directory layout conventions, so you'll end up
in chaos if you mirror their paths.  Instead always derive
the path name from file attributes (LFN, dataset, owner, ...).

*** Write a script to verify download success

All file transfer tools are unreliable, so you shouldn't rely
on the their exit code.  Instead provide a script to verify
whether the file was successfully transferred.  Typically you
should verify that the file size is correct, but not check the
checksum (it's expensive to do so for all files, and size check
flags the vast majority of errors).

The script gets the following arguments:
  1: exit status from the transfer tool (ignore this!)
  2: destination pfn as produced by your script above
  3: file size as stored in the database
  4: file checksum as stored in the database

If the script exits with non-zero exit code, the transfer is
considered failed, otherwise sucessful.  There's no need to
print out anything.

Good examples available:
  Custom/CERN/FileDownloadVerify
  Testbed/Standalone/NodeDownloadVerify

*** Write a script to clean up failed transfers

This script is invoked under two circumstance: once before all
downloads, and once after failed transfers.  It should remove
the destination file as most transfer tools refuse to copy over
existing files.

The script gets two arguments:
  1: reason, either "pre" or "post"
  2: destination pfn as produced by your script above

Your script should forcefully remove the destination file.  The
exit code from the script is ignored.  There is no need to print
out anything.  In particular note that the destination file may
not even exist, so don't be too picky.

*** Write a script to publish downloaded files to your local catalogue

Once the file is successfully downloaded, you need to register it
to your local catalogue.  FileDownload produces a XML catalogue
fragment with all the file information.  In this XML file the PFN
has been set to the destination PFN you generated, which is most
likely not the path you want to register to your catalogue.  So
you will want to replace it first with something else, then
publish the file to your main catalogue.  You may also wish to
change file permissions and ownership, or record the file for
later processings of that kind.

The script gets these arguments:
  1: file guid
  2: destination pfn as produced by your script above
  3: path of the temprary XML catalogue

Note that if you want to pass other arguments, for instance the
contact string for your own catalogue, you can arrange that
when invoking FileDownload.  Those arguments will precede the
arguments from FileDownload.

If the script exits with non-zero exit code, the download is
considered failed, otherwise a success.

Good examples available:
  Custom/CERN/FileDownloadPublish
  Testbed/Standalone/NodeDownloadPub

**********************************************************************
** Running the agent

*** Make sure you have certificate

Normally you will use globus-url-copy or some other tool that requires
a grid certificate to copy files.  CMS at CERN uses castorgrid.cern.ch
service, so you need to set up things so you can access the files.  As
the site exporting data to you determines where you connect to, you
don't need to worry abut that -- just make sure you are in the correct
(CMS) VO, and thus in everybody's gridmap files.

Note that if you use proxy certificates, you need to set X509_USER_PROXY
and unset X509_USER_CERT and X509_USER_KEY.  If you don't use proxies,
you probably want to do exactly the opposite.  These and other settings
should be part of your node's "### ENVIRON" configuration block.

*** Run the agent

Typical agent configuration looks like this:
  ### AGENT LABEL=download-master PROGRAM=Toolkit/Transfer/FileDownload
   -node ${PHEDEX_NODE}_Transfer
   -ignore ${PHEDEX_NODE}_MSS
   -db ${PHEDEX_TMDB}
   -dbuser ${PHEDEX_TMDB_USER}
   -dbpass ${PHEDEX_TMDB_PASS}
   -backend Globus
   -command globus-url-copy,-p,3,-tcp-bs,2097152
   -pfndest $PHEDEX_CUSTOM/FileDownloadDest
   -delete $PHEDEX_CUSTOM/FileDownloadDelete
   -validate $PHEDEX_CUSTOM/FileDownloadVerify
   -publish $PHEDEX_CUSTOM/FileDownloadPublish,$PHEDEX_CATALOGUE
   -wanted 150G
   -jobs 7
   -wait 7

You manage the agent just like the others:
  Utilities/Master -config your/config/file start [download-master]
  Utilities/Master -config your/config/file stop [download-master]

*** Monitor your agent

Keep an eye on the log.  If you see lines that match "stats:.*failed",
you have trouble.

*** Get some data assigned to your node

You need to subscribe to data by entering a subscription into
t_subscription, and data will be allocated to your site.  Just
how to do this is beyond this document.

**********************************************************************
** Customising the agent

*** Commands

By default the backend uses the basic command to make transfers
("globus-url-copy", "srmcp" or "dccp").  You can provide a different
command, for instance with additional options, with the "-command"
option as shown above.  Arguments to the program should be separated
with commas, as shown above.

A good use of "-command" in initial testing is to say "-command echo"
or "-command true".  The former will simply print out the file names
instead of copying, the second does zero-cost non-transfer, allowing
you to short-circuit transfers completely out and test the rest of
your setup.  (You will then need to reset all file states back to
zero or one in the database!)

You can select a different backend with the -backend option.
Available backends are "Globus", "SRM" and "DCCP".  SRM is the
most efficient transfer method -- provided it's properly configured
at your site!

You can also develop your own backend to the download agent.  See
Toolkit/Common/UtilsDownload{Globus,SRM,DCCP}.pm for examples.

You can get a rough idea of what various things can be achieved
with the different site-specific scripts by looking around in the
different Custom/<Site> and Testbed/Standalone directories.

*** Targeted downloads

You can use the -ignore and -accept options to specify which nodes
downloads are ignored and accepted from.  By default nothing is
ignored and everything is accepted.  The options are independent
such that -ignore list is always processed first, and then if and
only if the node passes the -accept list, the download is processed.
Both options accept comma-separated list of node names; wildcards
are not recognised.

Normally you would have a special "upload" agent for transfers from
your MSS node to the disk buffer (or pseudo-buffer) node, so you
would say "-ignore ${PHEDEX_NODE}_MSS" on your buffer downloader.

**********************************************************************
** Optimising transfer performance

FileDownload should be able to reliably transfer files at your raw
network link and disk bandwidth.  If it doesn't, optimisation is
required.  Here are some hints to optimise the performance.

1) Make sure you are running the latest version of the agent.  From
time to time we fix bugs and performance issues.

2) Look at the right numbers.   Your perceived transfer rate is listed
on the "Transfer rate" monitor page at http://cern.ch/cms-project-phedex
(follow link to "Agent State").  If your agent has been up for at least
an hour, look under "aggregate rate".  That's how much data your agent
ransferred in the time.  Momentary transfer rates and numbers shown by
network monitoring tools are intersting, but much less important.

The other rates on the monitoring web page indicate how good a PhEDEx-
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

4) Make sure there's no undue delays with your transfer commands.  We've
seen all kinds of misconfigurations.  A globus-url-copy made by hand on
a file that's staged in should being immediately -- no delays of several
seconds etc.  You can measure raw globus-url-copy bandwidth to your site
with Testbed/Bandwidth/GUCTest; it allows you to transfer to /dev/null
or file system, make sure to test both separately to understand possible
discrepancies.  It may happen for instance that you can write very fast
to /dev/null, but disk writes are slower; in this case investigate the
disk mount options on the gridftp servers.  The bottom line is that this
test program should be able to fill your network pipe with ease; there's
no point in addressing performance problems in PhEDEx until this test
produces maximum possible transfer rate for you.

5) Make sure you are batching transfers.  This should alwawys work with
SRM interface, and should provide substantial performance improvement.
It will work with Globus backend only if you don't modify the file name
part in the transfer and you are using Globus toolkit 3.x or newer (we
don't know of anybody who does!).  Use "-batch-files" and "-batch-size"
options to select suitable batch limits, the former sets the maximum
number of files in one transfer, the latter the maximum number of bytes.
Batch is closed when either limit is exceeded.

6) Make sure you are marking enough data "wanted".  We recommend 150GB
sliding window: use "-wanted 150G" option.  If your agent regularly
underruns data, you are probably transferring as much as the remote tape
system is able to deliver.  In that case you may need to increase your
sliding wanted window, but please do not increase the window beyond
200 GB without consultation on the cms-phedex-developers@cern.ch list.
You can see if your agent is running out of data by monitoring the
"Transferable" column in the "Transfer state" web page.  If that drops
to naught, your agent has run out of data to transfer.

7) Make sure you are using good options to globus-url-copy.  Try something
like shown in the example above.  Do not use excessive number of parallel
streams, get your network configured correctly instead.  You should not
need more than 20 parallel streams -- and that's number of jobs times
the number of streams in each job!  2 MB TCP bufers are likely to be a
good starting point.

8) If batching isn't enough or doesn't work for you, make sure you are
transferring enough data in parallel.  We recommend 20 parallel streams
with 2 MB buffers each, for instance 5 parallel workers with 4 parallel
streams each.  Parallel jobs helps avoid connection overheads and to
parallelise catalogue operations. Note however that parallel streaming
writes to the same file system have been reported to cause serious file
system fragmentation on certain Linux file systems (ext3, xfs should
fare better).

9) Monitor for serialisation with "watch ps xwwf", it shows your process
tree in real time.  You should be seeing substantial amounts of time
spent in "globus-url-copy" or "srmcp"; if not, something else is
serialiasing transfers, and you'll see which command it is.

10) All catalogue operations are performed in parallel since PhEDEx V2.1.
There should not be any bottlenecks here, but note that your catalogue
may get hit very hard, especially if you are exporting data.
