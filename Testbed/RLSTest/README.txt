Setting up fake CMS transfer system
===================================

This package contains a fake CMS file transfer system for tests with
the RLS catalogue.  Most agents are fake: no real file transfers are
made.  Instead they are based on statistical models of how long
transfers take; once the time is elapsed, RLS operations similar to
the real agents are executed.

Prerequisites
=============

1) This pack of fake agents.
2) POOL tools.  There's an environment setup script.
3) The contact string for the RLS server.
4) A machine that runs the fake agents.

It is possible to either run all the agents on one computer, or
several ones.  The latter is particularly useful for WAN latency
tests.  The distributed test setup uses "scp" bridges to connect the
fake transfer agents.

Setting up
==========

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

Generating drops
================

The best way to generate realistic drops is to reuse the CMS DC04
ones.  Run the following commands to regenerate all of them:

  mkdir dc04
  RefDBDrops -d dc04 \
   5270 5272 5273 5274 5275 5276 5278 \
   5439 5440 5441 5442 5443 5444 5445 \
   5449 5450 5452 5453 5454 5455 5457
  RefDBGenSmry -d dc04

The dc04/drops directory now contains all the drops produced by T0 in
CMS DC04.

Feeding the drops
=================

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

The agents
==========

The agents are based on the "drop box" model: they have an inbox
directory where they receive tasks.  Each "drop" is a subdirectory in
the inbox.  When the drop is complete (a "go" file appears), the drop
is moved over to the work queue.  Completed tasks (with "done" file in
them) are moved to an outbox, from where they passed to the next agent
if there is one, or destroyed.  Tasks in the work queue are processed;
some sequentially and immediately passed on, some on the background
and periodically checked until the task is completed.  Tasks that fail
are marked "bad", and will not be considered again until the "bad"
marker is removed.  All this is done robustly to avoid any data loss.

FakeNullAgent

	This agent does nothing.  However, because it's a drop box
	agent, it effectively moves drops from one agent to another.
	If it's given a statistical wait model, it acts as a holding
	queue between two agents.

FakeXMLUpdate

	This agent rewrites the XML drops to include full /castor
	paths.  The agent uses a summary file if the drop has one,
	otherwise asks castor where the file is.  If you want to do
	the latter (normally you wouldn't!), delete all the summary
	files from the drops and make sure the files are staged on
	disk -- or use a prestaging agent to bring them on disk.  This
	agent is "real" and doesn't use a statistical model.

FakeRLSPublisher

	This agent publishes the XML drops into RLS.  This agent is
	"real" and doesn't use a statistical model.  *NOTE*: This is
	one of the key components that should be speeded up.  In real
	life, this agent must be able to cope with a drop every 40s --
	and much faster to purge possible back logs.  In DC04 the
	agent normally ran from 6-35s, with weight above 25s.
	Occasionally the publish times exceeded 200s.  Note that in
	future data challenges the rates will be considerably higher!

FakeTMDBPublisher

	This agent publishes the XML drops for transfer once the files
	are registered in RLS.  This fake setup doesn't use the ORACLE
	transfer database CMS used in DC04 (known as TMDB); instead
	similar behaviour is simulated using drop box agents.  This
	agent does not use a statistical model, it runs as fast as it
	can.  The agent is basically a multiplexer, sending the drops
	to several other agents.

FakeTransfer

	This agent is a faked transfer agent.  Instead of finding
	files for transfer in TMDB, it receives them as drops from
	FakeTMDBPublisher, or another FakeTransferAgent.  No files are
	ever transferred, the agent simply pushes them into some
	future time, and then pretends the file was transferred.  The
	"start.csh" script starts many instances of this agent in a
	topology that matches the real DC04 agent setup.  The file
	transfer times use statistical models; tuning the transfer
	shapes gives an idea of how the system would be loaded under
	different performance conditions.  Note that at the end of the
	DC04 and afterwards considerably better sustained transfer
	rates were achieved than those used in the default models!
	The transfer agents also add and/or remove replicas for the
	files in RLS; this is another key area to be tuned with the
	catalogues.  At times it took less time to transfer files than
	to register replicas.

FakeCleaner

	This agent fakes the cleaning agents used in DC04.  Once all
	"related" transfer agents have transferred files and marked
	them safe, the cleaning agent removes the intermediate replica
	from RLS.  [Not yet implemented!]

ScpBridge

	This agent is like the null agent, except it uses "scp" to
	move the directory over to the next agent.  This allows you to
	transfer drops between computers.  The actual copy operation
	cannot of course require a password -- use public keys crypto
	or ssh-agent to make sure you don't need to type in your
	password thousands of times!

Testing without RLS
===================

If you wish to test without RLS, change T0_RLS_CATALOG contact string
to a XML file for instance.

Support
=======

If you have any questions or comments, please contact Lassi A. Tuura
<lassi.tuura@cern.ch> or Tim Barrass <tim.barrass@physics.org>.
