setenv T0_TMDB_BASE     `dirname $0`
setenv T0_TMDB_BASE     `cd $T0_TMDB_BASE && cd .. && pwd`
setenv T0_TMDB_SCRIPTS  ${T0_TMDB_BASE}/scripts
setenv T0_TMDB_MODELS   ${T0_TMDB_BASE}/models
setenv T0_TMDB_LOGS     ${T0_TMDB_BASE}/logs
setenv T0_TMDB_DROP     ${T0_TMDB_BASE}/incoming

# setenv T0_RLS_CATALOG	xmlcatalog_file:$T0_TMDB_BASE/logs/catalog.xml
setenv T0_RLS_CATALOG	edgcatalog_http://rlscert01.cern.ch:7777/cms/v2.2/edg-local-replica-catalog/services/edg-local-replica-catalog

eval `cd /afs/cern.ch/sw/lcg/app/releases/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 runtime -csh`
source  /afs/cern.ch/project/oracle/script/setoraenv.csh -s 8174
