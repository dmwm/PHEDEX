* Setting up agents

This document describes how to administer the drop box agents.  The
intended audience are the CMS data managers that need to inject files
into the transfer system.  Most of the agents are site-independent and
can be run anywhere by anyone.

** Related documents.

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

[FIXME: Get agent code.]
[FIXME: Setup machine and directories.]
[FIXME: Setup environment script.]
[FIXME: Setup ORACLE.]
[FIXME: Setup catalogue.]

On each computer running the fake agents, unpack this tar ball.  You
will find the subdirectories "scripts", "logs", "incoming" and
"models".  "scripts" contains everything the agents need to run.  The
agent logging output will be sent under "logs" by default.  "incoming"
is where "drops" are received: it has a subdirectory for each agent
task queue and state, for example "incoming/xml".  The "model"
directory contains the statistical models for the fake agents.

The environment for the agents is set up by scripts/environ.csh.  This
sets the parameters such as RLS contact string, and sources the POOL
environment.  Update this as necessary.

Two scripts, scripts/start.csh and scripts/stop.csh, start and stop
all the agents.  Under scripts/examples, there are other variants of
these for multi-host (e.g. WAN) tests.  These scripts automatically
source scripts/environ.csh.

If you run or source start.csh, the required agent chain is started.
Running stop.csh will shut them down cleanly without losing any
information.  If restarted, they will pick up where they left off.
Use these scripts to start and stop the agents until you get familiar
with starting and stopping them individually.

Now all you need to feed it "drops": files to "transfer" through the
system.

** Starting the agents

** Stopping the agents

** Generating drops

[FIXME: Generate (test) drops with RefDB tools, see README-RefDB.txt.]

[FIXME: DC04 drops:

  RefDBReady -a \
   5270 5272 5273 5274 5275 5276 5278 \
   5439 5440 5441 5442 5443 5444 5445 \
   5449 5450 5452 5453 5454 5455 5457

The drops-for-*/drops directory now contains all the drops produced by
T0 in CMS DC04.  FIXME: doesn't get summaries right!]

** Feeding drops to the agents

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
<lassi.tuura@cern.ch> or Tim Barrass <tim.barrass@physics.org>.

** FIXME: Olde stuff: Feeding the drops

For realistic tests, the drops need to be fed to the transfer chain at
CMS DC04 rates.  Our target rate was 25Hz, translating to one drop
every 40 seconds (1000 events per drop).  We never ran smoothly at
that rate however.  The models/25hz defines a model that would
still exercise the system at this rate.  There's also models/100hz
that does the same at a higher rate, e.g. for future data challenges.
There are also models/dc04-realistic and models/dc04-cleaned.  The
first is the real DC04 distribution, the latter with excessive tails
removed (when the whole system was down for days).  Note that if you
use these models to feed the drops, in theory you will run as long as
the data challenge took -- two months!  To run at faster rates, for
example flat out to discover peak performance or how well one can
recover from RLS service outages, construct your own model.

The model files are simple histograms of "secs n".  The "secs" is the
bin, and the "n" the number of the entries in that bin.  The task
execution times are distributed randomly according to this histogram.

The first agent in the chain is a "feed" that by default uses the 25Hz
flat model.  Copy all the drops to the feeder's inbox for injection to
transfer:

  cp -Rp dc04/drops/* incoming/feed/inbox
  for f in incoming/feed/inbox/*; do touch $f/go; done

The model directory also contains realistic transfer agent models.
