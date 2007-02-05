* Setting up agents

This document describes how to administer the drop box agents.  The
intended audience are the CMS data managers that need to inject files
into the transfer system.  Most of the agents are site-independent and
can be run anywhere by anyone.

** Related documents.

README-Overview.txt explains where this document fits in.
README-Transfer.txt explains how to set up the sample transfer agents.

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

Technically the drop box model uses a couple of directories to safely
juggle the files around.  The agent receives new drops in its "inbox",
where each drop is a subdirectory.  Completed drops, those with a "go"
file in them", are moved automatically to the "work" pending queue.
Completed drops, those with a "done" file in them, are first moved to
the "outbox" queue, from where they are passed to the next agent if
there is one, or destroyed.  Tasks in the "work" queue are processed,
some sequentially and immediately marked done and passed on, and some
on the background and periodically checked until the task is complete.
Drops that failed to be processed are marked "bad", and will not be
considered again until the "bad" marker is removed.  All the drop
management is done robustly to avoid any data loss.

** Transfer Overview

The expected minimal drop processing chain is something like this:

0) Drop source: reconstruction, simulation, online system.
1) DropTMDBPublish: Insert the files into the transfer.

** Installing agents

Deploying agents described in more detail in README-Deployment.txt.
We recommend setting up the agents in a common structure as used for
instance at CERN.

It is possible to run all the agents on one computer, or use several
systems.  Typically one would use a single computer as the load from
these agents is negligible.  You can drop box bridge agents on other
computers with scp or rfio by giving next agent's directory as
scp:user@host:/remote/dir or rfio:/remote/dir.

** Starting and stopping the agents

PhEDEx provides Utilities/Master to make the startup and stopping of
agents manageable.  Master reads in one or more configuration files in
order to start or stop any number of agents.  The configuration files
contain information that allows Master to set the necessary shell
environment for each agent, and then run each agent with desired
command line parameters.

The configuration files comprise two sections, named ENVIRON and
AGENT.  Within the ENVIRON section environment variables are set;
other scripts can be sourced to help in this. Within an AGENT section
the parameters necessary to run a single agent are set.

You may use a single configuration file with a number of ENVIRON
sections, and a number of AGENT sections -- or you may decide to split
your set of sections across a number of files.  In principle a single
ENVIRON section may be split across multiple files; a single AGENT
section may not.  However, the more complex you decide to make this
structure the more careful you need to be in cooridinating your use of
environment variables.

When Master runs, it executes an a number of agents in an internal
"sh" shell.  It first executes any settings in an ENVIRON labeled
"common".  Then it executes the settings in an ENVIRON defined for
each specific agent (if any), followed by the actual agent itself.
Everything is started on the background.

In detail, the syntax of an ENVIRON section is as follows; square
brackets indicate an optional parameter.  The content of the ENVIRON
section is executed as an sh script before starting agents.

### ENVIRON label
[ SOME_VARIABLE="some value"; ]
[ . some/path/to/a/script; ]
[ export SOME_OTHER_VAR="bobbins"; ]
[ ... &c ... ]

If there are parameters that are common to a number of environments
you may find it practical to modify them in one place rather than
many.  In this case, you should use the special ENVIRON label
"common": these common settings will be executed first, *BEFORE* any
other environment settings.

The content of each AGENT section is used to start a single agent
within the same bash shell. It's syntax is as follows

### AGENT LABEL=an_agent_name PROGRAM=Toolkit/some/agent_code [ ENVIRON=some_environ_label ]
  [ -option1 some_option_value ]
  [ -option2 ${SOME_VARIABLE}/some/script ]
  [ ... &c ... ]

As noted above, if you do not label an ENVIRON the agent will be
started with only the "common" environment.

For examples of configuration files, see files named Config under
SITECONF/<SiteName>/PhEDEx.

Once you have created your configuration file(s) you can use Master to
do a number of things

   * Print environment settings to stdout
   Master -config /path/to/Configfile environ [ specific label ]

   * Show what commands Master would use to start agents
   Master -config /path/to/Configfile show [an_agent_name|all]

   * Start an agent or all agents
   Master -config /path/to/Configfile start [an_agent_name|all]

   * Stop an agent or all agents
   Master -config /path/to/Configfile stop [an_agent_name|all]

   * Force termination of agents
   Master -config /path/to/Configfile terminate [an_agent_name|all]

To specify multiple configuration files, separate the configuration
file names by commas:

   Master -config file1,file2,file3 ...

You can specify as many agent names as you want after the command:

   Master -config file start download-master exp-pfn

** Examining logs

If you follow the suggested configuration, your agents will produce
logs to the "logs" directory parallel to "PHEDEX".  You can tail them
there.  In future we will deploy distributed logging (netlogger) to
collect the logs.

** Agent descriptions

DropNullAgent

	This agent does nothing.  However, because it's a drop box
	agent, it can link between agents.  You can use it copy drops
	to one or more receiving agents, also bridging between hosts
	using scp and rfio protocols.  Any drop box agent will of
	course be able to do the same.  If given a statistical wait
	model, the agent acts as a holding or delay queue between two
	agents, the main reason for the existence of this agent.

DropTMDBPublisher

	This agent publishes the XML drops into the transfer system
	once they are known in the local catalogue.  It injects the
	files and all their meta data into TMDB, the transfer
	management database (a ORACLE database).  The files are
	inserted into TMDB as unallocated; the allocation and
	scheduling agents handle the assignment of the files to
	destinations.

File*
	See the other READMEs for these agents.

[FIXME: Ranking]
[FIXME: Mr. Proper]

** Agent options

Many agents take same or similar options:

  -state	The drop box/state directory for the agent.  The
  		agent creates its working directories under this
		directory, including the "inbox" into which new
		drops should be made.  Many agents do not expect
		outside access to their state directories.

  -log		The log file into which the agent will redirect its
                standard output and error.  If no -log option is
                given, the agent output will be lost.  Note that an
		agent will always daemonise itself; if you want to
		test interactively, use "-log $TTY", but remember to
		stop the agent after you are done with the tests.

  -out		The drop box directory for the next agent.  More
  		than one out link can be specified; the drops will
		be copied to all of them.  The directory can either
		be a local directory, or bridge to another machine
		of type scp:<user>@<host>:</path> for copies with
		scp, or rfio:<machine>:</path> for rfio copies.

  -node, -nodes	For the agents that work with TMDB, this option sets
  		the PhEDEx node name for the agent.  The name must be
		known in the node tables.  Some agents are capable of
		working as multi-node agents, and accept list of node
		name patterns ("%" any string, "_" any character)
		separated by commas, and then act on all those nodes.

  -accept,      In case of multi-node agents, the selection of node
  -ignore       names can be further adjusted by the following two
                options.
                'accept' is applied first and acts as white-list,
                leaving only nodes matching. The remaining
                node names are checked against the black-list defined
                by '-ignore' and are hence ignored if matching.

  -workers	For master/slave-type agents this option sets how
  		many worker slaves the master will start and keep
		running.

  -jobs         For job-manager type agents this option sets how
                many concurrent sub-processes can be executed.

  -db           Used by any agent working with a database.  Defines
                path to a database configuration file which defines
		usernames and passwords and other parameters for
		different database contacts.  The argument is of the
		form PATH:SECTION, where SECTION is one of the named
		connections inside the file.  (See README-Auth.txt
		for more information about database authentication.)


** Support

Please contact <hn-cms-phedex@cern.ch> for support and check out the
documentation at http://cmsdoc.cern.ch/cms/aprom/phedex.  Please file
bugs and feature requests at http://savannah.cern.ch/projects/phedex.
