* General: CERN Operations

Production agents are installed under /data on lxgate10.cern.ch.  Use
the "phedex" account for all operations.

Various test agents (testbed, test, service challenges) operate from
a different machine, cmslcgco04, under user account "lat", under
"/data/lat" directory.  All the configurations are however stored in
the CVS repository.

* Directories

Agent directories
  code:                   /data/V2Nodes/PHEDEX
  agent state:            /data/V2Nodes/CERN/incoming
  mouth of distribution:  /data/V2Nodes/CERN/incoming/entry/inbox
  agent logs:             /data/V2Nodes/CERN/logs
  configuration:          /data/V2Nodes/PHEDEX/Custom/CERN

* Managing the drop box agents

The agent configuration, including the environment used by the agents,
is fully defined in PHEDEX/Custom/CERN/Config.  It has a section named
"ENVIRON" in the beginning which defines all the configurations used
at CERN, followed by "AGENT" sections for each agent.  The agent
settings partly rely on the environment variables defined in the first
section.

There are also a few CERN-specific glue scripts under Custom/CERN.
The purpose for these is explained in the other README-*.txt files.

To start the default set of agents:
  PHEDEX/Custom/CERN/Master start

To start specific agents:
  PHEDEX/Custom/CERN/Master start info-ts info-ds into-tc

To stop the default set of agents:
  PHEDEX/Custom/CERN/Master stop

To stop specific agents:
  PHEDEX/Custom/CERN/Master stop info-ts info-ds into-tc

To stop everything known in Config whether running or not:
  PHEDEX/Custom/CERN/Master stop all

To force kill all the agents in case of emergency:
  PHEDEX/Custom/CERN/Master terminate all

* Monitoring data allocations

Periodically check the data subscriptions.  Tier-1s are currently
subscribed to certain datasets.  The schedule page lists existing
subscriptions, and currently unallocated streams.

  http://cern.ch/cms-project-phedex/cgi-bin/browser?page=subs
