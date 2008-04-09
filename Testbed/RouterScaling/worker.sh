#!/bin/sh

TMPDIR=`pwd`;
START=$(date +%s)

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
# the database, or by us if the job exceeds our run time (20 hours).
while true; do
  sleep 300
  
  # Quit if the agent stopped or died
  [ ! -f ${PHEDEX_LOCAL}/state/download/pid ] && break
  kill -0 $(cat ${PHEDEX_LOCAL}/state/download/pid) || break

  # If the agent ran too long, quit
  if [ $(expr $(date +%s) - $START) -gt 72000 ]; then
    echo "INFO:  Stopping agents after 20 hours of running"
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
  echo "INFO:  Tailing log to ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.tail"
  tail -1000 ${PHEDEX_LOCAL}/logs/download > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.tail 2>/dev/null
done
echo "INFO:  Agent is dead, job finished"

# Copy compressed logs to AFS.
echo "INFO:  Sending log to ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.gz"
gzip -c --best < $PHEDEX_LOCAL/logs/download > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.gz

# Return happy and joyful!
echo "INFO:  Exiting job"
exit 0;
