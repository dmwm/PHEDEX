#!/bin/sh

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 run -sh`
source /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

rm -f entry
ln -s xml entry
mkdir -p {xml,exist,pfx,cat,tmdb}
rm -fr {xml,exist,pfx,cat,tmdb}/{inbox,work}/*

./DropXMLUpdate -in xml -out exist >& log-xml &
./DropCastorFileCheck -in exist -out pfx >& log-exist &
./DropCatPFNPrefix -in pfx -out cat -prefix sfn://castorgrid.cern.ch >& log-pfx &
./DropCatPublisher -in cat -out tmdb -catalogue file:catalog.xml >& log-cat &
./DropTMDBPublisher -in tmdb -db "devdb9" -dbuser cms_transfermgmt -dbpass smalland_round -node TEST_Transfer >& log-tmdb &

rm -fr foodata
./TRNew foodata
./TRNewData -a foodata 4965
./TRSyncDrops foodata
./TRSyncFeed $PWD devdb9 t_files_for_transfer foodata
