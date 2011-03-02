#!/bin/sh

STRING=`echo $0 | sed -e 's%/Testbed/LargeScaleTests.*$%%'`
if [ "$1" == 'kill' ]; then
  echo "Kill them all!"
# Get nasty with anything else already on the node:
  for state in `ps auxww | grep $STRING | grep state | awk '{ print $14 }'`
  do
    echo touch ${state}stop
    touch ${state}stop
  done
  sleep 60
  echo KILL anyone left...
  kill `ps auxww | grep $STRING | grep -v $0 | awk '{ print $2 }'`
  sleep 15
  echo Really kill anyone still standing
  kill -KILL `ps auxww | grep $STRING | grep -v $0 | awk '{ print $2 }'`
  sleep 10
  echo So are there any supermen here
  ps auxww | grep $STRING | grep -v $0 | egrep -v '[g]rep' | sed -e 's%^%WARNING: %'
  exit 0
fi

ps auxww | grep $STRING | tee ps.txt
for pid in `cat ps.txt | grep worker.sh | tail -1 | awk '{ print $2 }'`
do
  dir=`ls -l /proc/$pid/cwd | awk '{ print $NF }'`
  nodes=`cat ps.txt | grep worker.sh | grep $pid | awk '{ print $NF }'`
  echo Process $pid in $dir, running for nodes $nodes

  for node in `echo $nodes | tr ',' ' '`
  do
    pscount=`cat ps.txt | grep /$node/ | wc -l`
    echo Summary $node $pscount processes
  done
  for node in `echo $nodes | tr ',' ' '`
  do
    for statedir in `cat ps.txt | grep /$node/ | awk '{ print $14 }'`
    do
      label=`echo $statedir | awk -F/ '{ print $8 }'`
      pid=`cat ps.txt | grep $statedir | awk '{ print $2 }'`
      echo Agent $node $label $pid
    done
  done
done
