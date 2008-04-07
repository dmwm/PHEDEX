#!/bin/sh

TMPDIR=`pwd`;
START=$(date +%s)

# Set up local state and log directories.  $PHEDEX_NODE is the name of
# the node for which this agent runs and is used by the download agent
# configuration.  The $PHEDEX_LOCAL is used by the configuration too.
export PHEDEX_BASE="$1"
export PHEDEX_NODES="$2"
export PHEDEX_LOCAL=$TMPDIR;
mkdir -p ${PHEDEX_LOCAL}/logs;
mkdir -p ${PHEDEX_LOCAL}/state;
PHEDEX_LOGLABEL=`echo ${PHEDEX_NODES} |sed 's|%||g' |sed 's|,|+|g'`;

# Now start the agents.
${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config start download;

# Wait for the agents to exit.  They can be terminated at any time via
# the database, or by us if the job exceeds our run time (20 hours).
while true; do
  sleep 300

  # Quit if the agent stopped or died
  [ ! -f $PHEDEX_LOCAL/state/download/pid ] && break
  kill -0 $(cat $PHEDEX_LOCAL/state/download/pid) || break

  # If the agent ran too long, quit
  if [ $(expr $(date +%s) - $START) -gt 72000 ]; then
    if [ ! -f $PHEDEX_LOCAL/state/download/stop ]; then 
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site stop all;
    elif [ ! -f $PHEDEX_LOCAL/state/download/terminating ]; then
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site terminate all;
      touch $PHEDEX_LOCAL/state/download/terminating
    else
      ${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${PHEDEX_BASE}/PHEDEX/Testbed/RouterScaling/Config.Site kill all;
    fi
  fi

  # Show tail of the log on AFS
  tail -1000 $PHEDEX_LOCAL/logs/download > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.tail 2>/dev/null
done

# Copy compressed logs to AFS.
gzip -c --best < $PHEDEX_LOCAL/logs/download > ${PHEDEX_BASE}/logs/download-$PHEDEX_LOGLABEL.gz
rm -fr $PHEDEX_LOCAL

# Return happy and joyful!
exit 0;
