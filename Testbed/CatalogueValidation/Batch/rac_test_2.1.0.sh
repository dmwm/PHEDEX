#!/bin/tcsh
# set the catalogue contact strings
setenv MYSQL mysqlcatalog_mysql://phedex:phedex@cmslcgco04/phedexcat
setenv ORACLE relationalcatalog_oracle://itrac/jens

# setup pool FC tools (POOL 2.1.0)
eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_2_1_0/src; scram -arch slc3_ia32_gcc323 runtime -csh`;

# setup Phedex Utilities
setenv PATH .:${PATH}:/afs/cern.ch/user/r/rehn/scratch0/PHEDEX/Utilities
setenv PYTHONPATH .:${PYTHONPATH}

# Oracle testsystem specific env variables
setenv POOL_AUTH_USER jens
setenv POOL_AUTH_PASSWORD atari
setenv POOL_ORA_TS_TAB JENS_DATA01
setenv POOL_ORA_TS_IND JENS_INDX01
setenv TNS_ADMIN /afs/cern.ch/user/r/rado/public/oracle/ADMIN
setenv POOL_OUTMSG_LEVEL E

# run the stuff
time FClistPFN -u $MYSQL -q "guid like '1234%'" >/dev/null
