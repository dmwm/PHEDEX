#### Agents related to mass storage operations

### AGENT LABEL=mss-remove PROGRAM=Toolkit/Transfer/FileRemove DEFAULT=off
 -db              ${PHEDEX_DBPARAM}
 -nodes           ${PHEDEX_MSS}
 -delete          ${PHEDEX_CONFIG}/FileDownloadDelete
 -protocol        'direct'

### AGENT LABEL=exp-pfn-mss PROGRAM=Toolkit/Transfer/FileExport
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE},${PHEDEX_MSS}
 -accept      ${PHEDEX_NODE},${PHEDEX_MSS}
 -storagemap  ${PHEDEX_MAP}
 -protocols   'direct'

#### SRM based agents
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocol    'srmv2'
 -stage       ${PHEDEX_SCRIPTS}/Custom/Template/gfal_prestage.py
 -status      ${PHEDEX_SCRIPTS}/Custom/Template/gfal_prestage-status.py

### AGENT LABEL=mss-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -mssbackend  'srm'

#### Castor based agents
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocol    'direct'
 -stage       ${PHEDEX_SCRIPTS}/Custom/Template/castor_prestage.pm
 -status      ${PHEDEX_SCRIPTS}/Custom/Template/castor_prestage-status.pm

### AGENT LABEL=mss-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -mssbackend  'castor'

#### dCache based agents
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocol    'direct'
 -stage       ${PHEDEX_SCRIPTS}/Custom/Template/dcache_prestage.py
 -status      ${PHEDEX_SCRIPTS}/Custom/Template/dcache_prestage-status.py

### AGENT LABEL=mss-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -mssbackend  'dcache'

#### Fake backend agents
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileFakeStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}

### AGENT LABEL=mss-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -mssbackend  'fake'

#### Custom staging code
#### Create a script in your SITECONF to trigger staging requests, taking pfns as input
#### Create a script in your SITECONF to check status of your staging requests, taking pfns
#### as input and giving in output the list of staged files
### AGENT LABEL=mss-stage PROGRAM=Toolkit/Transfer/FileStager DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_NODE}
 -storagemap  ${PHEDEX_MAP}
 -protocol    'direct'
 -stage       ${SITECONF}/custom_prestage.pm
 -status      ${SITECONF}/custom_prestage-status.pm

#### Custom migration code
#### Create a perl module in your SITECONF (e.g. CustomMSSCheck.pm)
#### with the function &checkFileInMSS defined (args: $pfn, $is_custodial)
### AGENT LABEL=mss-migrate PROGRAM=Toolkit/Transfer/FileMSSMigrate DEFAULT=off
 -db          ${PHEDEX_DBPARAM}
 -nodes       ${PHEDEX_MSS}
 -checkroutine ${SITECONF}/CustomMSSCheck.pm
