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
2) DropCastorFileCheck: Check the PFNs mentioned in XML exist.
3) DropTMDBPublish: Insert the files into the transfer.

If you wish to merge files into larger uncompressed zip archives for
better storage and transport efficiency, use DropFunnel between steps
2 and 3 as described in README-Funnel.txt.

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

We recommend setting up the agents in a common structure as used
for instance at CERN.  This also means creating a few scripts to
set up the environment, start and stop the agents.  Please refer
to README-Operations.txt and Custom/CERN.  You may also wish to
read README-DeveloperTestbed.txt as another deployment guide.

  mkdir -p /some/new/place
  cd /some/new/place
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
  cvs login # password is "98passwd"
  cvs co PHEDEX

  # Create log and state directories
  mkdir -p incoming logs
  mkdir -p PHEDEX/Custom/YourSite

  # Set up environment script; use V2-CERN-Environ.sh as template
  vi PHEDEX/Custom/YourSite/Environ.sh

  # Set up agent start script; use V2-CERN-Start.sh as template
  vi PHEDEX/Custom/YourSite/Start.sh

  # Set up agent stop script; use V2-CERN-Stop.sh as template
  vi PHEDEX/Custom/YourSite/Stop.sh

  # FIXME: Follow node deployment instructions:
  #  - set up oracle and perl dbd (see V2-CERN-Environ.sh)
  #  - set up catalogue contact (see V2-CERN-Environ.sh)
  #     - can use either rls, or local oracle/mysql pool catalogue
  #  - site glue scripts

** Starting and stopping the agents

In PHEDEX/Custom/YourSite you should create three scripts to manage
tasks for your agents.  Create "Environ.sh", "Start.sh" and "Stop.sh"
using scripts from Custom/CERN as a model.  You might want to refer
to README-Operations.txt for more details.

** Generating and feeding drops to the agents

Please refer to README-RefDB.txt and using TRSyncFeed.

** Examining logs

If you follow the suggested configuration, your agents will produce
logs to the "logs" directory parallel to "PHEDEX".  You can tail
them there.  In future we will deploy distributed logging (netlogger)
to collect the logs.

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

	Another important feature of this agent is that it creates
	an attribute cache of the file properties.  When the files
	are published for transfer in DropTMDBPublisher, only the
	attribute caches are used.

DropCastorFileCheck

	This agent checks that the PFNs mentioned in the catalogues
	actually exist.  As this depends on the mass storage system,
	the agent is mass-storage specific (Castor).  The agent does
	not allow non-existent or zero-size files to pass into the
	distribution, instead marking such files bad.  It also adds
	to the attribute cache file size information that will be
	required by the DropTMDBPublisher.

DropCatPFNPrefix

	Convert the PFNs in the drops that pass through.  Adds a
	simple text prefix to the file names, for instance at CERN
	/castor/cern.ch becomes sfn://castorgrid.cern.ch/castor/cern.ch
	so that transfer agents can use globus-url-copy and CastorGrid
	service to read the files from CERN.

DropCatPublisher

	This agent publishes the XML catalogue into the site's POOL
	catalogue.  Before files can be inserted into the transfer
	system, they must be known in the local catalogue -- normally
	either the RLS or a MySQL catalogue.  This should be the same
	catalogue as specified in TMDB as the site's catalogue
	contact.

	If the files already exist in the transfer catalogue, for example
	if the transfer and PubDB catalogues are shared and data is
	made available from PubDB, this agent is not needed at all.

DropTMDBPublisher

	This agent publishes the XML drops into the transfer system
	once they are known in the local catalogue.  It injects the
	files and all their meta data into TMDB, the transfer
	management database (a ORACLE database).  The files are
	inserted into TMDB as unallocated; the allocation and
	scheduling agents handle the assignment of the files to
	destinations.

	Note that this agent requires attribute cache information
	that must be created by other agens.  DropXMLUpdate creates
	basic file properties and meta data, DropCastorFileCheck
	adds mandatory file size data.  Checksum data is also
	possible to add if the information is available.

DropFunnel
DropFunnelWorker
DropFunnelStatus
	See README-Funnel.txt.

File*
	See README-Transfer.txt.

[FIXME: Ranking]
[FIXME: Mr. Proper]

** Agent options

Many agents take same or similar options:

  -in, -state	The drop box/state directory for the agent.  The
  		agent creates its working directories under this
		directory, including the "inbox" into which new
		drops should be made.  Agents that use "-state"
		do not normally expect outside access to their
		state directories.

  -out		The drop box directory for the next agent.  More
  		than one out link can be specified; the drops will
		be copied to all of them.  The directory can either
		be a local directory, or bridge to another machine
		of type scp:<user>@<host>:</path> for copies with
		scp, or rfio:<machine>:</path> for rfio copies.

  -wait		The time in seconds the agent will sleep between
  		inbox and pending work queue checks, to avoid busy
		looping.  Depending on what the agent does the sleep
		time should be a small number (e.g. 7), or something
		fairly large (a few minutes: 120-600).

  -stagehost	These options are used by Castor-related agent and
  -stagepool	force values for the STAGE_HOST and STAGE_POOL
  		environment variables, respectively.

  -node		For the agents that work with TMDB, this option sets
  		the PhEDEx node name for the agent.  The name must be
		known in the node tables.

  -workers	For master/slave-type agents this option sets how
  		many worker slaves the master will start and keep
		running.

  -db		Used by any agent working with a database.  Defines
  		the name of the database to use.  For ORACLE this
		name must be registered in tnsnames.ora in $TNS_ADMIN.
 
  -dbuser	Used by any agent working with a database.  Defines
  		the user name for connecting to the database.

  -dbpass	Used by any agent working with a database.  Defines
  		the password for connecting to the database.

  -dbitype	Used by any agent working with a database.  Defines
  		the perl DBD library to be used.  The default is
		"Oracle".  Note that interpretation of "-db" option
		depends on the database "-dbitype" backend.

** Support

If you have any questions or comments, please contact the developers
at <cms-project-phedex@cern.ch>.  You are welcome to file bug reports
and support requests at our Savannah site at
  http://savannah.cern.ch/projects/phedex
