#### Agents related to mass storage operations
### AGENT LABEL=exp-stage PROGRAM=Custom/Castor/FileCastorStager.New DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protect     ${PHEDEX_SITE}/../PhEDEx/CastorConditionRed

### AGENT LABEL=exp-upload PROGRAM=Toolkit/Transfer/FileMSSPublish
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_NODE}
 -mssnode     ${PHEDEX_MSS}

### AGENT LABEL=exp-master PROGRAM=Custom/Castor/FileCastorExport DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}

### AGENT LABEL=exp-migrate PROGRAM=Custom/Castor/FileCastorMigrate
 -db          ${PHEDEX_DBPARAM}
 -node        ${PHEDEX_MSS}
 -storagemap  ${PHEDEX_MAP}
