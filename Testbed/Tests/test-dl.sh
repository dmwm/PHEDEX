#!/bin/sh

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 run -sh`
source /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

mkdir -p {fr,dl,si,cs,cm,exp}
rm -fr {fr,dl,si,cs,cm,exp}/{inbox,work}/*

TNS_ADMIN=$(pwd); export TNS_ADMIN

DBARGS="-db devdb9 -dbuser cms_transfermgmt -dbpass smalland_round"
STARGS="-stagehost stagecmsprod -stagepool cms_prod2"

./FileRouter -state fr $DBARGS -node GLOBAL >& log-fr &
./FileDownload -state dl $DBARGS -node TEST_LAT -pfndest ./FileDownloadDest -wanted 1G >& log-dl &
./FileCastorExport -state exp $DBARGS $STARGS -node castorgrid_mss >& log-exp &
./FileCastorStager -state si $DBARGS $STARGS -node castorgrid_mss -prefix sfn://castorgrid.cern.ch >& log-si &
./FileCastorChecksum -state cs $DBARGS $STARGS -node castorgrid_mss -prefix sfn://castorgrid.cern.ch >& log-cs &
./FileCastorMigrate -state cm $DBARGS $STARGS -node castorgrid_mss_test -prefix sfn://castorgrid.cern.ch >& log-cs &
