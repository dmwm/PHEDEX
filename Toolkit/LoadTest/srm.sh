#!/bin/sh

FNAME=$1
BASEPATH="srm://io.hep.kbfi.ee:8443/srm/managerv2?SFN=/pnfs/hep.kbfi.ee/cms/LoadTest07/"

PROTOCOLOPTION="-srm_protocol_version=2"

if [[ $BASEPATH =~ srm/managerv1 ]]; then
    PROTOCOLOPTION="-srm_protocol_version=1"
fi    

srmcp -debug=true $PROTOCOLOPTION -retry_num=3 file:///`pwd`/$FNAME ${BASEPATH}${FNAME}
exit $?
