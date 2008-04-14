#!/bin/sh

TMPDIR=`pwd`;
START=$(date +%s)
RUNTIME=$((24*3600*7)) # 1 week

# Set up local state and log directories.  $PHEDEX_NODE is the name of
# the node for which this agent runs and is used by the download agent
# configuration.  The $PHEDEX_LOCAL is used by the configuration too.
export PHEDEX_BASE="$1"
export PHEDEX_NODE="$2"
export PHEDEX_ARCH=slc4_amd64_gcc345;
export PHEDEX_LOCAL=$TMPDIR;
PHEDEX_LOGLABEL=`echo ${PHEDEX_NODE} |sed 's|%||g' |sed 's|,|+|g'`;

# Now start the agents.
echo "INFO:  Starting agents..."
(
  unset WORKDIR # workaround an environment bug in 3_0_0_pre14...
  ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site start;
)

# Wait for the agents to exit.  They can be terminated at any time via
# the database, or by us if the job exceeds our run time.
while true; do
  sleep 300
  
  # Quit if the agent stopped or died
  [ ! -f ${PHEDEX_LOCAL}/state/download/pid ] && break
  kill -0 $(cat ${PHEDEX_LOCAL}/state/download/pid) || break

  # If the agent ran too long, quit
  if [ $(expr $(date +%s) - $START) -gt $RUNTIME ]; then
    echo "INFO:  Stopping agents after $RUNTIME seconds of running"
    if [ ! -f ${PHEDEX_LOCAL}/state/download/stop ]; then 
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site stop;
    elif [ ! -f ${PHEDEX_LOCAL}/state/download/terminating ]; then
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site terminate;
      touch ${PHEDEX_LOCAL}/state/download/terminating
    else
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site kill;
    fi
  fi

  # Show tail of the log on AFS
  echo "INFO:  Tailing logs to ${PHEDEX_BASE}/logs"
  tail -1000 ${PHEDEX_LOCAL}/logs/download    > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.tail 2>/dev/null
  tail -1000 ${PHEDEX_LOCAL}/logs/exp-pfn     > ${PHEDEX_BASE}/logs/exp-pfn-$PHEDEX_LOGLABEL.tail 2>/dev/null
  tail -1000 ${PHEDEX_LOCAL}/logs/remove      > ${PHEDEX_BASE}/logs/remove-$PHEDEX_LOGLABEL.tail 2>/dev/null
  tail -1000 ${PHEDEX_LOCAL}/logs/blockverify > ${PHEDEX_BASE}/logs/blockverify-$PHEDEX_LOGLABEL.tail 2>/dev/null
done
echo "INFO:  Agents are dead, job finished"

# Copy compressed logs to AFS.
echo "INFO:  Sending logs to ${PHEDEX_BASE}/logs"
gzip -c --best < $PHEDEX_LOCAL/logs/exp-pfn     > ${PHEDEX_BASE}/logs/exp-pfn-$PHEDEX_LOGLABEL.gz
gzip -c --best < $PHEDEX_LOCAL/logs/download    > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.gz
gzip -c --best < $PHEDEX_LOCAL/logs/remove      > ${PHEDEX_BASE}/logs/remove-$PHEDEX_LOGLABEL.gz
gzip -c --best < $PHEDEX_LOCAL/logs/blockverify > ${PHEDEX_BASE}/logs/blockverify-$PHEDEX_LOGLABEL.gz

# Return happy and joyful!
echo "INFO:  Exiting job"
exit 0;
