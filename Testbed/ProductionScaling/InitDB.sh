sqlplus -S $($PHEDEX_SCRIPTS/Schema/OracleConnectId -db $PHEDEX_DBPARAM) @$PHEDEX_SCRIPTS/Schema/OracleReset.sql </dev/null
sqlplus -S $($PHEDEX_SCRIPTS/Schema/OracleConnectId -db $PHEDEX_DBPARAM) @$PHEDEX_SCRIPTS/Schema/OracleInit.sql </dev/null
sqlplus -S $($PHEDEX_SCRIPTS/Schema/OracleConnectId -db $PHEDEX_DBPARAM) @$PHEDEX_SCRIPTS/Testbed/ProductionScaling/migrate.sql < /dev/null
sqlplus -S $($PHEDEX_SCRIPTS/Schema/OracleConnectId -db $PHEDEX_DBPARAM) @$PHEDEX_SCRIPTS/Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $($PHEDEX_SCRIPTS/Schema/OracleConnectId -db $PHEDEX_DBPARAM) @$PHEDEX_SCRIPTS/Schema/OracleStatsUpdate.sql </dev/null

