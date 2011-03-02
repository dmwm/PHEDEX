#!/bin/sh

export ORACLE_HOME=/afs/cern.ch/project/oracle/@sys/prod
export ORA_NLS33=/afs/cern.ch/project/oracle/@sys/prod/ocommon/nls/admin/data

TMPDIR=`pwd`;
START=$(date +%s)
RUNTIME=$((24*3600*7)) # 1 week

MYROOT=$HOME/public/COMP/PHEDEX_CVS
cd $MYROOT/Testbed/LargeScaleTests
export PERL5LIB=$MYROOT/perl_lib:$HOME/public/perl:$HOME/public/perl/lib:$HOME/public/perl/lib/arch
. ./env.sh
cd $TMPDIR

# Set up local state and log directories.  $PHEDEX_NODE is the name of
# the node for which this agent runs and is used by the download agent
# configuration.  The $PHEDEX_LOCAL is used by the configuration too.
export PHEDEX_BASE="$1"
NODELIST=`echo $2 | sed 's/,/ /g'`
AGENTLIST="watchdog exp-pfn remove download"

export PHEDEX_LOCAL=$TMPDIR;
export CONFIG=${PHEDEX_BASE}/${LOCAL_ROOT}
export Master=${PHEDEX_BASE}/Utilities/Master
export PHEDEX_REMOTE="${PHEDEX_BASE}/${LOCAL_ROOT}"
export PHEDEX_LOGROOT="${PHEDEX_REMOTE}/logs"
mkdir -p ${PHEDEX_LOGROOT}

mkdir -p ${PHEDEX_REMOTE}/failconf;
for node in $NODELIST; do
    # Make failure configuration file
    export PHEDEX_FAIL_CONF=${PHEDEX_REMOTE}/failconf/$node-fail.conf
    [ ! -f $PHEDEX_FAIL_CONF ] && cp ${CONFIG}/LinkFailureRates.conf $PHEDEX_FAIL_CONF
    
    # Now start the agents.
    echo "`date`:  Starting agents for $node"
    (
	unset WORKDIR # workaround an environment bug in 3_0_0_pre14...
	export PHEDEX_NODE=$node
	export PHEDEX_NOTIFICATION_PORT=20$node
	$Master -config ${CONFIG}/Config.Site start watchdog;
    )
done

# Wait for the agents to exit.  They can be terminated at any time via
# the database, or by us if the job exceeds our run time.
AGENTSALIVE=1
while [ $AGENTSALIVE -gt 0 ]; do
    sleep 300 # long sleep appropriate when tailing logfiles, but we don't do that anymore
#   sleep 30

    # Check if agents are still alive.
    AGENTSALIVE=0
    for node in $NODELIST; do  
	PIDFILE=${PHEDEX_LOCAL}/$node/state/watchdog/pid
	[ ! -f $PIDFILE ] && break
	kill -0 $(cat $PIDFILE) || break
	AGENTSALIVE=1
    done

#    if [ ! $AGENTSALIVE ]; then
#	break
#    fi
    
#    # If the agents ran too long, quit
#    if [ $(expr $(date +%s) - $START) -gt $RUNTIME ]; then
#	echo "INFO:  Stopping agents after $RUNTIME seconds of running"
#	for node in $NODELIST; do
#	    if [ ! -f ${PHEDEX_LOCAL}/$node/state/download/stop ]; then 
#		$Master -config ${CONFIG}/Config.Site stop;
#	    elif [ ! -f ${PHEDEX_LOCAL}/$node/state/download/terminating ]; then
#		$Master -config ${CONFIG}/Config.Site terminate;
#		touch ${PHEDEX_LOCAL}/$node/state/download/terminating
#	    else
#		$Master -config ${CONFIG}/Config.Site kill;
#	    fi
#	done
#    fi

  # Show tail of the log on AFS
    echo "`date`:  Tailing logs to ${PHEDEX_LOGROOT}"
    for node in $NODELIST; do
	for agent in $AGENTLIST; do
	    tail -1000 ${PHEDEX_LOCAL}/$node/logs/$agent \
		> ${PHEDEX_LOGROOT}/$agent-$node.tail 2>/dev/null
	done
    done
done

echo "`date`:  Agents are dead, job finished"

# Copy compressed logs to AFS.
echo "`date`:  Sending logs to ${PHEDEX_LOGROOT}"
for node in $NODELIST; do
    for agent in $AGENTLIST; do
	gzip -c --best < $PHEDEX_LOCAL/$node/logs/$agent > ${PHEDEX_LOGROOT}/$agent-$node.gz
    done
done

# Return happy and joyful!
echo "`date`:  Exiting job"
exit 0;
