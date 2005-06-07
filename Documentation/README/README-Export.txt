* Using the export agents

This document explains briefly how to use the export agents.  This
is the more complex side of data transfers, as you typically need
to handle tape mounts and file stage-in in an efficient manner.
The whole process is highly dependent on your site configuration:
which mass storage system you use, your disk configurations, how
the data is exported out with gsiftp etc.

You need to provide once site-specific script, to look up files
in your local catalogue.  Make sure you are using a reasonably
capable catalogue implementation, as the agents may make very
heavy access on the catalogue at times.

This document does not explain how to deploy a node; please refer
to relevant documentation (mainly README-Deployment.txt, but also
README-Transfer.txt) for those details.  This documents only
explains how to use the various export agents, and you will
probably need some amount of creativity to apply the instructions.

It is assumed that the data you are serving for transfer is already
known at your site, for instance in PubDB, and registered to your
local POOL catalogue, and known as replicas on your site.  How to
get that far is documented elsewhere (README-ProdHarvest.txt).

To serve the data out you need a "matser" export agent and a few
additional ogents.  We first explain how this is set up at CERN
for CMS, and then what one can do on other sites.

**********************************************************************
** CERN export configuration

CERN serves data from a castor pool accessible from castorgrid.cern.ch
with gsiftp.  Downloads are also possible with SRM, but they end up
going out from castorgrid as well.

The CMS downloads are mapped to a specific castor pool via the gridmap
file on castorgrid.  The export agents at CERN manage file stage-in for
the pool so all files are guaranteed to be on disk before transfers
begin.  The stage-in agent monitors file requests ("wanted" files) and
stages in files, then marks them available for transfer.

This is, all in all, the following agents:
  1: FileCastorExport: main export agent that marks files available
  2: FileCastorStager: stage-in agent, marks files staged in (state=1
     or state=0 on t_replica_state) as appropriate
  3: FilePFNExport: generate transfer names for "wanted" files
  4: FileCastorChecksum: compute checksums on staged-in files if the
     checksums are missing (for old files imported without checksums)
  5: FilecCastorFilesize: determine file sizes from castor directory
     for files imported without file size (yes, a horrible kludge)

You should not need to run the latter two at your site.

**********************************************************************
** Export configurations

First you need to answer which download methods you plan to support.
You must support at least "gsiftp" and optionally "srmcp".

Option A: You buffer and mss nodes are shared

 1: Pseudo-agent uploads files from mss to transfer node.  Use
    Toolkit/Transfer/FileMSSUpload.

 2: Master export agent flags files available for transfer.  You
    can use Custom/Castor/FileCastorExport -- there's no castor-
    specific code in it, it just assumes you are working as if you
    had castor.

 3: Stage-in agent observes wanted files and stages them in, and
    reflects into TMDB which files are available for transfer.  The
    Castor equivalent is Custom/Castor/FileCastorStager, but there's
    considerably simpler version being tested for the new Castor
    stager, most likely much better starting point for others (not yet
    committed, so ask if you want it).

    This may not be the best approach for SRM/dCache.  We'll expand
    on this later as experience builds.

 4: PFN-generation agent produces TURLs for the outbound files.
    Use Toolkit/Transfer/FilePFNExport.  This requires PFN lookup
    glue script that queries your local catalogue and generates file
    names for outbound transfers.  You can easily copy the CERN one
    (Custom/CERN/PFNLookup).

Option B: Your transfer and mss nodes are actually separate.

 MSS node:
   1.1-3: As steps 2-4 in A above.  PFN-generation in step 4 produces
          URLs for the internal MSS->buffer transfers.

 Transfer node:
   2.1: Run separate download agent instance for MSS->buffer transfers.
   2.2: Export agent marks files available: use Toolkit/Transfer/FileDiskExport.
   2.3: PFN-generation agent: similar to the MSS->buffer one, except
        generates externally usable names.

  Note that V2.1 added targeted download agents, so you can run different
  download agent instances for different node links.

Option C: You have no MSS node, only a disk node (e.g. a Tier 2 or Tier 3)

 1: Use disk based export: Toolkit/Transfer/FileDiskExport
 2: PFN-generation agent: Toolkit/Transfer/FilePFNExport.  See above.

