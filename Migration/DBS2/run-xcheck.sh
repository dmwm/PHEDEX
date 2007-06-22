#!/bin/sh

DBS_INSTANCE=$1
TIME_FMT=$2
OUTPUT_DIR=$3

if [ -z "$DBS_INSTANCE" ]
then
  DBS_INSTANCE="global"
fi

if [ -z "$TIME_FMT" ]
then
  TIME_FMT="%s"
fi

if [ -z "$OUTPUT_DIR" ]
then
  OUTPUT_DIR=$PWD
fi

if [ -z "$PHEDEX_SCRIPTS" ]
then
  echo "ERROR:  Set the PHEDEX_SCRIPTS variable"
  exit 1
fi

if [ -z "$PHEDEX_DBPARAM" ]
then
  echo "ERROR:  Set the PHEDEX_DBPARAM variable"
  exit 1
fi

if [ -z "$MIGRATION_FILE" ]
then
  echo "ERROR:  Set the MIGRATION_FILE variable"
  exit 2
fi

DBS2_R="http://cmsdbsprod.cern.ch/cms_dbs_prod_${DBS_INSTANCE}/servlet/DBSServlet"

XCHECK_TIME=`date +$TIME_FMT`
XCHECK_FILE="${OUTPUT_DIR}/xcheck-${DBS_INSTANCE}-${XCHECK_TIME}.txt"

echo "Running DBS/PhEDEx cross-check"
echo "DBS            $DBS2_R"
echo "TMDB           $PHEDEX_DBPARAM"
echo "MIGRATION_FILE $MIGRATION_FILE"
echo "Output file    $XCHECK_FILE"
echo "Beginning cross-check..."
${PHEDEX_SCRIPTS}/Migration/DBS2/TMDBPostMigrationStats -d -R -f $MIGRATION_FILE \
  -u "$DBS2_R" -c $(${PHEDEX_SCRIPTS}/Utilities/OracleConnectId -d $PHEDEX_DBPARAM) > $XCHECK_FILE
echo "Done"
