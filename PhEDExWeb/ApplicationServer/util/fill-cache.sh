#!/bin/bash
# An example of pre-filling a proxy-server cache

# Set baseUrl to the url of your proxy-server data-service instance
perlUrl=http://localhost:30001/phedex/datasvc/perl/prod
jsonUrl=http://localhost:30001/phedex/datasvc/json/prod

# Fetch the nodes and pull out their names
wget -O - $perlUrl/nodes | grep NAME | grep -v TX_ | awk -F\' ' { print $4 }' | sort | tee nodes

# fetch it again as JSON, that's what the cache really needs!
wget --quiet -O /dev/null $jsonUrl/nodes

# For each node, get the list of agents
for node in `cat nodes`
do
  echo agents: $node
  wget --quiet -O /dev/null "$jsonUrl/agents?node=$node"
done

# For each node, get the transfer statistics and errors
for node in `cat nodes`
do
  echo transfer stats: $node
  wget --quiet -O /dev/null "$jsonUrl/TransferQueueStats?to=$node;binwidth=21600;"
  wget --quiet -O /dev/null "$jsonUrl/TransferHistory?to=$node;binwidth=21600;"
  wget --quiet -O /dev/null "$jsonUrl/TransferErrorStats?to=$node;binwidth=21600;"
done

# If you _really_ want to hammer the service...
# T0, T1 to all T0,1,2 sites (ignore T3s...)
for from in `cat nodes | egrep '^T0|^T1' | grep -v MSS`
do
  echo transfer queue blocks: $from
  for to in `grep -v $from nodes | egrep '^T0|^T1|^T2' | grep -v MSS`
  do
   wget --quiet -O /dev/null "$jsonUrl/TransferQueueBlocks?from=$from;to=$to;"
  done
done
# T2 to T0,T1s, (ignore T3s and T2->T2)
for from in `cat nodes | egrep '^T2'`
do
  echo transfer queue blocks: $from
  for to in `grep -v $from nodes | egrep '^T0|^T1' | grep -v MSS`
  do
   wget --quiet -O /dev/null "$jsonUrl/TransferQueueBlocks?from=$from;to=$to;"
  done
done

# For a range of requests, get the transfer request details
for request in `seq 30000 31000`
do
  echo request: $request
  wget --quiet -O /dev/null "$jsonUrl/TransferRequests?request=$request;"
done
