#!/bin/sh

if [ "X$1" = 'X' ]; then
    echo "Please give amount of nodes to simulate !!"
    exit 1
fi

start=1
if [ $2 ]; then
  start=$2
fi

nodes_per_job=5
nodes=$1
cmd='bsub -q cmsphedex'

for (( i=$start; $i<$nodes+$start; i+=$nodes_per_job )); do
    nodelist=""
    for (( j=$i; $j<$nodes+$start && $j<$i+$nodes_per_job; j+=1 )); do
        nodelist="${nodelist:+$nodelist,}$(printf '%03d' $j)"
    done
    (set -x; $cmd $PHEDEX_BASE/PHEDEX/Testbed/ProductionScaling/worker.sh $PHEDEX_BASE "$nodelist")
done
