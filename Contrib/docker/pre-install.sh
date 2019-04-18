myarch=slc6_amd64_gcc493 # for 4.2.X on SLC6
repo=comp # for 4.2.1 on SLC6
export sw=/home/phedex/sw
cd /home/phedex
mkdir -p state logs gridcert
chmod 700 gridcert
mkdir $sw

wget -O $sw/bootstrap.sh http://cmsrep.cern.ch/cmssw/repos/bootstrap.sh
sh -x $sw/bootstrap.sh setup -path $sw -arch $myarch -repository $repo 2>&1|tee $sw/bootstrap_$myarch.log
$sw/common/cmspkg -a $myarch update
$sw/common/cmspkg -a $myarch search PHEDEX|grep PHEDEX+

version=4.2.1  # for 4.2.1 on SLC6

$sw/common/cmspkg -a $myarch --force install cms+PHEDEX+$version
rm -f PHEDEX; ln -s $sw/$myarch/cms/PHEDEX/$version PHEDEX
