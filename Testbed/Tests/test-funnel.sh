#!/bin/sh

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 run -sh`
source /afs/cern.ch/project/oracle/script/setoraenv.sh -s 8174

rm -f entry
ln -s null entry
mkdir -p {null,xml,exist,mrg,out,ref}
rm -fr {null,xml,exist,mrg,out,ref}/{inbox,work}/*

# FIXME: also run in "maximal mode", first putting everything through to funnel
# inbox, then running funnel maxed out on its entire collection of drops

# ./DropNullAgent -in null -out xml -model ../RLSTest/models/25hz >& log-null &
# ./DropNullAgent -in null -out xml -model ../RLSTest/models/100hz >& log-null &
./DropNullAgent -in null -out xml >& log-null &
./DropXMLUpdate -in xml -out exist >& log-xml &
./DropCastorFileCheck -in exist -out mrg -out ref >& log-exist &
./DropFunnel -in mrg -out out \
	-queue . 1800 1500 \
	-stagehost stagecmsprod \
	-stagepool cms_prod2 \
	-dryrun \
	-workers 5 \
	-rfcp 5 \
	-wait 7 \
	>& log-mrg &
