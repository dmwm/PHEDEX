#!/bin/bash

Master=$PHEDEX_ROOT/Utilities/Master
Config=$PHEDEX_ROOT/Testbed/LifeCycle
eval `$Master -config $Config/SRM-Config.Mgmt.Testbed environ`

not_first=0
for cfg in $Config/SRM-Config.Test*.MSS
do
  i=`echo $cfg | sed -e 's%^.*SRM-%%' | tr -d '[a-z,A-Z,._]'`
  node="TX_Test${i}_Buffer"
  echo "Starting node $node"
  if [ $first ]; then
    echo 'pause before starting next node...'; sleep 15
    not_first=1
  fi
  nice $Master -config $Config/SRM-Config.Test$i.MSS start watchdog
done

echo 'pause before starting next node...'; sleep 15
$Master --config $Config/SRM-Config.Mgmt.Testbed start watchdog
echo 'pause before starting next node...'; sleep 15
node="T0_Test_Buffer"
echo "Starting node $node"
nice $Master -config $Config/SRM-Config.T0.MSS start watchdog
