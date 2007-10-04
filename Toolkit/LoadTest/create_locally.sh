#!/bin/sh

for i in `seq 0 255`; do 
  ./CreateFile $i LoadTest07_YOURSITE_ srm.sh nohex
done

