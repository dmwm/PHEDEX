#!/bin/bash
# An example of pre-filling a proxy-server cache

# Set baseUrl to the url of your proxy-server data-service instance
perlUrl=http://localhost:30001/phedex/datasvc/perl/prod
jsonUrl=http://localhost:30001/phedex/datasvc/json/prod

# Fetch the nodes and pull out their names
wget -O - $perlUrl/nodes | grep NAME | grep -v TX_ | awk -F\' ' { print $4 }' | egrep '^T0|^T1|^T2|^T3' | sort | tee nodes

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
  wget --quiet -O /dev/null "$jsonUrl/transferqueuestats?to=$node;binwidth=21600"
  wget --quiet -O /dev/null "$jsonUrl/transferhistory?to=$node;binwidth=21600"
  wget --quiet -O /dev/null "$jsonUrl/errorlogsummary?to=$node;binwidth=21600"
  wget --quiet -O /dev/null "$jsonUrl/transferqueuestats?from=$node;binwidth=21600"
  wget --quiet -O /dev/null "$jsonUrl/transferhistory?from=$node;binwidth=21600"
  wget --quiet -O /dev/null "$jsonUrl/errorlogsummary?from=$node;binwidth=21600"
done

# Get all binwidths for T0/1 non-MSS nodes...
node=T1_US_FNAL_Buffer
for node in `cat nodes | egrep '^T0|^T1' | grep -v MSS`
do
  echo -n "all timebins for $node "
  for bin in 3600 10800 21600 43200 86400 172800 345600 604800
  do
    echo -n "$bin "
    wget --quiet -O /dev/null "$jsonUrl/transferqueuestats?to=$node;binwidth=$bin"
    wget --quiet -O /dev/null "$jsonUrl/transferhistory?to=$node;binwidth=$bin"
    wget --quiet -O /dev/null "$jsonUrl/errorlogsummary?to=$node;binwidth=$bin"
    wget --quiet -O /dev/null "$jsonUrl/transferqueuestats?from=$node;binwidth=$bin"
    wget --quiet -O /dev/null "$jsonUrl/transferhistory?from=$node;binwidth=$bin"
    wget --quiet -O /dev/null "$jsonUrl/errorlogsummary?from=$node;binwidth=$bin"
  done
  echo ' '
done

# If you _really_ want to hammer the service...
# T0, T1 to all T0,1,2 non-MSS sites
for from in `cat nodes | egrep '^T0|^T1' | grep -v MSS`
do
  echo transfer queue blocks: $from
  for to in `grep -v $from nodes | grep -v MSS`
  do
    wget --quiet -O /dev/null "$jsonUrl/transferqueueblocks?from=$from;to=$to"
    echo -n "all timebins for $from -> $to "
    for bin in 3600 10800 21600 43200 86400 172800 345600 604800
    do
      echo -n "$bin "
      wget --quiet -O /dev/null "$jsonUrl/transferqueueblocks?from=$from;to=$to;binwidth=$bin"
    done
    echo  " "
#   Now for the files. Yikes!
    for block in `wget --quiet -O - "$jsonUrl/transferqueueblocks?from=$from;to=$to" | tr -d '"' | tr ',' "\n" | grep name: | awk -F: '{ print $2 }' | sed -e 's|/|%2F|g' -e 's|#|%23|'g`
    do
      echo $block
      wget --quiet -O /dev/null "$jsonUrl/transferqueuefiles?from=$from;to=$to;block=$block"
      echo -n "all timebins for $from -> $to "
      for bin in 3600 10800 21600 43200 86400 172800 345600 604800
      do
        echo -n "$bin "
        wget --quiet -O /dev/null "$jsonUrl/transferqueuefiles?from=$from;to=$to;block=$block;binwidth=$bin"
      done
      echo  " "
    done
  done
done
# T* to T0,T1s
for from in `cat nodes`
do
  echo transfer queue blocks: $from
  for to in `grep -v $from nodes | egrep '^T0|^T1' | grep -v MSS`
  do
   wget --quiet -O /dev/null "$jsonUrl/transferqueueblocks?from=$from;to=$to"
    echo -n "all timebins for $from -> $to "
    for bin in 3600 10800 21600 43200 86400 172800 345600 604800
    do
      echo -n "$bin "
      wget --quiet -O /dev/null "$jsonUrl/transferqueueblocks?from=$from;to=$to;binwidth=$bin"
    done
    echo  " "
  done
done

# For a range of requests, get the transfer request details
for request in `seq 30000 31000`
do
  echo request: $request
  wget --quiet -O /dev/null "$jsonUrl/transferrequests?request=$request"
done
