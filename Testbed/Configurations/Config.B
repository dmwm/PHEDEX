#### General configuration
### ENVIRON
# Node suffix
NODE="B";
# Set directories
PHEDEX_BASE=/data/TestNodes;

PHEDEX_SCRIPTS=${PHEDEX_BASE}/PHEDEX;
PHEDEX_LOGS=${PHEDEX_BASE}/logs/logs_${NODE};
PHEDEX_STATE=${PHEDEX_BASE}/state/state_${NODE};
PHEDEX_DL_HISTORY=${PHEDEX_BASE}/logs_${NODE}/history;
PHEDEX_CUSTOM=${PHEDEX_SCRIPTS}/Testbed/Configurations;

# create the log and state directories if they do not yet exist
[ -e ${PHEDEX_LOGS} ] || mkdir -p ${PHEDEX_LOGS};
[ -e ${PHEDEX_STATE} ] || mkdir -p ${PHEDEX_STATE};

# source the Phedex installation scripts
source ${PHEDEX_BASE}/tools/poolenv.sh;
source ${PHEDEX_BASE}/tools/oraenv.sh;
source ${PHEDEX_BASE}/tools/perlenv.sh;

# TMDB settings
PHEDEX_DBParam='/data/TestNodes/PHEDEX/Testbed/Configurations/DBParam';
PHEDEX_LABEL='RAC';
PHEDEX_NODE=T1;


# set the catalogue contact strings
PHEDEX_MYSQL=mysqlcatalog_mysql://phedex:phedex@cmslcgco04/phedexcat;
PHEDEX_ORACLE=relationalcatalog_oracle://itrac/JENS;


# Oracle testsystem specific env variables
export POOL_ORA_TS_TAB=JENS_DATA01;
export POOL_ORA_TS_IND=JENS_INDX01;
export POOL_AUTH_USER=jens;
export POOL_AUTH_PASSWORD=atarimaus;
export TNS_ADMIN=${PHEDEX_SCRIPTS}/Schema;
export POOL_OUTMSG_LEVEL=100;


# Local catalogue contact
PHEDEX_CATALOGUE=${PHEDEX_MYSQL};


# Get tools
#    X509_USER_PROXY=/data/V2Nodes/gridcert/proxy.cert; export X509_USER_PROXY;
#    unset X509_USER_CERT X509_USER_KEY;

# MYPROXY_SERVER=myproxy.cern.ch; export MYPROXY_SERVER;

#### Export-side agents
### AGENT LABEL=exp-pfn PROGRAM=Toolkit/Transfer/FilePFNExport
 -node ${PHEDEX_NODE}_${NODE}_Buffer
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -pfnquery ${PHEDEX_CUSTOM}/PFNLookup.sh,-u,${PHEDEX_CATALOGUE},-n,${PHEDEX_NODE}_${NODE}
 -wait $(expr 10 + $RANDOM % 10)

### AGENT LABEL=exp-disk PROGRAM=Toolkit/Transfer/FileDiskExport
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -node ${PHEDEX_NODE}_${NODE}_Buffer
 -wait $(expr 50 + $RANDOM % 20)

### AGENT LABEL=exp-upload PROGRAM=Toolkit/Transfer/FileMSSPublish
 -node ${PHEDEX_NODE}_${NODE}_Buffer
 -mssnode ${PHEDEX_NODE}_${NODE}_MSS
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -wait $(expr 50 + $RANDOM "%" 20)


#### Download agents
### AGENT LABEL=download-transfer PROGRAM=Toolkit/Transfer/FileDownload
 -node ${PHEDEX_NODE}_${NODE}_Buffer
 -ignore ${PHEDEX_NODE}_${NODE}_MSS
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -backend Globus
 -command /bin/true
 -pfndest ${PHEDEX_CUSTOM}/Transfer_URLmapper.sh,node=${NODE}
 -publish ${PHEDEX_CUSTOM}/Publish.pl,${PHEDEX_CATALOGUE},${PHEDEX_NODE}_${NODE}
 -timeout 600
 -wanted 1T
 -jobs 3
 -wait $(expr 10 + $RANDOM % 10)

# fake migration to tape (inverse MSSPublish)
### AGENT LABEL=exp-migrate PROGRAM=Toolkit/Transfer/FileMSSPublish
 -node ${PHEDEX_NODE}_${NODE}_MSS
 -mssnode ${PHEDEX_NODE}_${NODE}_Buffer
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -wait $(expr 50 + $RANDOM "%" 20)

### AGENT LABEL=exp-clean PROGRAM=Toolkit/Transfer/FileFakeCleaner
 -nodes ${PHEDEX_NODE}_${NODE}_Buffer
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -backoff 36000
 -wait $(expr 4 \* 3600 + $RANDOM "%" 1800)


#### Management agents
### AGENT LABEL=mgmt-rtab PROGRAM=Toolkit/Infrastructure/NodeRouter
 -nodes ${PHEDEX_NODE}_${NODE}_Buffer,${PHEDEX_NODE}_${NODE}_MSS
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -timeout 240
 -wait $(expr 50 + $RANDOM % 20)

### AGENT LABEL=mgmt-router PROGRAM=Toolkit/Infrastructure/FileRouter
 -node ${PHEDEX_NODE}_${NODE}_Buffer
 -nodes ${PHEDEX_NODE}_${NODE}_Buffer,${PHEDEX_NODE}_${NODE}_MSS
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -wait $(expr 50 + $RANDOM % 20)

#### Start monitoring
### AGENT LABEL=info-ds PROGRAM=Toolkit/Monitoring/InfoDropStatus
 -site ${PHEDEX_NODE}_${NODE}
 -dir ${PHEDEX_STATE}
 -db ${PHEDEX_DBParam}:${PHEDEX_LABEL}
 -wait $(expr 60 + $RANDOM % 60)

