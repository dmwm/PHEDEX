#!/bin/sh

db=$1
echo "InitDB.sh  $db"

echo "Resetting DB"
sqlplus -S $(Utilities/OracleConnectId  -db $db) @Schema/OracleReset.sql </dev/null

echo "Creating Schema"
sqlplus -S $(Utilities/OracleConnectId  -db $db) @Schema/OracleInit.sql </dev/null

echo "Enabling Stats"
sqlplus -S $(Utilities/OracleConnectId  -db $db) @Schema/OracleStatsEnable.sql </dev/null

echo "Init Schema Data"
sqlplus -S $(Utilities/OracleConnectId  -db $db) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null

echo "Setup nodes"
Testbed/RouterScaling/SetupNodes -db $db 8:T1 50:T2

echo "Setup data"
Testbed/RouterScaling/SetupData -db $db -datasets 10 -blocks 10 -files 1000

echo "Stats update"
sqlplus -S $(Utilities/OracleConnectId  -db $db) @Schema/OracleStatsUpdate.sql </dev/null
