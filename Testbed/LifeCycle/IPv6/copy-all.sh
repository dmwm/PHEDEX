#!/bin/sh


doit() {
  echo "host=$host"
  echo "dir=$dir"
  echo globus-url-copy -ipv6 file://$fullfile gsiftp://$host/$dir/src/$file
       globus-url-copy -ipv6 file://$fullfile gsiftp://$host/$dir/src/$file
}

file=file-500.gz
fullfile=/data/ipv6/PHEDEX/Testbed/LifeCycle/IPV6/data/$file
echo lhcnet
dir=/home/wildish/ipv6user
host=hermes-gva.uslhcnet.org
doit

echo infn
dir=/var/tmp/wildish
host=seipersei.mi.infn.it
doit

#echo desy
#dir=/scratch/ipv6user/wildish
#host=hepix01.desy.de
#doit

echo gridka
dir=/var/tmp/hepix_ipv6/wildish
host=hepix01-v4.gridka.de
doit

echo garr
host=hepix-ui.dir.garr.it
dir=/home/ipv6user/wildish
doit

echo fzu
host=ui.ipv6.farm.particle.cz
dir=/tmp/wildish
doit
