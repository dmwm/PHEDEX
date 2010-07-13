#!/bin/bash

Master=$PHEDEX_ROOT/Utilities/Master
Config=$PHEDEX_ROOT/Testbed/LifeCycle
eval `$Master -config $Config/SRM-Config.Mgmt.Testbed environ`

node="T0_Test_Buffer"
echo "Stopping node $node"
$Master -config $Config/SRM-Config.T0.MSS stop

for cfg in $Config/SRM-Config.Test*.MSS
do
  i=`echo $cfg | sed -e 's%^.*SRM-%%' | tr -d '[a-z,A-Z,._]'`
  node="TX_Test${i}_Buffer"
  echo "Stopping node $node"
  $Master -config $Config/SRM-Config.Test$i.MSS stop
done

echo "Stopping Mgmt agents"
$Master --config $Config/SRM-Config.Mgmt.Testbed stop
echo removing stop-files
rm $PHEDEX_ROOT/DEVDB10_*/state/*/stop
