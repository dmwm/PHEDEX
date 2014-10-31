#### General configuration
### ENVIRON common

# Common part
PHEDEX_SITE=T0_Test;
PHEDEX_NODE=${PHEDEX_SITE}_Buffer;
PHEDEX_MSS=${PHEDEX_SITE}_MSS;
PHEDEX_DISK=${PHEDEX_SITE}_Disk;
PHEDEX_CONTEXT=${PHEDEX_SITE};

# For the watchdog...
PHEDEX_NOTIFICATION_PORT=22000;
export PHEDEX_NOTIFICATION_PORT;

PHEDEX_MAP=${PHEDEX_CONFIG}/tfc.xml;
export PHEDEX_MAP;
### IMPORT ConfigPart.Testbed

### AGENT LABEL=watchdog PROGRAM=Utilities/AgentFactory.pl
 -db         ${PHEDEX_DBPARAM}
 -config     ${PHEDEX_CONFIG_FILE}
 -agent_list exp-pfn
 -agent_list exp-pfn-mss
 -agent_list download
 -agent_list download-migrate
 -agent_list remove

### AGENT LABEL=exp-pfn PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE},${PHEDEX_DISK}
 -protocols   'srm','direct'
 -storagemap  ${PHEDEX_MAP}

### AGENT LABEL=exp-pfn-mss PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -accept      ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocols   'direct'

### AGENT LABEL=download PROGRAM=Toolkit/Transfer/FileDownload
 -verbose
 -db              ${PHEDEX_DBPARAM}
 -accept	  '%Test%'
 -nodes           ${PHEDEX_NODE},${PHEDEX_DISK}
 -validate        ${PHEDEX_CONFIG}/fake-validate.pl
 -delete          ${PHEDEX_CONFIG}/fake-delete.pl
 -backend         Null
 -jobs            5

### AGENT LABEL=remove PROGRAM=Toolkit/Transfer/FileRemove
 -db              ${PHEDEX_DBPARAM}
 -nodes           ${PHEDEX_NODE},${PHEDEX_DISK},${PHEDEX_MSS}
 -delete          ${PHEDEX_CONFIG}/fake-delete.pl
 -protocol        'direct'
 -limit		  1000
 -jobs		  10
 -no-retry

# ### AGENT LABEL=blockverify PROGRAM=Toolkit/Verify/BlockDownloadVerify DEFAULT=off
#  -db          ${PHEDEX_DBPARAM}
#  -nodes       ${PHEDEX_NODE}

# ### AGENT LABEL=drop-publish PROGRAM=Toolkit/DropBox/DropTMDBPublisher DEFAULT=off
#  -db          ${PHEDEX_DBPARAM}
#  -node        ${PHEDEX_NODE}

### AGENT LABEL=download-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -protocols   direct
 -mssbackend  fake
