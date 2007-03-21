#### Agents related to mass storage operations

### AGENT LABEL=mss-remove PROGRAM=Toolkit/Transfer/FileRemove DEFAULT=off
 -db              ${PHEDEX_DBPARAM}
 -nodes           ${PHEDEX_MSS}
 -ignore          ${PHEDEX_NODE}
 -storagemap      ${PHEDEX_CONFIG}/storage.xml
 -delete          ${PHEDEX_CONFIG}/FileDownloadDelete
 -protocol        'srm'

### AGENT LABEL=exp-pfn-mss PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE},${PHEDEX_MSS}
 -accept      ${PHEDEX_NODE},${PHEDEX_MSS}
 -storagemap  ${PHEDEX_MAP}
 -protocols   'direct'


#### SRM based agents
### AGENT LABEL=mss-stage PROGRAM=Custom/SRM/FileSRMStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}

### AGENT LABEL=mss-migrate PROGRAM=Custom/SRM/FileSRMMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}

#### Castor based agents
### AGENT LABEL=mss-stage PROGRAM=Custom/Castor/FileCastorStager.New DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}

### AGENT LABEL=mss-migrate PROGRAM=Custom/Castor/FileCastorMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}

#### dCache based agents
#### Currently we don't have a native dCache stager,
#### hence a fake stager is used for now.
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileFakeStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}

### AGENT LABEL=mss-migrate PROGRAM=Custom/DCache/FiledCacheMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}

