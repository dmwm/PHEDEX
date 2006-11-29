#!/bin/sh

sqlplus -S $(Schema/OracleConnectId  -db Schema/DBParam:Prod/Testnode) @Schema/OracleReset.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db Schema/DBParam:Prod/Testnode) @Schema/OracleInit.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db Schema/DBParam:Prod/Testnode) @Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db Schema/DBParam:Prod/Testnode) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null
Testbed/RouterScaling/SetupScaleTest -db Schema/DBParam:Prod/Testnode -count 10 -blocks 1 -nodes 4:Buffer,2:MSS,2:Disk
sqlplus -S $(Schema/OracleConnectId  -db Schema/DBParam:Prod/Testnode) @Schema/OracleStatsUpdate.sql </dev/null
