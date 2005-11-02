### ENVIRON common

PHEDEX_CATALOGUE='mysqlcatalog_mysql://cms_manager:boss$db@sql.gridpp.rl.ac.uk/cms_pool_filecatalog';
PHEDEX_SC3_CATALOGUE='mysqlcatalog_mysql://cms_manager:boss$db@sql.gridpp.rl.ac.uk/cms_pool_sc3';

. /rutherford/cms-soft1/PhEDEx/tools/poolenv.sh;
. /rutherford/cms-soft1/PhEDEx/tools-ora10.1.0.4/oraenv.sh;
. /rutherford/cms-soft1/PhEDEx/perl-modules-ora10.1.0.4/perlenv.sh;

export PATH=/rutherford/cms-soft1/PhEDEx/tools/lcg/external/python/2.3.4/slc3_ia32_gcc323/bin/:$PATH;
export SRM_PATH=/opt/d-cache/srm/;
export PATH=${SRM_PATH}/bin:${PATH};
export X509_USER_CERT=/phedex-grid-security/hostcert.pem; 
export X509_USER_KEY=/phedex-grid-security/hostkey.pem;
export X509_USER_PROXY=/home/csf/phtab/PhEDEx/gridcert/proxy;
export LD_PRELOAD="/opt/d-cache/dcap/lib/libpdcap.so";
#export DCACHE_IO_TUNNEL="/opt/d-cache/dcap/lib/libgsiTunnel.so";
