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

To serve the data out you need a "master" export agent plus supporting
agents.  We first explain how this is set up at CERN for CMS, and then
what one can do on other sites.

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
  1: FileCastorExport: main export agent that marks files available
  2: FileCastorStager.New: stage-in agent, marks files staged in
     (state=1 or state=0 on t_xfer_replica) as appropriate
  3: FilePFNExport: generate transfer names for "wanted" files

**********************************************************************
** Export configurations

First you need to answer which download methods you plan to support.
You must support at least "srm".

Option A: Your Buffer and MSS nodes are shared

 1: Pseudo-agent uploads files from mss to transfer node.  Use
    Toolkit/Transfer/FileMSSUpload.

 2: Master export agent flags files available for transfer.  You can
    use Custom/Castor/FileCastorExport -- there's no castor-specific
    code in it, it just assumes you are working as if you had castor.

 3: Stage-in agent observes wanted files and stages them in, and
    reflects into TMDB which files are available for transfer.  The
    Castor equivalent is Custom/Castor/FileCastorStager.New.  FNAL
    has in their SITECONF another agent for dCache/Enstore.  A
    purely SRM-based stage-in agent is also in the works.

 4: PFN-generation agent produces TURLs for the outbound files.  Use
    Toolkit/Transfer/FilePFNExport.  This uses the storagemap.xml
    trivial file catalogue.

Option B: Your transfer and MSS nodes are actually separate.

 MSS node:
   1.1-3: As steps 2-4 in A above.  PFN-generation in step 4 produces
          URLs for the internal MSS->buffer transfers.

 Transfer node:
   2.1: Run separate download agent instance for MSS->buffer transfers.
   2.2: Export agent marks files available: use Toolkit/Transfer/FileDiskExport.
   2.3: PFN-generation agent: similar to the MSS->buffer one, except
        generates externally usable names.

  To run targeted download agents, use "-accept" and "-ignore" options
  to restrict which nodes each agent can serve.

Option C: You have no MSS node, only a disk node (e.g. a Tier 2 or Tier 3)

 1: Use disk based export: Toolkit/Transfer/FileDiskExport
 2: PFN-generation agent: Toolkit/Transfer/FilePFNExport.  See above.
