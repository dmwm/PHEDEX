#### General configuration
### ENVIRON common

# Common part
PHEDEX_SITE=Test1;
PHEDEX_NODE=T1_${PHEDEX_SITE}_Buffer;
PHEDEX_MSS=T1_${PHEDEX_SITE}_MSS;
PHEDEX_CONTEXT=${PHEDEX_SITE};

# For the watchdog...
PHEDEX_NOTIFICATION_PORT=22007;
export PHEDEX_NOTIFICATION_PORT;

# FTS specific part
TIER1_FTS_SERVER=https://fts-t1-import.cern.ch:8443/glite-data-transfer-fts/services/FileTransfer;
export TIER1_FTS_SERVER;

PHEDEX_MAP=${LIFECYCLE}/tfc.xml;
export PHEDEX_MAP;

PHEDEX_GLITE_WRAPPER=${LIFECYCLE_ROOT}/Testbed/FakeFTS.pl;
export PHEDEX_GLITE_WRAPPER;

### IMPORT ConfigPart.Testbed


### AGENT LABEL=watchdog PROGRAM=Utilities/AgentFactory.pl
 -db         ${PHEDEX_DBPARAM}
 -config     ${PHEDEX_CONFIG_FILE}
 -agent_list exp-pfn
 -agent_list exp-pfn-mss
 -agent_list download-fts
 -agent_list download-migrate
 -agent_list remove

### AGENT LABEL=exp-pfn PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocols   'srm','direct'

### AGENT LABEL=exp-pfn-mss PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -accept      ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocols   'direct'

### AGENT LABEL=download PROGRAM=Toolkit/Transfer/FileDownload DEFAULT=off
 -verbose
 -db              ${PHEDEX_DBPARAM}
 -accept	  '%Test%'
 -nodes           ${PHEDEX_NODE}
 -validate        ${PHEDEX_CONFIG}/fake-validate.pl
 -delete          ${PHEDEX_CONFIG}/fake-delete.pl
 -backend         Null
 -jobs            10

### AGENT LABEL=remove PROGRAM=Toolkit/Transfer/FileRemove
 -db              ${PHEDEX_DBPARAM}
 -nodes           ${PHEDEX_NODE},${PHEDEX_MSS}
 -delete          ${PHEDEX_CONFIG}/fake-delete.pl
 -protocol        'direct'
 -limit		  1000
 -jobs		  10

### AGENT LABEL=blockverify PROGRAM=Toolkit/Verify/BlockDownloadVerify DEFAULT=off
  -db          ${PHEDEX_DBPARAM}
  -nodes       ${PHEDEX_NODE}
  -namespace   castor

### AGENT LABEL=drop-publish PROGRAM=Toolkit/DropBox/DropTMDBPublisher DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}

### AGENT LABEL=download-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -protocols   direct
 -mssbackend  fake

### AGENT LABEL=download-fts PROGRAM=Toolkit/Transfer/FileDownload
 -db                    ${PHEDEX_DBPARAM}
 -nodes                 ${PHEDEX_NODE}
 -accept                '%'
 -validate              ${PHEDEX_CONFIG}/fake-validate.pl
 -backend               FTS
 -protocols             'srm'
 -service               ${TIER1_FTS_SERVER}
 -batch-files           5
 -link-pending-files    20
 -job-awol		3600
