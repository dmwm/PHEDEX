#!/bin/sh

if [ $# != 1 ]; then
    echo "please give directory containing files to create drops for as argument"
    echo "example: run_FeedExporterFromCastorDirectory.sh /castor/cern.ch/cms/store/test"
    exit 1
fi

${T0FeedBasedir}/Bin/FeedExporterFromCastorDirectory.pl --config ${T0FeedBasedir}/Config/ExportFeeder.conf --dir $1
