* Setting up agents

This document describes how to administer the drop box agents.  The
intended audience are the CMS data managers that need to inject files
into the transfer system.  Most of the agents are site-independent and
can be run anywhere by anyone.

** Related documents.

README-Overview.txt explains where this document fits in.
README-Operations.txt explains how things are done at CERN.
README-RefDB.txt explains how to inject data from RefDB into transfer.
README-Transfer.txt explains how to set up the sample transfer agents.
README-Funnel.txt explains how to merge files prior to transfer.
README-Schedule.txt explains how files are scheduled.

** Agent Overview

The PHEDEX transfer system is based on a database (TMDB) and a number
of agents.  The general idea is that each agent performs a simple and
clearly defined task robustly.  More complex tasks are decomposed into
simpler tasks and agents that act as a chain.  The agents can be
stopped at any time without loss of information, and will pick up
their previous state and continue where they left off when restarted.
Where possible agents perform all operations with commit-or-rollback
semantics: either fully or none at all.  The agents handle errors
robustly and gracefully, so they are unlikely to get wedged or die
from "fatal" errors; normally they simply back off and try again
later, and log alerts or warnings for operator attention.

There are two main types of agents: some agents process files, others
pass messages and state through the database.  Some agents are a
mixture of both.  The file-processing type agents are called "drop
box" agents, as the handle "drops", directories with files in them, in
the sprit of design of mail transfer agents such as postfix.  Drops
are always processed safely such that there is no risk of data loss.
Upstream processes wanting to give agents work create drops in their
inbox directory.  Once a drop is marked complete with a "go" file in
it, the agent moves the drop into its internal work queue, carries out
its actions on it, and then moves the drop to the outbox.  If there
are downstream agents, completed drops are passed to their inboxes.

Most drop box agents handle one drop at a time as the task is
typically simple and takes little time.  When tasks take longer, there
is normally a front-end agent that performs preparation and possibly
also results gathering, and passes the work to a number of internal
worker slaves that handle the jobs in parallel on the background.
When the time-consuming task is best handled asynchronously by
external software (e.g. a mass-storage stager system), the agents may
start asynchronous operations on all available drops in their work
queue, and then let drops progress when the action has completed.

[FIXME: Merge Old: The agents are based on the "drop box" model: they
have an inbox directory where they receive tasks.  Each "drop" is a
subdirectory in the inbox.  When the drop is complete (a "go" file
appears), the drop is moved over to the work queue.  Completed tasks
(with "done" file in them) are moved to an outbox, from where they
passed to the next agent if there is one, or destroyed.  Tasks in the
work queue are processed; some sequentially and immediately passed on,
some on the background and periodically checked until the task is
completed.  Tasks that fail are marked "bad", and will not be
considered again until the "bad" marker is removed.  All this is done
robustly to avoid any data loss.]

** Transfer Overview

The expected minimal drop processing chain is something like this:

0) Drop source: reconstruction, simulation or RefDB tools.
1) DropXMLUpdate: Expand XML fragment and PFNs to full paths.
2) DropCastorStageIn: Stage the files in from the mass storage.
3) DropCastorChecksum: Generate file checksums if they are missing.
4) DropCastorGridPFN: Update PFNs to form expected by transfer agents
   (sfn://castorgrid.cern.ch/castor/some/file).
5) DropCatPublish: Publish catalogue fragment to local/rls catalogue.
6) DropTMDBPublish: Insert the files into the transfer.

If you wish to merge files into larger uncompressed zip archives for
better storage and transport efficiency, use DropFunnel between steps
3 and 4 as described in README-Funnel.txt.

** Prerequisites

Setting up the data distribution agents:
1) Get this pack of agents.
2) Setup a machine to run the agents.
3) Get POOL tools.  There's an environment setup script.
4) Setup ORACLE database and accounts with the TMDB schema.
5) Determine a catalogue contact string.

It is possible to run all the agents on one computer, or use several
systems.  Typically one would use a single computer as the load from
these agents is typically negligible.  You can use also bridge to
agents on other computers with scp or rfio by giving next agent's
directory as scp:user@host:/remote/dir or rfio:/remote/dir.

** Setting up

  mkdir -p /some/new/place
  cd /some/new/place
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/TMAgents
  cvs login # password is "98passwd"
  cvs co -d scripts TMAgents/AgentToolkitExamples

