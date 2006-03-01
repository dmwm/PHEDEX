* Generating data from the RefDB

This document explains how to extract data from the CMS RefDB database
and inject it into the PHEDEX transfer system.

NOTE: THIS PROCEDURE HAS BEEN SUPERCEDED.  See for example
  Custom/CERN/TransferPublishedMess.txt

** Background

We have several utilities to help in inserting data into the transfer
system from RefDB and CERN Castor MSS.  "RefDB tools" allow the user
to generate summary information to guide insertion of data.  "Drop*"
tools are used to process that summary information and use it to
insert data files into the transfer system.

The objective of the RefDB tools is to simulate the output of a CMS
reconstruction or simulation farm: they produce output in the same
format, in packets of information we call "drops", as a normal job
would.  Each drop must have at least two files, a XML catalogue
fragment and a summary file, and optionally a checksum file.  The
catalog fragment lists the files created by the job, using relative
PFNs.  The summary file defines the base directory in which those
files exist at that site, at CERN a path in Castor.  Note that if at
all possible, do not lose the file checksum information -- it is very
expensive to regenerate.

The expected minimal drop processing chain is then something like
this:
  - DropXMLUpdate: Expand the XML fragment to complete POOL catalogue
    and remap relatives PFNs to full paths using the summary file.
  - DropCastorFileCheck: Ensure all the files actually exist.
  - DropCastorGridPFN: Update PFNs to sfn://castorgrid.cern.ch.
  - DropCatPublish: Publish the XML to the local/rls catalogue.
  - DropTMDBPublish: Publish the files for transfer.

Then the files are available in PHEDEX TMDB database.  Note that the
definition of the "drop" is CMS-independent.  What is inside the drops
is probably largely CMS-specific, but by the time the information
makes it into TMDB, it is again largely CMS-independent.  However no
matter which system you use to process the files, you will need to do
pretty much the same thing, so you might as well formulate them much
like CMS does :-)

** Overview of the RefDB tools

Typically data is inserted into the transfer system using the
following process:
  1. Prepare a transfer request
     1.1. Create the request
     1.2. Assign data destination
     1.3. Assign data to the request
  2. Generate the drops for the request
  3. Feed the drops to the transfer chain
  4. Afterwards, verify everything has been transferred correctly
  5. Even more afterwards, verify the definition of the transfer
     request hasn't changed (e.g. the expansion of wildcard patterns)

For CMS, the first step typically consists of receiving a group of
datasets to be transferred to some destination.  From this list you
need to find out which owner/dataset pairs that exactly corresponds
to.  That list then has to be mapped into RefDB assignments.  The
tools automate large parts of this task, but it still takes some human
decision-making along the way.

The drops are generated from RefDB using the POOL XML catalogue
fragments saved from the jobs that have already run.  The utilities
try to figure out where those files are stored at CERN Castor, and
records that location in a summary file.  RefDB does not at present
record the checksum data, so none is generated.

If the drops arrive from running jobs, you would normally have all the
three files automatically without any additional work.

As files from the assignments are uploaded to CERN from the production
sites, the list of the files available on Castor changes.  Therefore,
if not all the files for the transfer request are available, "sync"
time to time newly available drops into the transfer chain.  You can
also use the same tools to verify that everything has indeed been
transferred correctly.

There are some additional utilities, RefDBList and RefDBAssignments,
that provide easy browsing access to specific preparation steps.

All the "dataset.owner" patterns are interpreted as shell wildcards.
So you can use something like bt03_b_*.* to list all datasets that
match "bt03_b_*" and then all owners for those datasets.  If you don't
use any wildcards, then the match is required to be exact.  Typical
transfer requests use lengthy data selection patterns such as
"bt03_b_*.bt_*{PU761,Hit75[012],DST813_2}*". If the pattern is of the
form "@file", then the tools will read white-space separated list of
patterns from "file".  You can use any number and mixture of patterns
and "@file" arguments on the command line.  Note that wildcards given
on the command line may need to be quoted so your shell doesn't try to
expand them.

** Typical transfer request process

