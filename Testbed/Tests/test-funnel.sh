#!/bin/sh

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 run -sh`
source /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

rm -f entry
ln -s xml entry
mkdir -p {xml,exist,mrg,out}
rm -fr {xml,exist,mrg,out}/{inbox,work}/*

./DropXMLUpdate -in xml -out exist >& log-xml &
./DropCastorFileCheck -in exist -out mrg >& log-exist &
./DropFunnel -in mrg -out out \
	-queue . 1800 1500 \
	-stagehost stagecmsprod \
	-stagepool cms_prod2 \
	-dryrun \
	-workers 5 \
	-rfcp 5 \
	-wait 7 \
	>& log-mrg &
