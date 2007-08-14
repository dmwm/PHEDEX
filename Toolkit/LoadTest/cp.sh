#!/bin/sh

FNAME=$1
BASEPATH="/tmp/"

cp $FNAME ${BASEPATH}${FNAME}
exit $?
