#!/bin/sh

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 run -sh`
source /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

mkdir {xml,gridpfn,checksum,catpub,tmdb}
rm -fr {xml,gridpfn,checksum,catpub,tmdb}/{inbox,work}/*

./DropXMLUpdate -in xml -out checksum >& log-xml &
./DropCastorChecksum -in checksum -out gridpfn -stagehost stagecmsprod -stagepool cms_prod2 >& log-checksum &
./DropCastorGridPFN -in gridpfn -out catpub >& log-gridpfn &
./DropCatPublisher -in catpub -out tmdb -catalogue file:catalog.xml >& log-catpub &
./DropTMDBPublisher -in tmdb -db devdb9 -node lat-test >& log-tmdb &

: ./RefDBReady -a 4965
: cp -rp drops-for-4965/drops/* xml/inbox
