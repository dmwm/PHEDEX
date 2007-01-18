* Using the download agent

This document explains briefly how to use the PhEDEx download agent.
The agent coordinates transfers using commands such as srmcp, ftscp,
globus-url-copy, or dccp.  Site-specific glue scripts are called to
interact with the site, and a XML storage map guides file placement.
In general the agent should run near the storage it operates on; this
is not a technical requirement, the constraints are operational.

Please refer to other documentation, mainly README-Deployment.txt, for
node deployment instructions.  This document explains only how to use
the FileDownload agent.

Once your node is deployed, you will need the following for downloads:
 * A script to verify the download completed successfully
 * A script to clean up failed downloads

It is assumed you already know which transfer method you wish to use
(globus-url-copy, srmcp or ftscp) and the infrastructure for using
these exists and is being tested by the transfer heart beat monitor.

As of version 2.3, PhEDEx assumes trivial file catalogue; old-style
POOL catalogues are no longer supported.  The trivial file catalogue
specifies the mapping between the CMS hierarchical logical file names,
the location of the files in your storage, and the access paths for
different purposes.

**********************************************************************
** Prepraration

*** Decide the destination location for your files

Let's assume the following storage layout:
  Storage: /data/files/<logical-file-name>
  Local access: dcap:/data/files/...
  SRM: srm://host.site.edu:8443/srm/managerv1?SFN=/data/files/...

*** Write trivial file catalogue for your site

Examples of trivial catalogue are available in the SITECONF
repository, for example SITECONF/CERN/PhEDEx/storage.xml.  Given the
above definitions, your storage.xml would look like this:

*NOTE*: SRM paths must include the ":8443/srm/managerv1?SFN=" part.

<storage-mapping>
  <lfn-to-pfn protocol="direct" path-match="/+(.*)"
    result="/data/files/$1"/>
  <lfn-to-pfn protocol="srm" chain="direct" path-match="/+(.*)"
    result="srm://host.site.edu:8443/srm/managerv1?SFN=/$1"/>

  <pfn-to-lfn protocol="direct" path-match="/+data/files/+(.*)"
    result="/$1"/>
  <pfn-to-lfn protocol="srm" chain="direct" path-match=".*\?SFN=(.*)"
    result="$1"/>
</storage-mapping>

*** Write a script to verify download success

All file transfer tools produce unreliable exit codes.  The transfer
verification script makes an independent check of successful file
transfer.  Typically you should verify the size of the file in your
storage is correct, but not check the file checksum -- the latter
should be done only when file corruption is probable.

Sites using srmcp can use a slightly more complex verification model
instead of file size check to reduce load on the storage name space.

The verification script gets the following arguments:
  1: exit status from the transfer tool
  2: destination pfn as produced by your trivial catalogue
  3: file size as stored in the PhEDEx database
  4: file checksum as stored in the PhEDEx database

If the script exits with non-zero exit code, the transfer is
considered failed, otherwise sucessful.  There's no need to
print out anything.

Good examples available:
  SITECONF/CERN/PhEDEx/FileDownloadVerify
  SITECONF/FNAL/PhEDEx/FileDownloadVerify

*** Write a script to clean up failed transfers

The clean-up script is invoked under two circumstances: once before
all downloads, and once after failed transfers.  It should remove the
destination file: most transfer tools refuse to copy over existing
files.

The script gets two arguments:
  1: reason, either "pre" or "post"
  2: destination pfn as produced by your script above

Your script should forcefully remove the destination file.  The exit
code from the script is ignored and it should not print out anything.
The destination file may not exist, so don't be too picky.

When using Castor-2, do not use "srm-advisory-delete", it only deletes
the file on the stager, but does not remove a tape copy or Castor name
space entry.  Instead, convert the SRM path into a /castor path, then
issue "stager_rm -M $pfn" followed by "rfrm $pfn".  This resets any
lingering SRM state from interrupted transfers before the file is
deleted.

Good examples available:
  SITECONF/CERN/PhEDEx/FileDownloadDelete
  SITECONF/FNAL/PhEDEx/FileDownloadDelete

**********************************************************************
** Running the agent

*** Make sure you have certificate

Normally a grid certificate is required for transfers.  You need to
use a certificate that is allowed to read and write to your storage.
In particular make sure you use a certificate in the CMS VO and have
registered yourself to the VORMS.

You manage all aspects of access to your storage, and don't need to
worry about paths anybody else will use.  Sites exporting data to you
will determine where your downloads come from.

Typically you will want to set up a long-lived proxy in myproxy, then
extract short-lived proxies from it.  The "### ENVIRON" block in your
agent configuration should point X509_USER_PROXY to the short-lived
proxy and unset X509_USER_KEY and X509_USER_KEY.  You can use a cron
job to renew the short-lived proxy once an hour; for details please
see SITECONF/CERN/PhEDEx/ProxyRenew.

*** Run the agent

Typical agent configuration looks like this:
  ### AGENT LABEL=download-master PROGRAM=Toolkit/Transfer/FileDownload
   -db          ${PHEDEX_DBPARAM}
   -nodes       ${PHEDEX_NODE}_Buffer
   -ignore      ${PHEDEX_NODE}_MSS
   -storagemap  ${PHEDEX_CONF}/storage.xml
   -delete      ${PHEDEX_CONF}/FileDownloadDelete
   -validate    ${PHEDEX_CONF}/FileDownloadVerify
   -backend     SRM
   -command     srmcp,-x509_user_proxy=$X509_USER_PROXY

