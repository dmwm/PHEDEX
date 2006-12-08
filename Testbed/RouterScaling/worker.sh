#!/bin/sh

TMPDIR=`pwd`;
PHEDEX=~rehn/scratch0/PhEDEx;
START=$(date +%s)

# Set up local state and log directories.  $PHEDEX_NODE is the name of
# the node for which this agent runs and is used by the download agent
# configuration.  The $PHEDEX_LOCAL is used by the configuration too.
export PHEDEX_NODES="$1"
export PHEDEX_LOCAL=$TMPDIR;
mkdir -p ${PHEDEX_LOCAL}/logs;
mkdir -p ${PHEDEX_LOCAL}/state;
PHEDEX_LOGLABEL=`echo ${PHEDEX_NODES} |sed 's|%||g' |sed 's|,|+|g'`;

# Now start the agents.
${PHEDEX}/PHEDEX/Utilities/Master -config ${PHEDEX}/PHEDEX/Testbed/RouterScaling/Config start download;

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
      ${PHEDEX}/PHEDEX/Utilities/Master -config ${PHEDEX}/PHEDEX/Testbed/RouterScaling/Config stop download;
    elif [ ! -f $PHEDEX_LOCAL/state/download/terminating ]; then
      ${PHEDEX}/PHEDEX/Utilities/Master -config ${PHEDEX}/PHEDEX/Testbed/RouterScaling/Config terminate download;
      touch $PHEDEX_LOCAL/state/download/terminating
    else
      ${PHEDEX}/PHEDEX/Utilities/Master -config ${PHEDEX}/PHEDEX/Testbed/RouterScaling/Config kill download;
    fi
  fi

  # Show tail of the log on AFS
  tail -1000 $PHEDEX_LOCAL/logs/download > $PHEDEX/logs/download-$PHEDEX_LOGLABEL.tail 2>/dev/null
done

# Copy compressed logs to AFS.
gzip -c --best < $PHEDEX_LOCAL/logs/download > $PHEDEX/logs/download-$PHEDEX_LOGLABEL.gz
rm -fr $PHEDEX_LOCAL

# Return happy and joyful!
exit 0;
