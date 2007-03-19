sqlplus -S $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM) @PHEDEX/Schema/OracleReset.sql </dev/null
sqlplus -S $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM) @PHEDEX/Schema/OracleInit.sql </dev/null
sqlplus -S $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM) @PHEDEX/Testbed/ProductionScaling/migrate.sql < /dev/null
sqlplus -S $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM) @PHEDEX/Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(PHEDEX/Utilities/OracleConnectId -db $PHEDEX_DBPARAM) @PHEDEX/Schema/OracleStatsUpdate.sql </dev/null

