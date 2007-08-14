#!/bin/sh

for i in `seq 256`; do 
  ./CreateFile $i LoadTest07_YOURSITE_ srm.sh nohex
done

