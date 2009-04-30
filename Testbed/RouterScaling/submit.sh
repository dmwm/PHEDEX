#!/bin/sh

t1s=$1
t2s=$2

if [ "X$t1s" = 'X' -o "X$t2s" = 'X' ]; then
    echo "usage:  submit.sh N_T1 N_T2"
    exit 1
fi

cmd='bsub -q cmsphedex'

i=1
for (( i; $i<=$t1s; i+=1 )); do
  buffer=$(printf 'T1_%03d_Buffer' $i)
  (set -x; echo $cmd $PHEDEX_BASE/PHEDEX/Testbed/RouterScaling/worker.sh $PHEDEX_BASE $buffer)
done

for (( i; $i<=$t2s+$t1s; i+=1 )); do
  buffer=$(printf 'T2_%03d_Buffer' $i)
  (set -x; echo $cmd $PHEDEX_BASE/PHEDEX/Testbed/RouterScaling/worker.sh $PHEDEX_BASE $buffer)
done
