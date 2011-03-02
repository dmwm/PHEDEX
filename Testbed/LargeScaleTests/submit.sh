#!/bin/sh

if [ "X$1" = 'X' ]; then
  echo "Please give number of nodes to simulate !!"
  exit 1
fi

start=1
if [ $2 ]; then
  start=$2
fi

nodes_per_job=5
nodes=$1
cmd='bsub -q cmsphedex'

if [ -z $PHEDEX_ROOT ]; then
  echo "PHEDEX_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi
if [ -z $LOCAL_ROOT ]; then
  echo "LOCAL_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi

for (( i=$start; $i<$nodes+$start; i+=$nodes_per_job )); do
  nodelist=""
  for (( j=$i; $j<$nodes+$start && $j<$i+$nodes_per_job; j+=1 )); do
    nodelist="${nodelist:+$nodelist,}$(printf '%03d' $j)"
  done
  (set -x; $cmd -o $PHEDEX_ROOT/$LOCAL_ROOT/logs/worker-$nodelist.log $PHEDEX_ROOT/$LOCAL_ROOT/worker.sh $PHEDEX_ROOT "$nodelist")
done
