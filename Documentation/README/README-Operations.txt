* General

Everything is installed under /data on lxgate04.cern.ch.  Always use
the "cmsprod" account for everything.

* Directories

Agent directories
  code:                   /data/V2Nodes/PHEDEX
  agent state:            /data/V2Nodes/CERN/incoming
  mouth of distribution:  /data/V2Nodes/CERN/incoming/entry/inbox
  agent logs:             /data/V2Nodes/CERN/logs

* Managing the drop box agents

See V2-CERN-Environ.sh, V2-CERN-Start.sh and V2-CERN-Stop.sh in PHEDEX
Custom/CERN directory.  Use the start script to start the agents, and
the stop script to stop them.  The environment script can be sourced
in bourne shell to get various useful variables.  Use "ps xwwf" as
cmsprod to see which agents are running.

Start the scripts with the start script.  If you find you need to
modify the start sequence for any reason, modify the script, and then
run it.  The start script starts all agents that need to run at CERN.

Normally stop the processes with the stop script; they exit cleanly
quite quickly.  If you have to kill them, do
  kill $(cat /data/V2Nodes/CERN/incoming/*/pid)

* Monitoring data allocations

Periodically check the data subscriptions.  Tier-1s are currently
subscribed to certain datasets.  The schedule page lists existing
subscriptions, and currently unallocated streams.

  http://cern.ch/cms-project-phedex/cgi-bin/browser?subs=1