[FIXME: Setup machine and directories.  See V2 part in
  README-Operations.txt and/or ../NodeTestbed/readme]
[FIXME: Setup environment script.  See V[12]-CERN-Environ.sh.]
[FIXME: Setup ORACLE.  See end of V[12]-CERN-Environ.sh; need DBD/Oracle.]
[FIXME: Setup catalogue.  See V[12]-CERN-Environ.sh.  Either use RLS,
  like everybody does now, or setup local POOL catalogue, e.g. MySQL.]

** Starting the agents

[FIXME: See V2 part in README-Operations.txt and V2-CERN-Start.sh.]

** Stopping the agents

[FIXME: See V2 part in README-Operations.txt and V2-CERN-Stop.sh.]

** Generating drops

[FIXME: Read README-RefDB.txt.]

** Feeding drops to the agents

[FIXME: See TRSyncFeed in README-RefDB.txt.]

** Examining logs

** FIXME: Configure netlogging

** Agent descriptions

DropNullAgent

	This agent does nothing.  However, because it's a drop box
	agent, it can link between agents.  You can use it copy drops
	to one or more receiving agents, also bridging between hosts
	using scp and rfio protocols.  Any drop box agent will of
	course be able to do the same.  If given a statistical wait
	model, the agent acts as a holding or delay queue between two
	agents, the main reason for the existence of this agent.

DropXMLUpdate

	This agent rewrites and updates the XML fragments in the
	drops.  It is typically the first agent in a drop box chain.
	It expands the XML fragments generated by CMS production into
	full POOL XML catalogues by adding the missing XML preamble
	and trailer.  It also updates pre-POOL 1.4 catalogues to the
	modern format.  Finally, it converts relative PFNs (./File) in
	the catalogue to full paths using an additional summary file;
	the summary file must define "EVDS_OutputPath" to the mass
	storage directory into which the data producer uploaded the
	files.  This makes XML fragments from production jobs suitable
	for further downstream processing.

DropCastorStageIn

	Stage in Castor every PFN mentioned in the XML catalogues of
	the drops that pass by.  The drops are sent downstream once
	all the files in the drop have been successfully staged in.
	This agent ensures that transfer agents can immediately access
	the files when the files are inserted into the transfer.

DropCastorChecksum

	Check that there is a checksum file and that it has an entry
	for every PFN mentioned in the XML catalogue of every drop
	that passes through.  If checksums are missing, download the
	files from castor, calculate the checksums, and update the
	checksum file.  Note that existing contents of the checksum
	file are assumed to be valid, entries are added only for files
	without checksums.  Assumes the files are stored in Castor
	[FIXME: add option -cpcmd to allow others?].

DropCastorGridPFN

	Convert the PFNs in the drops that pass through.  Changes
	/castor/cern.ch to sfn://castorgrid.cern.ch/castor/cern.ch so
	that transfer agents can use globus-url-copy and CastorGrid
	service to read the files from CERN.

DropCatPublisher

	This agent publishes the XML catalogue into the site's POOL
	catalogue.  Before files can be inserted into the transfer
	system, they must be known in the local catalogue -- normally
	either the RLS or a MySQL catalogue.  This should be the same
	catalogue as specified in TMDB as the site's catalogue
	contact.

DropTMDBPublisher

	This agent publishes the XML drops into the transfer system
	once they are known in the local catalogue.  It injects the
	files and all their meta data into TMDB, the transfer
	management database (a ORACLE database).  The files are
	inserted into TMDB as unallocated; the allocation and
	scheduling agents handle the assignment of the files to
	destinations.

DropFunnel
DropFunnelWorker
DropFunnelStatus
	See README-Funnel.txt.

ExampleTransfer
ExampleTransferSlave
ExampleCleaner
	See README-Transfer.txt.

[FIXME: Ranking]
[FIXME: Mr. Proper]

** Agent options

[FIXME: describe common options.]

** Support

If you have any questions or comments, please contact Lassi A. Tuura
<lassi.tuura@cern.ch> or Tim Barrass <tim.barrass@physics.org>.  You
are welcome to file bug reports and support requests at our Savannah
site at http://savannah.cern.ch/projects/phedex
