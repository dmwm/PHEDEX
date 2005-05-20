* Injecting data from Production into PhEDEx

This document explains how to inject Production data into PhEDEx, i.e.,  
how to make Production data files available to the CMS transfer system 
for download. 

The link between Production and PhEDEx is the Production summary file. It 
is created after successful completion of a Production job and contains 
all the information needed to inject the produced data into Phedex.

Files are "atomically" injected run-by-run (per job basis) as they become 
available from Production. There is no need to wait until the data have 
been published by Production. 

The information needed to inject a file into PhEDEx is: the POOL 
attributes (GUID, LFN, etc) , checksum and filesize.  

Files must be located in the storage area accessible to the 
local PhEDEx node in charge of exporting data. The injection process is 
initiated by dropping the Production summary files into the mouth of the 
dropbox injection chain (making a subdirectory in the inbox directory of 
the first dropbox agent containing the summary file and a "go" file). The 
drops are currently done manually. An additional agent, in charge of 
monitoring production jobs looking for new summary files, copying if 
necessary the output data into an storage area managed by PhEDEx, and 
dropping the summary files might be created in the future.

Injection of files produced either in local farm or in LCG is covered in 
this document. These two modes are different in several aspects (see 
below for details). In short, local farm production requires a real (local) 
PhEDEx node with a local relational PhEDEx catalogue, while files produced
in LCG are harvested by means of a virtual PhEDEx node which makes use of a
global LCG catalogue (currently the RLS). In addition, files generated in LCG
are bundled up in a zip archive which gets injected into PhEDEx while files
produced in local farm mode are individually injected and transferred. 

** Injection in local farm production mode

The dropbox chain DropSmry - DropTMDBpublisher (dropbox agents available 
in Toolkit/DropBox) must be run in the local PhEDEx node. See e.g. 
Custom/PIC/Config for the configuration of the agents.

Summary files of production jobs that terminated successfully appear in a
pre-specified directory configured by production.
The summary files must be dropped into the inbox directory of the 
DropSmry agent. This agent parses the summary file extracting from it the 
POOL XML fragment and checksums of the EVD data files. File sizes are 
currently not available in the summary file. DropSmry calls a local site 
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
sites. A virtual PhEDEx node has been created to harvest production files  
in LCG and transfer them to a real PhEDEx node. For an efficient harvest, 
files in LCG SEs should be available on disk since no PhEDEx stager agents 
can run at the remote LCG sites. 

Routing and Export agents for this node run somewhere centrally (currently
at PIC). Several instances of the LCG drop box chain (DropSmryLCG and 
DropTMDBpublisher agents) can be run at different sites, 
typically one at every UI machine submitting production jobs to LCG. 
See Custom/LCGProduction/Config for the configuration. 

The summary file of a production job that terminated successfully is 
stored in the job output sandbox. The job output sandbox must be retrieved 
by the job submitter (or an agent) and the summary file dropped into the 
inbox directory of the DropSmryLCG agent (see
Custom/LCGProduction/drop_summary_files.sh for a simple script to make
drops for DropSmryLCG). The zip file containing the EVD 
data files is the one injected into PhEDEx. DropSmryLCG creates a 
XML POOL fragment for the zip file which is dropped into the 
DropTMDBpublisher inbox. If the checksum of the zip file is not available
in the summary file, the zip file should be checksummed at the harvesting 
real PhEDEx node. 
No publication into a local PhEDEx catalogue is needed. The LCG global 
catalogue acts as PhEDEx catalogue for the virtual LCG node. The Export 
agent uses it to convert GUIDs into TURLs. 

Some LCG sites hosting data produced in LCG run a real PhEDEx node, eg. PIC. 
It might be for those sites that the LCG storage is the same as the storage 
managed by PhEDEx so that part of the data managed by the PhEDEx LCG virtual 
node is already local to the real PhEDEx node. 
In this case, when injecting data into the virtual node, the corresponding
replicas for the data local to the real node should also be created in TMDB.
For this purpose, DropSmryLCG makes use of a file (option -nodesmap) which
maps real PhEDEx nodes to LCG storage accessible to PhEDEx at that node.
See Custom/LCGProduction/NodesFile. The first column is the real node name 
and the second is a regular expression to match a PFN to be considered local
to the PhEDEx real node. When injecting a file in TMDB for the virtual PhEDEx
node, if the regular expresion matches the PFN of the file being injected, the
corresponding replica will be created for the matching real PhEDEx node. 
 
  
