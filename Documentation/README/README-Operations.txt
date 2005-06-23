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
  transferred files:      /data/V2Nodes/CERN/history
  configuration:          /data/V2Nodes/PHEDEX/Custom/CERN

* Managing the drop box agents

The agent configuration, including the environment used by the agents,
is fully defined in PHEDEX/Custom/CERN/Config.* (for * = Prod/Dev/SC3).
This pulls in the configuration composed of the ConfigPart.* files.
The sections named "ENVIRON common" in the beginning define environment
variables etc. required to run the agents.  The "AGENT" sections define
which agents run, and use settings defined in the environment part.

PLEASE NOTE: Some agents are off by default ("DEFAULT=off").  Please do
not do "Master ... start all" as it will start these agents as well, use
simple "start".

There are also a few CERN-specific glue scripts under Custom/CERN.
The purpose for these is explained in the other README-*.txt files.

To start the default set of agents:
  Utilities/Master -config Custom/CERN/Config.Prod start

To start specific agents:
  Utilities/Master -config Custom/CERN/Config.Prod start \
    info-ts info-ds info-tc

To stop the default set of agents:
  Utilities/Master -config Custom/CERN/Config.Prod stop

To stop specific agents:
  Utilities/Master -config Custom/CERN/Config.Prod stop \
    info-ts info-ds info-tc

To stop everything known in Config whether running or not:
  Utilities/Master -config Custom/CERN/Config.Prod stop all

To force kill all the agents in case of emergency:
  Utilities/Master -config Custom/CERN/Config.Prod terminate all

* Monitoring data allocations

Periodically check the data subscriptions.  Tier-1s are currently
subscribed to certain datasets.  The schedule page lists existing
subscriptions, and currently unallocated streams.

  http://cern.ch/cms-project-phedex/cgi-bin/browser?page=subs
