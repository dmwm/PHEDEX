#!/bin/sh

if [ "X$1" = 'X' ]; then
    echo "Please give amount of nodes to simulate !!"
    exit 1
fi

nodes_per_job=5
nodes=$1
cmd='bsub -q cmsphedex'

for (( i=1; $i<=$nodes; i+=$nodes_per_job )); do
    nodelist=""
    for (( j=$i; $j<=$nodes && $j<$i+$nodes_per_job; j+=1 )); do
        nodelist="${nodelist:+$nodelist,}%$(printf '%03d' $j)%"
    done
    (set -x; $cmd $PHEDEX_BASE/PHEDEX/Testbed/ProductionScaling/worker.sh $PHEDEX_BASE "$nodelist")
done
