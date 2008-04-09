#!/bin/sh

if [ "X$1" = 'X' ]; then
    echo "Please give amount of nodes to simulate !!"
    exit 1
fi

nodes=$1
cmd='bsub -q cmsphedex'

for (( i=1; $i<=$nodes; i+=5 )); do
    nodelist=""
    for (( j=$i; $j<=$nodes && $j<$i+5; j+=1 )); do
        nodelist="${nodelist:+$nodelist,}%$(printf '%03d' $j)%"
    done
    (set -x; $cmd $PHEDEX_BASE/PHEDEX/Testbed/RouterScaling/worker.sh $PHEDEX_BASE "$nodelist")
done

