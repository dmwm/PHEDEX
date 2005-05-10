#!/bin/sh

node= dataset= owner= lfn=
for arg; do
  case $arg in
    node=*) node=$(echo $arg | sed 's![^=]*=!!') ;;
    guid=*) guid=$(echo $arg | sed 's![^=]*=!!') ;;
    owner=*) owner=$(echo $arg | sed 's![^=]*=!!') ;;
    dataset=*) dataset=$(echo $arg | sed 's![^=]*=!!') ;;
    lfn=*) lfn=$(echo $arg | sed 's![^=]*=!!') ;;
  esac
done

case $owner in
    *Hit*) subpath='Hit' ;;
    *PU*) subpath='Digi' ;;
    *DST*) subpath='DSTs';;
esac

case $lfn in
    *.ntuple) subpath='CMKin';;
    *.fz) subpath='CMSim';;
esac

case $dataset in
    *MBforPU*) subpath='MBforPU' ;;
esac

[ -z "$subpath" ] && { echo "no subpath" 1>&2; exit 1; }
[ -z "$owner" ] && { echo "no owner" 1>&2; exit 1; }
[ -z "$dataset" ] && { echo "no dataset" 1>&2; exit 1; }
[ -z "$lfn" ] && { echo "no lfn" 1>&2; exit 1; }
 
# Copy everything into a subdirectories of a local directory.
basedir=${node}
local=$basedir/$subpath/$dataset/$lfn
echo file:/$local |perl -ne 'print length() < 250 ? $_ : substr($_, 0, 210)."'$guid'"'

