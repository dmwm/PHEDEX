* General

Everything is installed under /data on lxgate04.cern.ch.  Always use
the "cmsprod" account for everything.

* Directories

Drop box agent directories
  scripts:                /data/V2Nodes/CastorGridDataSource/scripts
  agent state:            /data/V2Nodes/CastorGridDataSource/incoming
  mouth of distribution:  /data/V2Nodes/CastorGridDataSource/incoming/entry/inbox
  agent logs:             /data/V2Nodes/CastorGridDataSource/logs

Management (= allocator) agent
  program:                /data/V2Nodes/ManagementNode/scripts/Allocator.pl
  state:                  /data/V2Nodes/ManagementNode/work
  logs:                   /data/V2Nodes/ManagementNode/logs

* Managing the drop box agents

See V2-CERN-Environ.sh, V2-CERN-Start.sh and V2-CERN-Stop.sh in the
scripts directory mentioned above.  Use the start script to start the
drop box agents, and the stop script to stop them.  If you use bourne
shell, you can source the environment script to get variables set for
yourself.  You can use "ps xwwf" as cmsprod to see which agents are
running.

Start the scripts with the start script.  If you find you need to
modify the start sequence for any reason, modify the script, and then
run it.

Normally stop the processes with the stop script; they exit cleanly
quite quickly.  If you have to kill them, do
  kill $(cat /data/V2Nodes/CastorGridDataSource/incoming/*/pid)

* Managing the allocator agent

The agent should keep running on its own just fine, just like the drop
box agents.  You can tell if it's running if "config" entry goes red
in http://cern.ch/cms-project-phedex/cgi-bin/browser

To restart the allocator agent (as cmsprod@lxgate04.cern.ch):
  cd /data/V2Nodes/ManagementNode/scripts
  . /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174
  nohup ./Allocator.pl -db pdb01 \
     -user cms_transfermgmt \
     -passwd smalland_round \
     -w ../work \
    >> ../logs/log 2>&1 </dev/null &

To stop it
  touch /data/V2Nodes/ManagementNode/work/stop
  ps auxwwf | grep Allocator

* Monitoring data allocations

Periodically check the data subscriptions.  Tier-1s are currently
subscribed to certain datasets.  The schedule page lists existing
subscriptions, and currently unallocated streams.

  http://cern.ch/cms-project-phedex/cgi-bin/browser?subs=1
