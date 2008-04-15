#!/bin/sh

TMPDIR=`pwd`;
START=$(date +%s)
RUNTIME=$((24*3600*7)) # 1 week

# Set up local state and log directories.  $PHEDEX_NODE is the name of
# the node for which this agent runs and is used by the download agent
# configuration.  The $PHEDEX_LOCAL is used by the configuration too.
export PHEDEX_BASE="$1"
NODELIST=`echo $2 | sed 's/,/ /g'`
AGENTLIST="download remove exp-pfn blockverify"

export PHEDEX_ARCH=slc4_amd64_gcc345;
export PHEDEX_LOCAL=$TMPDIR;
CONFIG=${PHEDEX_BASE}/PHEDEX/Testbed/ProductionScaling

mkdir -p ${PHEDEX_BASE}/failconf;
for node in $NODELIST; do
    # Make failure configuration file
    export PHEDEX_FAIL_CONF=${PHEDEX_BASE}/failconf/$node-fail.conf
    [ ! -f $PHEDEX_FAIL_CONF ] && cp ${CONFIG}/LinkFailureRates.conf $PHEDEX_FAIL_CONF
    
    # Now start the agents.
    echo "INFO:  Starting agents for $node"
    (
	unset WORKDIR # workaround an environment bug in 3_0_0_pre14...
	export PHEDEX_NODE=$node
	${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${CONFIG}/Config.Site start;
    )
done

# Wait for the agents to exit.  They can be terminated at any time via
# the database, or by us if the job exceeds our run time.
while true; do
    sleep 300

    # Check if agents are still alive.
    AGENTSALIVE=0
    for node in $NODELIST; do  
	[ ! -f ${PHEDEX_LOCAL}/$node/state/download/pid ] && break
	kill -0 $(cat ${PHEDEX_LOCAL}/$node/state/download/pid) || break
	AGENTSALIVE=1
    done
    if [ ! $AGENTSALIVE ]; then
	break
    fi
    
    # If the agents ran too long, quit
    if [ $(expr $(date +%s) - $START) -gt $RUNTIME ]; then
	echo "INFO:  Stopping agents after $RUNTIME seconds of running"
	for node in $NODELIST; do
	    if [ ! -f ${PHEDEX_LOCAL}/$node/state/download/stop ]; then 
		${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${CONFIG}/Config.Site stop;
	    elif [ ! -f ${PHEDEX_LOCAL}/$node/state/download/terminating ]; then
		${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${CONFIG}/Config.Site terminate;
		touch ${PHEDEX_LOCAL}/$node/state/download/terminating
	    else
		${PHEDEX_BASE}/PHEDEX/Utilities/Master -config ${CONFIG}/Config.Site kill;
	    fi
	done
    fi

  # Show tail of the log on AFS
    echo "INFO:  Tailing logs to ${PHEDEX_BASE}/logs"
    for node in $NODELIST; do
	for agent in $AGENTLIST; do
	    tail -1000 ${PHEDEX_LOCAL}/$node/logs/$agent \
		> ${PHEDEX_BASE}/logs/$agent-$node.tail 2>/dev/null
	done
    done
done

echo "INFO:  Agents are dead, job finished"

# Copy compressed logs to AFS.
echo "INFO:  Sending logs to ${PHEDEX_BASE}/logs"
mkdir -p ${PHEDEX_BASE}/logs
for node in $NODELIST; do
    for agent in $AGENTLIST; do
	gzip -c --best < $PHEDEX_LOCAL/$node/logs/$agent > ${PHEDEX_BASE}/logs/$agent-$node.gz
    done
done

# Return happy and joyful!
echo "INFO:  Exiting job"
exit 0;