You manage the agent just like the others:
  Utilities/Master -config your/config/file start [download-master]
  Utilities/Master -config your/config/file stop [download-master]

*** Monitor your agent

Keep an eye on the log.  If you see lines that match "failed", you
have trouble.

*** Get some data assigned to your node

The PhEDEx "Dev" instance hosts small scale data samples that are used
to verify site configuration.  Notify cms-phedex-admins@cern.ch when
you are ready for tests.  Large scale data transfers are made through
PRS requests.

**********************************************************************
** Customising the agent

*** Commands

By default the backend uses the basic command to make transfers
("globus-url-copy", "srmcp" or "dccp").  You can provide a different
command, for instance with additional options, with the "-command"
option as shown above.  Arguments to the program should be separated
with commas, as shown above.

A good use of "-command" in initial testing is to say "-command echo"
or "-command true".  The former will simply print out the arguments
instead of copying, the second does zero-cost non-transfer, allowing
you to short-circuit transfers completely out and test the rest of
your setup.

You can select a different download backend with the -backend option.
Available backends are "Globus", "SRM" and "DCCP"; FTS is currently
supported by using "SRM" backend with "ftscp" as the copy command, a
proper "FTS" backend will come soon.  CMS requires you use SRM-based
file transfers.

You can also develop your own backend to the download agent.  See
Toolkit/Common/UtilsDownload{Globus,SRM,DCCP}.pm for examples.

You can get a rough idea of what various things can be achieved with
the different site-specific scripts by looking around in the different
SITECONF directories.

*** Targeted downloads

You can use the -ignore and -accept options to specify which nodes the
agent interacts with.  By default no nodes are ignored and all are
accepted.  The -ignore list is processed first, and then if and only
if the node passes the -accept list, the download is processed.  Both
options accept comma-separated list of node names; SQL wildcards are
supported ("%" for any string, "_" for any character).

A site with tape storage will normally have a special "upload" agent
for transfers from the MSS node to the Buffer node, and would use
"-ignore ${PHEDEX_NODE}_MSS" with the Buffer download agent as shown
in the example above.  A disk-only storage node does not need to use
such an option.

*** Bypassing downloads

You can use the "-bypass <script>" option to bypass a file copy. This
is useful when the file to be transferred is already available at the
site but is not yet known to PhEDEx.

The agent invokes the bypass script immediately before the download.
The script gets the source and destination PFNs as arguments.  If the
script prints out something, the agent considers the file downloaded
and uses the printed-out value as the new destination PFN.  Normally
the script would print out either the source PFN or nothing.  The
post-transfer validation will use the replaced destination PFN.

**********************************************************************
** Optimising transfer performance

FileDownload is capable of transferring files in excess of your
network and disk bandwidth limits.  If your hardware is underused, you
may need to optimise the settings.  This section includes some hints
to optimise performance.

1) Make sure you are running the latest version of the agent.  From
time to time we fix bugs and performance issues.

2) Check the transfer quality.  Follow the "Transfer Quality Plots"
link on the monitor web page (http://cern.ch/cms-project-phedex,
follow link to "Status").  Performance tuning makes sense only if your
site is experiencing negligible number of transfer failures.

3) Look at the right numbers.  The transfer rate seen by PhEDEx is
listed under "Aggregate Rate" on the "Transfer Rate" page in the
monitor.  If your agent has been up for at least an hour, the numbers
should be reliable.  There is also a "Transfer Rate Plots" link where
you can see historical performance.

If the rate monitoring shows errors, your first priority should be to
reduce errors.  If the rate monitoring page shows expired transfers to
or from your site, your site is unable to complete its transfers in a
reasonable time.  Possible causes are overload or transfers simply
taking too long.  Either way, many errors or expired transfers and
long transfer backlog will lead PhEDEx to shun or even isolate your
site.  The agent will throttle itself down if it sees a significant
number of errors, and this may further reduce transfer rates to and
from your site.

If your network is inherently unreliable, please contact the project
at hn-cms-phedex@cern.ch for advice.

4) PhEDEx is not a network monitor.  Momentary transfer rates and
numbers shown by network monitoring tools are interesting, but much
less important.  What matters is transfers successfully completed.

5) If your agents have ran for a while, check the daily reports.  They
give an account of how good a PhEDEx citizen your agents are.  In
particular, you'll see average hourly rates, the average size of the
pending queue and how long PhEDEx estimates your transfers will take
to complete.

6) Make sure there are no undue delays with your transfer commands.
Executing srmcp manually on a file that PhEDEx claims is staged should
copy the file immediately and at reasonably good rate.  The bottom
line is it should easy to fill your network bandwidth for days on end
with a handful of concurrent srmcp or globus-url-copy commands, with
no performance drops.  If that's not the case, you need to tune your
storage systems better.  The number of parallel GridFTP streams and
TCP buffer sizes are set in the SRM storage servers, not on the client
side; changing the parameters for srmcp doesn't affect SRM transfers.
Make sure the servers are properly configured, including the choice of
appropriate file system and tuning parameters.

7) Make sure you are batching transfers.  This is the default with the
SRM backend.  Use "-batch-files" and "-batch-size" options to select
suitable batch limits, the former sets the maximum number of files in
one transfer, the latter the maximum number of bytes.  A batch is
closed when either limit is exceeded.

8) Monitor your agents using "watch ps xwwf".  You should see
substantial amount of time spent in "srmcp".  If that is not the case,
something else may be forcing your transfers going serial, and you
should see which command that is.
