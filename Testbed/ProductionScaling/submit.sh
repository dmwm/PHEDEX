#!/bin/sh

if [ "X$1" = 'X' ]; then
    echo "Please give amount of nodes to simulate !!"
    exit 1
fi

nodes=$1
cmd='bsub -q cmsphedex'

for (( i=1; $i<=$nodes; i+=1 )); do
    nodelist="%$(printf '%03d' $i)%"
    (set -x; $cmd $PHEDEX_BASE/PHEDEX/Testbed/RouterScaling/worker.sh $PHEDEX_BASE "$nodelist")
done

