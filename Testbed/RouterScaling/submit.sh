#!/bin/sh

if [ "X$1" = 'X' ]; then
    echo "Please give start or stop as first argument !!"
    exit 1
fi
if [ "X$2" = 'X' ]; then
    echo "Please give amount of nodes to simulate as second argument !!"
    exit 1
fi



if [ "X$1" = "Xstart" ]; then
    cmd='bsub -q dedicated -R itdccms'
else
    cmd='sh -c'
fi
nodes=$2

basedir='/afs/cern.ch/user/r/rehn/scratch0/PhEDEx'
configdir="$basedir/SITECONF/CERN/Testbed"

for (( i=1; $i<=$nodes; i+=1 )); do
    sed -i "s|PHEDEX_NODE=TX_TEST_.|PHEDEX_NODE=TX_TEST_$i|" $configdir/Config
    $cmd "cd $basedir/PHEDEX; Utilities/Master -config $configdir/Config $1"
done

