#!/bin/sh

DBS_INSTANCE=$1
TIME_FMT=$2
DIR=$3

if [ -z "$DBS_INSTANCE" ]
then
  DBS_INSTANCE="global"
fi

if [ -z "$TIME_FMT" ]
then
  TIME_FMT="%s"
fi

if [ -z "$DIR" ]
then
  DIR=$PWD
fi

if [ -z "$PHEDEX_DBPARAM"]
then
  echo "ERROR:  Set the PHEDEX_DBPARAM variable"
  exit 1
fi

if [ -z "$MIGRATION_FILE"]
then
  echo "ERROR:  Set the MIGRATION_FILE variable"
  exit 2
fi

source /data/PHEDEX/DBS2Migration/slc3_ia32_gcc323/external/python/2.4.3/etc/profile.d/init.sh
source /data/PHEDEX/DBS2Migration/slc3_ia32_gcc323/external/py2-cx-oracle/4.2/etc/profile.d/init.sh
source /data/PHEDEX/DBS2Migration/slc3_ia32_gcc323/cms/dbs-client/DBS_1_0_0/etc/profile.d/init.sh

PHEDEX_SCRIPTS=/data/PHEDEX/DBS2Migration/PHEDEX
PHEDEX_DB_R="${PHEDEX_DBPARAM}:Prod/Reader"
DBS2_R="http://cmsdbsprod.cern.ch/cms_dbs_prod_${DBS_INSTANCE}/servlet/DBSServlet"

XCHECK_TIME=`date +$TIME_FMT`
XCHECK_FILE="$DIR/xcheck-${DBS_INSTANCE}-${XCHECK_TIME}.txt"

echo "Running DBS/PhEDEx cross-check"
echo "DBS            $DBS2_R"
echo "TMDB           $PHEDEX_DB_R"
echo "MIGRATION_FILE $MIGRATION_FILE"
echo "Output file    $XCHECK_FILE"
echo "Beginning cross-check..."
PHEDEX/Migration/DBS2/TMDBPostMigrationStats -d -R -f $MIGRATION_FILE \
  -u "$DBS2_R" -c $($PHEDEX_SCRIPTS/Utilities/OracleConnectId -d $PHEDEX_DB_R) > $XCHECK_FILE
echo "Done"
