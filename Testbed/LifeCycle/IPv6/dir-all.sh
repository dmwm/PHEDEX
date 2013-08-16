#!/bin/sh

echo ' '
echo ' '
echo chicago
echo /home/ipv6user/wildish
echo dir /home/ipv6user/wildish | uberftp ml-chi-v4.uslhcnet.org | grep ipv6user

echo ' '
echo ' '
echo lhcnet
echo /home/wildish/ipv6user
echo dir /home/wildish/ipv6user | uberftp hermes-gva.uslhcnet.org | grep ipv6user

echo ' '
echo ' '
echo infn
echo /var/tmp/wildish
echo dir /var/tmp/wildish | uberftp seipersei.mi.infn.it | grep ipv6user

echo ' '
echo ' '
echo desy
echo /scratch/ipv6user/wildish
echo dir /scratch/ipv6user/wildish | uberftp hepix01.desy.de | grep ipv6user

echo ' '
echo ' '
echo glasgow
echo /home/ipv6user/wildish
echo dir /home/ipv6user/wildish | uberftp dev011-v4.gla.scotgrid.ac.uk | grep ipv6user

echo ' '
echo ' '
echo gridka
echo /var/tmp/hepix_ipv6/wildish
echo dir /var/tmp/hepix_ipv6/wildish | uberftp hepix01-v4.gridka.de | grep ipv6user

echo ' '
echo ' '
echo cern
echo /home/ipv6user/wildish/
echo dir /home/ipv6user/wildish | uberftp v6hepix.cern.ch | grep ipv6user

#echo ' '
#echo ' '
#echo garr
#echo /home/ipv6user/wildish
#echo dir /home/ipv6user/wildish | uberftp hepix-ui.dir.garr.it | grep ipv6user

echo ' '
echo ' '
echo fzu
echo /tmp/wildish
echo dir /tmp/wildish | uberftp ui.ipv6.farm.particle.cz | grep ipv6user

echo ' '
echo ' '
echo ihep
echo dir /home/ipv6user/wildish | uberftp ui01-hepix-v4.ihep.ac.cn | grep ipv6test

echo ' '
echo ' '
echo imperial
echo dir /srv/localstage/ipv6test/wildish | uberftp hepix00.grid.hep.ph.ic.ac.uk | grep ipv6test

echo ' '
echo ' '
echo pic
echo dir /home/ipv6user/wildish | uberftp hepix01-v4.pic.es | grep ipv6user
