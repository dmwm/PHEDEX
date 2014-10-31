#!/bin/bash

cp ../2Node/Config* .
for f in Config*
do
  mv $f $f.orig
  cat $f.orig | sed -e 's%2Node%4Node%g' | tee $f >/dev/null && rm $f.orig
done

port=`grep PHEDEX_NOTIFICATION_PORT= Config.Test1.MSS | awk -F= '{ print $2 }' | tr -d ';'`
echo Found notification port $port

oldport=$port
for i in 2 3 4
do
  port=`expr $port + 1`
  echo "Prep config for node $i, port $port"
  cat Config.Test1.MSS | \
	sed -e "s%Test1%Test${i}%g" | \
	sed -e "s%$oldport%$port%" | \
	tee Config.Test${i}.MSS > /dev/null
done
