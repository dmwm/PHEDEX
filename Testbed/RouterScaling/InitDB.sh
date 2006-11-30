#!/bin/sh

source ../sw/slc*/cms/PHEDEX/PHEDEX_*/etc/profile.d/env.sh
sqlplus -S $(Schema/OracleConnectId  -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode) @Schema/OracleReset.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode) @Schema/OracleInit.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode) @Schema/OracleStatsEnable.sql </dev/null
sqlplus -S $(Schema/OracleConnectId  -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode) @Testbed/RouterScaling/SetupScaleTest.sql </dev/null
Testbed/RouterScaling/SetupScaleTest -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode -count 10 -blocks 1 -nodes 4:Buffer,2:MSS,2:Disk
sqlplus -S $(Schema/OracleConnectId  -db ../SITECONF/CERN/PhEDEx/DBParam:Prod/Testnode) @Schema/OracleStatsUpdate.sql </dev/null
