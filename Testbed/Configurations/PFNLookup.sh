#!/bin/sh

# Lassi's script for Cern modified to meet FZK requirements
##H Usage: PFNLookup -u CATALOGUE -n PFNSEL { -g | -p | -q } [-m] PROTO FORNODE TERM...
##H
##H List GUID/PFN pairs for query terms.  Use -g/-p/-q to select
##H query mode:
##H   -g  TERMs are GUIDs
##H   -p  TERMs are PFNs
##H   -x  TERMs are general queries
##H
##H If -m is used, the terms are taken to be patterns.  This only
##H makes sense with -g and -p.
##H
##H Queries the CERN EVD file catalogue (POOL MySQL / ORACLE),
##H which has file names of the form rfio:/castor/cern.ch/...,
##H and maps them for access using PROTO protocol and transfer
##H to node FORNODE using the PFN search pattern PFNSEL.
##H
##H CERN supports PROTOs "gsiftp", "srm" and "direct", where
##H the latter means direct local access.  The TURL is not
##H dependent on FOR-NODE in any way.


# Pick up options
cat= pfnsel= match= mode= proto= fornode= rewrite=
while [ $# -ge 1 ]; do
  case $1 in
    -u )
      cat="$2"; shift; shift ;;
    -n )
      pfnsel=$2; shift; shift ;;
    -g | -p | -x | -q)
      mode=$1; shift ;;
    -m )
      match=$1; shift ;;
    -h )
      grep "^##H" < $0 | sed 's/^##H\( \|\)//'; exit 1 ;;
    -* )
      echo "unrecognised option $1" 1>&2; exit 1 ;;
    * )
      break ;;
  esac
done

proto="$1"; shift
fornode="$1"; shift

[ -z "$cat" ] && { echo "$0: no catalogue specified" 1>&2; exit 1; }
[ -z "$mode" ] && { echo "$0: no lookup mode specified" 1>&2; exit 1; }
[ -z "$proto" ] && { echo "$0: no protocol specified" 1>&2; exit 1; }
[ -z "$fornode" ] && { echo "$0: no destination node specified" 1>&2; exit 1; }
[ -z "$pfnsel" ] && { echo "$0: no PFN search pattern specified" 1>&2; exit 1; }

case $proto:$mode in
#  direct:-p  ) rewrite='s| rfio:| |'
#	      set -- $(echo ${1+"$@"} | sed 's|\(^\| \)/castor|\1rfio:/castor|g') ;;
   direct:*   ) rewrite='s|file:| |'
	        pfnselect="$pfnsel";;
   gsiftp:*   ) rewrite='s|file:| |'
	        pfnselect="$pfnsel";;
  *          ) echo "$0: unrecognised protocol $1" 1>&2; exit 1 ;;
esac

tools="$(dirname $0)/../../Utilities"
"$tools/PFClistGuidPFN" -u "$cat" -j 10 $mode $match ${1+"$@"} |grep "$pfnselect" 2> /dev/null
exit $?
