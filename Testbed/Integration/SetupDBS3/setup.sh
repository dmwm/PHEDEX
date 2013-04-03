#!/bin/bash

source ./setup_env.sh

source $SWAREA/$SCRAM_ARCH/cms/dbs3-lifecycle/$DBS3LIFECYCLEVERSION/etc/profile.d/init.sh
## setup dbs_client
export DBS_READER_URL=https://dbs3-integ.cern.ch/dbs/dev/global/DBSReader
export DBS_WRITER_URL=https://dbs3-integ.cern.ch/dbs/dev/global/DBSWriter
