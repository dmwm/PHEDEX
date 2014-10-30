#!/bin/bash

Master=$PHEDEX_ROOT/Utilities/Master
Config=$LIFECYCLE
eval `$Master -config $Config/Config.Mgmt.Testbed environ`

node="T0_Test_Buffer"
echo "Stopping node $node"
$Master -config $Config/Config.T0.MSS stop

for cfg in $Config/Config.Test*.MSS
do
  i=`echo $cfg | awk -F/ '{ print $NF }' | tr -d '[a-z,A-Z,._]'`
  node="T1_Test${i}_Buffer"
  echo "Stopping node $node"
  $Master -config $Config/Config.Test$i.MSS stop
done

echo "Stopping Mgmt agents"
$Master --config $Config/Config.Mgmt.Testbed stop
echo removing stop-files
rm $TESTBED_ROOT/DEVDB*/state/*/stop
