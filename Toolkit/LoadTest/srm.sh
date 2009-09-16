#!/bin/sh

FNAME=$1
BASEPATH="srm://io.hep.kbfi.ee:8443/srm/managerv1?SFN=/pnfs/hep.kbfi.ee/cms/LoadTest07/"

srmcp -debug=true -retry_num=3 file:///`pwd`/$FNAME ${BASEPATH}${FNAME}
exit $?
