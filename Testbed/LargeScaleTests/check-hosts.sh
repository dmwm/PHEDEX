#!/bin/bash

if [ -z $PHEDEX_ROOT ]; then
  echo "PHEDEX_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi
if [ -z $LOCAL_ROOT ]; then
  echo "LOCAL_ROOT not set, are you sure you sourced the environment?"
  exit 0
fi

cd $PHEDEX_ROOT/$LOCAL_ROOT
for host in `bhosts -R cmsphedex | awk '{ print $1 }' | grep -v HOST_NAME | egrep -v 'lxb7423|lxb7425|lxb7426' | sort`
do
  echo Check host $host
  bsub -q cmsphedex -m $host -o $PHEDEX_ROOT/$LOCAL_ROOT/logs/check-$host.log $PHEDEX_ROOT/$LOCAL_ROOT/check-host.sh $1
done
