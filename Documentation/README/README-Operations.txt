* General

Everything is installed under /data on lxgate04.cern.ch.  Always use
the "cmsprod" account for everything.

The V1 and V2 drop box chains use the same scripts at CERN, installed
in lxgate04.cern.ch:/data/V2Nodes/CastorGridDataSource/scripts.

* V1 Setup

** Directories

Drop box agent directories
  scripts:                /data/V2Nodes/CastorGridDataSource/scripts
  agent state:            /data/incoming.cmsprod/T0/TMDB
  mouth of distribution:  /data/incoming.cmsprod/T0/TMDB/entry/inbox
  agent logs:             /data/logs.cmsprod/T0/TMDB

Management (= allocator) agent
  program:                /data/scripts.cmsprod/T0/TMDB/allocator.pl
  state and log file:     /data/incoming.cmsprod/T0/Configuration

** Managing the drop box agents

See V1-CERN-Environ.sh, V1-CERN-Start.sh and V1-CERN-Stop.sh in the
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
  kill $(cat /data/incoming.cmsprod/T0/TMDB/*/pid)

** Managing the allocator agent

The agent should keep running on its own just fine, just like the drop
box agents.  You can tell if it's running if "config" entry goes red
in http://www.cern.ch/dc04-tmdb/cgi-bin/browser.pl.

To restart the allocator agent (as cmsprod@lxgate04.cern.ch):
  cd /data/scripts.cmsprod/T0/TMDB
  source environ.csh
  nohup ./allocator.pl -db pdb01 \
     -w /data/logs.cmsprod/T0/Configuration/ \
    >> /data/logs.cmsprod/T0/Configuration/log 2>&1 </dev/null &

To stop it
  touch /data/logs.cmsprod/T0/Configuration/stop
  ps auxwwf | grep allocator

* V2 Setup

** Directories

Drop box agent directories
  scripts:                /data/V2Nodes/CastorGridDataSource/scripts
  agent state:            /data/V2Nodes/CastorGridDataSource/incoming
  mouth of distribution:  /data/V2Nodes/CastorGridDataSource/incoming/entry/inbox
  agent logs:             /data/V2Nodes/CastorGridDataSource/logs

Management (= allocator) agent
  program:                /data/V2Nodes/ManagementNode/scripts/Allocator.pl
  state:                  /data/V2Nodes/ManagementNode/work
  logs:                   /data/V2Nodes/ManagementNode/logs

** Managing the drop box agents

Management is the same as with V1, but use V2-CERN-* instead.

** Managing the allocator agent

Same as V1, but different place:
  cd /data/V2Nodes/ManagementNode/scripts
  . /afs/cern.ch/project/oracle/script/setoranv.sh -s 8174
  nohup ./Allocator.pl -db devdb9 \
     -user cms_transfermgmt \
     -passwd smalland_round \
     -w ../work \
    >> ../logs/log 2>&1 </dev/null &

To stop it
  touch /data/V2Nodes/ManagementNode/work/stop
  ps auxwwf | grep Allocator
