# Set directories
PHEDEX_BASE=/home/csf/phtab/PhEDExDev/
PHEDEX_SCRIPTS=$PHEDEX_BASE/PHEDEX
PHEDEX_TEST_BASE=$PHEDEX_SCRIPTS/Testbed
PHEDEX_LOGS=$PHEDEX_TEST_BASE/Routing/logs;
PHEDEX_STATE=$PHEDEX_TEST_BASE/Routing/incoming;
PHEDEX_DL_HISTORY=$PHEDEX_TEST_BASE/Routing/history;
PHEDEX_CUSTOM=$PHEDEX_SCRIPTS/Custom/RAL;

# Local catalogue contact
PHEDEX_CATALOGUE='mysqlcatalog_mysql://boss_manager:boss$db@sql.gridpp.rl.ac.uk/cms_pool_filecatalog';

# Get tools
PATH=/afs/cern.ch/sw/lcg/app/spi/scram/:${PATH};
PROD04_BASE=/rutherford/cms-soft1/prod04;
. /home/csf/cms/prod04/dar_install_dir/ORCA_8_7_1_SLC3/ORCA_8_7_1_SLC3_env.sh;

# Finally set RAL specific environment
export PERL5LIB=${PHEDEX_BASE}/perl-modules/lib/5.8.0:${PHEDEX_BASE}/perl-modules/lib/5.8.0/i386-linux-thread-multi:${PHEDEX_BASE}/perl-modules/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi::${PHEDEX_BASE}/perl-modules/lib/perl5/site_perl/5.8.0:${PHEDEX_BASE}/perl-modules/lib/perl5/5.8.0/i386-linux-thread-multi;
export ORACLE_HOME=/rutherford/cms-soft1/oracle/app/slc3;
export TNS_ADMIN=${PHEDEX_SCRIPTS}/Schema/;
export SRM_PATH=/opt/d-cache/srm/;
export PATH=${SRM_PATH}/bin:${PATH};
export LD_PRELOAD="/opt/d-cache/dcap/lib/libpdcap.so";
export DCACHE_IO_TUNNEL="/opt/d-cache/dcap/lib/libgsiTunnel.so";
