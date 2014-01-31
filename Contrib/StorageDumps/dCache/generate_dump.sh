#!/bin/bash

# Requires that postrgres-python is installed
# Requires the "chimera-dump.py" script available
# Requires cd_conf.py to contain the name of the Chimera host (dchpnfs)
# Requires the Chimera host to accept Postgres queries from this host

# Run the chimera dump
./chimera-dump.py  -s /pnfs/ciemat.es/data/cms/ -c fulldump -o dcache.cms.dump

# Uncompress it (required for sed operation) 
bunzip2 dcache.cms.dump.xml.bz2

# Transform it (PFN -> LFN)
sed -e 's#/pnfs/ciemat.es/data/cms/store/user/#/store/user/#' \
    -e 's#/pnfs/ciemat.es/data/cms/scratch/user/#/store/temp/user/#' \
    -e 's#/pnfs/ciemat.es/data/cms/store/group/#/store/group/#' \
    -e 's#/pnfs/ciemat.es/data/cms/prod/store/#/store/#' \
    -e '/\/pnfs\/ciemat.es\/data\/cms\/Tier3/d' \
    -e '/\/pnfs\/ciemat.es\/data\/cms\/generated/d' \
    -e 's#<dCache:location>.*<dCache:location>##' \
      dcache.cms.dump.xml | uniq > dcache.cms.dump.xml.new

mv  dcache.cms.dump.xml.new  dcache.cms.dump.xml

# Compress it again
bzip2 dcache.cms.dump.xml
