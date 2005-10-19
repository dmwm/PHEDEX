* Processing transfer requests

When you receive a transfer request, it includes a set of commands
to execute.  In addition to these commands cron jobs execute every
once in a while, updating the transfer progress status of pending
requests; see Custom/CERN/AFSCrontab and scripts for details.

** Setting up

ssh phedex@cmsgate.cern.ch
cd /data/V2Nodes/PHEDEX
eval $(./Utilities/Master -config Custom/CERN/Config.Prod environ)
TRTOOLS=$PWD/Toolkit/Request
DBPARAM=$PWD/Schema/DBParam
cd /afs/cern.ch/cms/aprom/phedex/TransferRequests

** Execute the transfer request

The transfer request includes all the commands you need to execute.
Simply copy and paste them into the shell now.

** Synchronise

This is optional: the request will be automatically synchronised the
following night.  It is only important to execute these commands for
urgent requests; all requests to TX_ZIP_Subsitute are urgent.

$TRTOOLS/TRSyncAllocs -db $DBPARAM:Production/Admin 2005-10/*
$TRTOOLS/TRSyncWeb -db $DBPARAM:Production/Admin 2005-10/*
$TRTOOLS/TRSyncStatus -dbs RefDB -db $DBPARAM:Production/Admin '2005-10-*'

Here "2005-10" is the directory with requests for this month.  You can
run the first two commands with 2005-*/* for example, but do not run
the last command on all requests unless you are prepared to wait for a
long time.

** Security

Note that only Admin and CERN accounts are allowed to modify the
database for TMDB subscriptions and to maintain the request data.
Also the AFS area is protected and writable only by the admins.
