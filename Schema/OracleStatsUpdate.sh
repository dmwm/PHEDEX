#!/bin/sh

##H Update schema statistics.
##H
##H Usage: OracleStatsUpdate.sh USE/PASS@DB
##H
##H USER should be the master account name (cms_transfermgmt),
##H and PASS it's password.  The argument will be passed to
##H "sqlplus" as such.
##H
##H Runs schema utilities to update statistics

if [ $# -ne 1 ]; then
   grep "^##H" < $0 | sed 's/^\#\#\H\( \|$\)//'
   exit 1
fi

connect="$1"

(echo "exec dbms_stats.gather_schema_stats"			\
      " (ownname => 'cms_transfermgmt',"			\
      "  options => 'GATHER AUTO',"				\
      "  estimate_percent => dbms_stats.auto_sample_size,"	\
      "  method_opt => 'for all columns size repeat',"		\
      "  degree => 15,"						\
      "  cascade => true);") |
  sqlplus -S "$connect"
