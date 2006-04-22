sqlplus -S $(Schema/OracleConnectId -db Schema/DBParam:Testbed) @Schema/OracleReset.sql </dev/null
sqlplus -S $(Schema/OracleConnectId -db Schema/DBParam:Testbed) @Schema/OracleInit.sql </dev/null
sqlplus -S $(Schema/OracleConnectId -db Schema/DBParam:Testbed) @Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(Schema/OracleConnectId -db Schema/DBParam:Testbed) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null
Testbed/RouterScaling/SetupScaleTest -db Schema/DBParam:Testbed -count 100 -blocks 10
sqlplus -S $(Schema/OracleConnectId -db Schema/DBParam:Testbed) @Schema/OracleStatsUpdate.sql </dev/null
