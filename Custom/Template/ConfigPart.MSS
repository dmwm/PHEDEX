#### Agents related to mass storage operations
### AGENT LABEL=exp-stage PROGRAM=Custom/SRM/FileSRMStager
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}_Buffer
 -storagemap  ${PHEDEX_MAP}

### AGENT LABEL=exp-upload PROGRAM=Toolkit/Transfer/FileMSSPublish
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}_Buffer
 -mssnode     ${PHEDEX_NODE}_MSS

### AGENT LABEL=exp-master PROGRAM=Custom/SRM/FileSRMExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}_Buffer

### AGENT LABEL=exp-migrate PROGRAM=Custom/SRM/FileSRMMigrate
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}_MSS
 -storagemap  ${PHEDEX_MAP}
