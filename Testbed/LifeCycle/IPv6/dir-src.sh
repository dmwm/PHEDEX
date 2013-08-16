#!/bin/sh

echo ' '
echo ' '
echo chicago
echo /home/ipv6user/wildish
echo dir /home/ipv6user/wildish/src | uberftp ml-chi-v4.uslhcnet.org

echo ' '
echo ' '
echo lhcnet
echo /home/wildish/ipv6user
echo dir /home/wildish/ipv6user/src | uberftp hermes-gva.uslhcnet.org

echo ' '
echo ' '
echo infn
echo /var/tmp/wildish
echo dir /var/tmp/wildish/src | uberftp seipersei.mi.infn.it

echo ' '
echo ' '
echo desy
echo /scratch/ipv6user/wildish
echo dir /scratch/ipv6user/wildish/src | uberftp hepix01.desy.de

echo ' '
echo ' '
echo gridka
echo /var/tmp/hepix_ipv6/wildish
echo dir /var/tmp/hepix_ipv6/wildish/src | uberftp hepix01-v4.gridka.de

echo ' '
echo ' '
echo cern
echo /home/ipv6user/wildish/
echo dir /home/ipv6user/wildish/src | uberftp v6hepix.cern.ch

#echo ' '
#echo ' '
#echo garr
#echo /home/ipv6user/wildish
#echo dir /home/ipv6user/wildish/src | uberftp hepix-ui.dir.garr.it

echo ' '
echo ' '
echo fzu
echo /tmp/wildish
echo dir /tmp/wildish/src | uberftp ui.ipv6.farm.particle.cz

echo ' '
echo ' '
echo imperial
echo dir /srv/localstage/ipv6test/wildish/src | uberftp hepix00.grid.hep.ph.ic.ac.uk

echo ' '
echo ' '
echo ihep
echo dir /home/ipv6user/wildish/src | uberftp ui01-hepix-v4.ihep.ac.cn | grep ipv6test
echo ' '
echo ' '
echo pic
echo dir /home/ipv6user/wildish/src | uberftp hepix01-v4.pic.es | grep ipv6user
