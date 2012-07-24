#!/bin/bash

Master=$PHEDEX_ROOT/Utilities/Master
Config=$LIFECYCLE
eval `$Master -config $Config/Config.Mgmt.Testbed environ`

not_first=0
for cfg in $Config/Config.Test*.MSS
do
  i=`echo $cfg | awk -F/ '{ print $NF }' | tr -d '[a-z,A-Z,._]'`
  node="T1_Test${i}_Buffer"
  echo "Starting node $node"
  if [ $first ]; then
    echo 'pause before starting next node...'; sleep 15
    not_first=1
  fi
  nice $Master -config $Config/Config.Test$i.MSS start watchdog
done

echo 'pause before starting next node...'; sleep 15
echo "Starting Lifecycle and central agents"
$Master --config $Config/Config.Mgmt.Testbed start watchdog
echo 'pause before starting next node...'; sleep 15
node="T0_Test_Buffer"
echo "Starting node $node"
nice $Master -config $Config/Config.T0.MSS start watchdog
