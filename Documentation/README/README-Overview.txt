* Documentation overview

The PHEDEX system consists of several components:
 1) Transfer management database (TMDB), currently version is 2.
 2) Transfer agents that move files from site to site.
 3) Management agents, in particular the allocator agent which assigns
    files to destinations based on site data subscriptions, and
    routing agent to maintains file transfer routing information.
 4) Tools to manage transfer requests; CMS/RefDB/PubDB specific.
 5) Drop box agents for managing files locally, for instance as files
    arrive from a transfer request or a production farm, including any
    processing that needs to be done before they can be made available
    for transfer: massaging information, staging in files, calculating
    missing checksums, registering files into the catalogues, injecting
    into TMDB.

** Overview documentation

AgentDocs/overview.tex describes the whole system.

AgentDocs/routing.tex describes the file routing.

AgentDocs/schema.tex describes TMDB schema and how transfer agents
should interpret and maintain the information.

** Management documentation

AgentToolkitExample/Managers/readme (a RTF file) describes the
management agents.

AgentToolkitExample/NodeTestbed/readme (a RTF file) describes how to
set up a V2 testbed system.

AgentToolkitExample/DropBox/README-Operations.txt describes current
operations practises for CMS transfers; currently only for CERN, but
hopelly more later on.

** Detailed documentation

AgentToolkitExample/DropBox/README-RefDB.txt describes transfer
request management, and more specifically, how to inject data from
RefDB into transfer.

AgentToolkitExample/DropBox/README-Agents.txt describes the drop box
agents.

AgentToolkitExample/DropBox/README-Funnel.txt is being written and
will describe how to merge files prior to transfer.

AgentToolkitExample/DropBox/README-Schedule.txt is being written and
will describe how files are scheduled.

AgentToolkitExamples/RLSTest/README.txt describes a stand-alone
test-bed setup for RLS performance benchmarking.

** Support

If you have any questions or comments, please contact Lassi A. Tuura
<lassi.tuura@cern.ch> or Tim Barrass <tim.barrass@physics.org> or the
developers list at cms-phedex-developers@cern.ch.  You are welcome to
file bug reports and support requests at our Savannah site at
  http://savannah.cern.ch/projects/phedex
