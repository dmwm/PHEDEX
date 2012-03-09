#!/bin/bash

WORKINGDIR=/tmp/$USER/DBS3_Life_Cycle_Agent_Test
SCRAM_ARCH=slc5_amd64_gcc461
APT_VER=429-comp
SWAREA=$WORKINGDIR/sw
REPO=comp.pre

GRIDENVSCRIPT=/afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh

DBS3CLIENTVERSION=3.0.12
DBS3CLIENT=cms+dbs3-client+$DBS3CLIENTVERSION
DBS3CLIENTDOC=cms+dbs3-client-webdoc+$DBS3CLIENTVERSION

source $SWAREA/$SCRAM_ARCH/cms/dbs3-client/$DBS3CLIENTVERSION/etc/profile.d/init.sh
export DBS_READER_URL=https://dbs3-dastestbed.cern.ch/dbs/prod/global/DBSReader
export DBS_WRITER_URL=https://dbs3-dastestbed.cern.ch/dbs/prod/global/DBSWriter

wildish=/afs/cern.ch/user/w/wildish/public
export PERL5LIB=$wildish/COMP/PHEDEX_CVS/perl_lib:$wildish/COMP/T0_CVS/perl_lib:$wildish/perl:$wildish/perl/lib:$wildish/perl/lib/arch
