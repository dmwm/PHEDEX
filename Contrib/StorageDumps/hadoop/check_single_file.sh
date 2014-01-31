#!/bin/sh
# See: https://twiki.cern.ch/twiki/bin/vie...
# Check a single file and output PFN,Size,Time stamp and check sum (optional)
FILE=$1
CKSUMFILE=`echo $FILE | sed 's/hadoop/hadoop\/cksums/'`
if [ -f $CKSUMFILE ] ; then
ADLER32=`grep ADLER32 $CKSUMFILE | awk -F\: '{print $2}'`
if [ -z $ADLER32 ] ; then
ADLER32="N/A"
fi
else
ADLER32="N/A"
ls -lc --time-style=+%s $FILE | \
awk -v val=$ADLER32 '{print $7"|"$5"|"$6"|" val}' | sed 's/ //g'
exit
