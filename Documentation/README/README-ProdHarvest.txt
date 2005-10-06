* Injecting data from Production into PhEDEx

This document explains how to inject Production data into PhEDEx, i.e.,  
how to make Production data files available to the CMS transfer system 
for download. 

The link between Production and PhEDEx is the Production summary file. It 
is created after successful completion of a Production job and contains 
all the information needed to inject the produced data into PhEDEx
(POOL attributes (GUID, LFN, etc), checksum and filesize).

Files can be "atomically" injected run-by-run (per job basis) as they become 
available from Production. There is no need to wait until the data have 
been published by Production. 

The injection process is initiated by dropping the Production 
summary files into the mouth of the dropbox injection chain 
(i.e., making a subdirectory in the inbox directory of 
the first dropbox agent, containing the summary file and a "go" file). The 
drops are currently done manually. An additional agent, in charge of 
monitoring production jobs looking for new summary files and 
dropping them might be useful.

Drops can be manually made using a simple script like the one below
giving as argument a directory containing the smry files to be dropped:

#!/bin/sh
inboxdir=/replace/by/inbox/dir/of/the/DropSmry/agent
smrydir=$1
for file in `\ls $smrydir` ; do
  smry=`basename $file`
  guid=`grep OUT_GUID $smrydir/$file | cut -d= -f2`
  dropdir=$inboxdir/$guid-${smry}
  mkdir $dropdir
  cp $smrydir/$smry $dropdir 
  touch $dropdir/go
  echo "drop $dropdir created"
done

Injection of files produced either in local farm or in LCG is covered in 
this document. These two modes are different in several aspects (see 
below for details). In short, local farm production requires a real (local) 
PhEDEx node with a local relational PhEDEx catalogue, while files produced
in LCG are harvested by means of a virtual PhEDEx node
which makes use of the global LCG catalogue (currently the RLS). 
In addition, files generated in LCG are bundled up in a zip archive which 
gets injected into PhEDEx while EVD files produced in local farm mode are 
individually injected and transferred. 


** Injection in local farm production mode

EVD data files must be located in the storage area associated to the
local PhEDEx node in charge of exporting data. Data must be accessible
via SRM or gridFTP protocols.

The dropbox chain DropSmry - DropTMDBpublisher (dropbox agents available 
in Toolkit/DropBox) must be run in the local PhEDEx node. See e.g. 
Custom/PIC/Config for the configuration of the agents.

Summary files of production jobs that terminated successfully appear in a
pre-specified tracking directory configured by production.
The summary files must be dropped into the inbox directory of the 
DropSmry agent. This agent parses the summary file extracting from it the 
POOL XML fragment and checksums of the EVD data files. File sizes are 
currently not available in the summary file. Thus, DropSmry calls a local site 
glue script (option -sizequery) passing as arguments the LFN and the 
output directory of the EVD files in the production jobs. See e.g. 
Custom/PIC/SIZELookup. DropSmry also takes care of publishing the EVD 
files into the local PhEDEx catalogue. It calls a local site glue script 
(option -publish) passing as arguments the local PhEDEx catalogue contact 
string, the location of the POOL XML fragment and the output directory of 
the EVD files in the production jobs. See e.g. Custom/PIC/DropSmryPublish. 
Finally, DropSmry creates a drop for DropTMDBpublisher whichs actually 
publishes the information into TMDB. 


** Injection in LCG production mode

Production jobs in LCG bundle up the output files into a single zip 
archive. The zip files are stored in LCG SEs and registered in the LCG
RLS catalogue. 

Files produced using LCG resources are (potentially) spread among many LCG 
sites. A virtual PhEDEx node (named TV_LCG_Production) has been created to 
make production files in LCG available from it. 
This way files can be transferred to a real PhEDEx node for publication and 
analysis. For an efficient export, files in LCG SEs should be available on 
disk since no PhEDEx stager agent runs for the virtual PhEDEx node. This 
should be always the case for CMS Tier-2 centers.  

Routing and Export agents for the LCG node run somewhere centrally (currently
at PIC). Several instances of the LCG drop box chain (DropSmryLCG and 
DropTMDBpublisher agents) can be run at different sites, 
typically one at every UI machine submitting production jobs to LCG. 

The configuration for the drop agents is the following:

PHEDEX_STATE=/replace/by/agents/state/directory
### AGENT LABEL=DropSmryLCG PROGRAM=Toolkit/DropBox/DropSmryLCG
 -in  ${PHEDEX_STATE}/DropSmryLCG
 -out ${PHEDEX_STATE}/DropTMDBPublisher
 -node TV_LCG_Production
 -wait 30

### AGENT LABEL=DropTMDBPublisher PROGRAM=Toolkit/DropBox/DropTMDBPublisher
 -in ${PHEDEX_STATE}/DropTMDBPublisher
 -db ${PHEDEX_DBPARAM}
 -node TV_LCG_Production
 -wait 30

Contact jose.hernandez@ciemat.es to get authorization parameters to be used
in ${PHEDEX_DBPARAM}.

The summary file of a production job that terminated successfully is 
stored in the job output sandbox. The job output sandbox must be retrieved 
by the job submitter (or an agent) and the summary file dropped into the 
inbox directory ($PHEDEX_STATE/inbox) of the DropSmryLCG agent 
(see example above for a simple script to make drops for DropSmryLCG). 
The zip file containing the EVD data files is the one injected into PhEDEx. 
DropSmryLCG creates from the information in the summary file a XML POOL 
fragment and a checksum file for the zip file which is dropped 
into the DropTMDBpublisher inbox. 
No publication into a local PhEDEx catalogue is needed. The LCG global 
catalogue acts as PhEDEx catalogue for the virtual LCG node. The Export 
agents use it to convert GUIDs into TURLs. 


Data produced in LCG and injected into the LCG virtual node migh be locally
accessible by a real PhEDEx node. However, those data are not known to PhEDEx 
as available at the real PhEDEx node since the corresponding replicas in TMDB 
do not exist and the file POOL attributes are not published in the local 
catalogue of the real PhEDEx node. When transferring those data from the LCG 
node to the real node, the copy of the files already available at the real node
can be bypassed by using the -bypass option in the Download agent. 
See README-Transfer.txt for details. 
  