Transfer requests are simply directories in which the tools track the
information.  Each request has a ticket (DIR/Request/Ticket) that
tracks all the actions carried on the request.  We never remove
information, only "cancel" previous choices.  Normally you can keep on
invoking the commands and they will add to the ticket, you use an
"-r" option to indicate you want to reset/cancel previous ones.

There's nothing particular about where the requests are.  You can
create a request anywhere you like, and call it anything you like.
For management purposes we keep the requests on AFS in a single place,
at /afs/cern.ch/cms/aprom/phedex/TransferRequests.  We call the
requests YYYY-MM-DD-LABEL-ID, where YYYY-MM-DD is date when the
request is made, LABEL is some semi-meaningful label, and ID is three
first letters of your AFS user id (LAT, BARrass, WILdish, ...).  In
any case the ticket tracks who did what and on which computer.

The tools are in /afs/cern.ch/cms/aprom/phedex/PHEDEX/Toolkit/Request.
All TR* commands should respond to "-h" option to get help.

1) You create a new empty request with TRNew:
     cd /afs/cern.ch/cms/aprom/phedex/TransferRequests
     ../PHEDEX/Toolkit/Request/TRNew 2004-08-20-TEST-LAT

2) Add destination information -- where the data is wanted.  This
   will be the list of TMDB nodes that will be subscribed to this
   data.
     ../PHEDEX/Toolkit/Request/TRNewLoc 2004-08-20-TEST-LAT FNAL_MSS

3) Add data:
    ../PHEDEX/Toolkit/Request/TRNewData -p 2004-08-20-TEST-LAT \
    'bt03_udsg*.bt_*{PU761,Hit75[012],Hit245,DST813_2}*'

   TRNewData doesn't print out the result.  You can either:
    A) cat 2004-08-20-TEST-LAT/Request/Ticket
    B) ../PHEDEX/Utilities/RefDBList -p <the-same-list-of-patterns-or-@files>
    C) ../PHEDEX/Utilities/RefDBAssignments -v $(../PHEDEX/Utilities/RefDBList <args>)

   As mentioned, you can run the commands more than once to add more
   destinations / data.  Use -r option to cancel previous choices.
   Use rm -fr request to start over.

4) Once you've added all the data, you can generate drops for them.
     ../PHEDEX/Toolkit/Request/TRSyncDrops 2004-08-20-TEST-LAT

5) Update TMDB subscriptions for the requests:
     ../PHEDEX/Toolkit/Request/TRSyncAllocs \
        cms t_files_for_transfer 2004-08-20-TEST-LAT

6) Log in as cmsprod@lxgate04.cern.ch to feed the drops into distribution:
      cd /afs/cern.ch/cms/aprom/phedex/TransferRequests
      source /data/V2Nodes/PHEDEX/Custom/CERN/V2-CERN-Environ.sh
      ../PHEDEX/Toolkit/Request/TRSyncFeed \
        $PHEDEX_STATE cms t_files_for_transfer 2004-08-20-TEST-LAT

   NOTE: Use the -x option to see what it would do, but without doing
   anything for real ("dry-run").

7) If there were drops marked "NotReady" (= files not available in
   Castor), you can keep on running TRSyncFeed exactly the same way.
   If more files have become available, it will feed the ready ones to
   the transfer chain.

8) To update the status of all the files in the request browser:
     ../PHEDEX/Toolkit/Request/TRSyncWeb \
       $PHEDEX_STATE cms 2004-08-20-TEST-LAT

   You can then see the status of the request in the browser at
      http://cern.ch/cms-project-phedex/cgi-bin/requests

** Utilities

RefDBExpand expands "dataset.owner" patterns into full list of pairs.
It takes the same options as TRNewData (-f, -p, -a).  RefDBAssignment
maps full dataset.owner names into lists of assignments.  See examples
above.

You can use TRFileCheck to check any drops anywhere to see their
current status -- including drops in the state directories of drop box
agents (see README-Agents.txt).  Use it something like this:
  echo 2004-08-20-TEST-LAT/Drops/*/* |
    xargs -n100 TRFileCheck $PHEDEX_STATE cms t_files_for_transfer

** Downloading tools from CVS

  setenv CVSROOT :pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
  cvs login # password is "98passwd"
  cvs co PHEDEX
