#### General configuration
### ENVIRON common

# Common part
PHEDEX_SITE=Test1;
PHEDEX_NODE=TX_${PHEDEX_SITE}_Buffer;
PHEDEX_MSS=TX_${PHEDEX_SITE}_MSS;
PHEDEX_CONTEXT=${PHEDEX_SITE};

# For the watchdog...
PHEDEX_NOTIFICATION_PORT=1236;
export PHEDEX_NOTIFICATION_PORT;

PHEDEX_MAP=${PHEDEX_ROOT}/Testbed/LifeCycle/tfc-dst.xml;
export PHEDEX_MAP;
### IMPORT ConfigPart.Testbed

### AGENT LABEL=watchdog PROGRAM=Utilities/AgentFactory.pl
 -db         ${PHEDEX_DBPARAM}
 -config     ${PHEDEX_CONFIG_FILE}
 -agent_list exp-pfn
# -agent_list exp-pfn-mss
# -agent_list download-fts
 -agent_list download-srm
# -agent_list download-migrate
# -agent_list remove

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
 -nodes           ${PHEDEX_NODE}
 -delete          ${PHEDEX_CONFIG}/fake-delete.pl
 -protocol        'direct'
 -limit		  150
 -jobs		  11

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

### AGENT LABEL=download-srm PROGRAM=Toolkit/Transfer/FileDownload
 -db                    ${PHEDEX_DBPARAM}
 -nodes                 ${PHEDEX_NODE}
 -accept                '%'
 -validate              ${PHEDEX_CONFIG}/fake-validate.pl
 -backend               SRM
 -protocols             'srm'
 -batch-files           1
 -link-pending-files    2
 -job-awol		10
