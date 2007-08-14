#!/bin/sh

FNAME=$1
# Set BASEPATH as appropriate for your site!
# e.g.  BASEPATH="srm://io.hep.kbfi.ee:8443/srm/managerv1?SFN=/pnfs/hep.kbfi.ee/cms/LoadTest07/"
BASEPATH="YOURBASEPATH"
srmcp -debug=true -retry_num=3 file:///`pwd`/$FNAME ${BASEPATH}${FNAME}
exit $?
