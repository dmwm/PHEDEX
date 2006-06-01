#### Agents related to mass storage operations
### AGENT LABEL=exp-stage PROGRAM=Custom/DCache/FileSrmStager
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_BUFFERNODE}
 -storagemap  ${PHEDEX_MAP}

### AGENT LABEL=exp-upload PROGRAM=Toolkit/Transfer/FileMSSPublish
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_BUFFERNODE}
 -mssnode     ${PHEDEX_MSSNODE}


#### Choose one of the following depending on your MSS setup
### AGENT LABEL=exp-master PROGRAM=Custom/DCache/FileDCacheExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_BUFFERNODE}

### AGENT LABEL=exp-master PROGRAM=Custom/Castor/FileCastorExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_BUFFERNODE}

