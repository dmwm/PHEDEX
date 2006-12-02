#!/bin/sh

source ../sw/slc*/cms/PHEDEX/PHEDEX_*/etc/profile.d/env.sh
db=../SITECONF/CERN/PhEDEx/DBParam.lat:Validation
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleReset.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleInit.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null
Testbed/RouterScaling/SetupScaleTest -db $db -datasets 100 -blocks 10 -files 1000 -nodes 8:T1,40:T2
sqlplus -S $(Schema/OracleConnectId  -db $db) << EOF
  update t_adm_node set kind = 'Disk' where kind = 'Buffer';
EOF
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleStatsUpdate.sql </dev/null
