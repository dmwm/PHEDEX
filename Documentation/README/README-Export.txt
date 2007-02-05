* Using the export agents

This document explains briefly how to use the export agents.  This is
the more complex side of data transfers, as you typically need to
handle tape mounts and file stage-in in an efficient manner.  The
whole process is highly dependent on your site configuration: which
mass storage system you use, your disk configurations, how the data is
exported out etc.

You need to provide a storage mapping file, which the various agents
use to translate file names.  See README-Catalogue.txt for details.

This document does not explain how to deploy a node; please refer to
relevant documentation (mainly README-Deployment.txt, but also
README-Transfer.txt) for those details.  This documents only explains
how to use the various export agents, and you will probably need some
amount of creativity to apply the instructions.

It is assumed that the data you are serving for transfer is already in
your storage, has been registered as replicas in PhEDEx TMDB for your
node.  How to get that far is documented in README-ProdHarvest.txt.

**********************************************************************
** CERN export configuration

CERN serves data from a castor pool accessible from castorgrid.cern.ch
with srm and gsiftp.

The CMS downloads are mapped to a specific castor service class via
the gridmap file on castorgrid.  The export agents at CERN manage file
stage-in so all files are guaranteed to be on disk before transfers
begin.  The stage-in agent monitors file requests ("wanted" files) and
stages in files, then marks them available for transfer.

This is, all in all, the following agents:
  1: FileCastorStager.New: stage-in agent, marks files staged in
     (state=1 or state=0 on t_xfer_replica) as appropriate
  2: FilePFNExport: generate transfer names for "wanted" files

**********************************************************************
** Export configurations

First you need to answer which download methods you plan to support.
You must support at least "srm".

Option A: Your Buffer and MSS nodes are shared

 1: Stage-in agent observes wanted files and stages them in, and
    reflects into TMDB which files are available for transfer.  The
    Castor equivalent is Custom/Castor/FileCastorStager.New.  FNAL has
    in their SITECONF another agent for dCache/Enstore.  A purely
    SRM-based stage-in agent is available via
    Custom/SRM/FileSRMStager.


Option B: You have no MSS node, only a disk node (e.g. a Tier 2 or Tier 3)

 1: PFN-generation agent: Toolkit/Transfer/FileExport.  This agent
    will generate the TURLs for your site using the TFC, enabling
    other sites to retrieve data from you.
