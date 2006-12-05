#!/bin/sh

source ../sw/slc*/cms/PHEDEX/PHEDEX_*/etc/profile.d/env.sh
db=../SITECONF/CERN/PhEDEx/DBParam.lat:Validation
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleReset.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleInit.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db $db) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null
Testbed/RouterScaling/SetupNodes -db $db 8:T1 50:T2
Testbed/RouterScaling/SetupData -db $db -datasets 10 -blocks 10 -files 1000
sqlplus -S $(Schema/OracleConnectId  -db $db) @Schema/OracleStatsUpdate.sql </dev/null
