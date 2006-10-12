To install PhEDEx web service, you will need the following.

* Setting up the web server

In the basic mode, you can just plop PHEDEX/Documentation/WebSite under any
odd Apache directory you like. The scripts under "cgi-bin" will need to be
able to execute as CGI scripts, and need access to Oracle (see DBS operations
guide for instructions on setting up httpd so it can access Oracle). We keep
our web server updated from CVS every fifteen minutes, see the cron jobs
above.

For a faster server operating under mod_perl, you follow roughly the same
scheme as with DBS.

On cmslcgco03:
$ cd /data
$ cvs co PHEDEX/Documentation/WebSite
On AFS:
$ cd /afs/cern.ch/cms/aprom/phedex
$ mkdir Documents DBPerfData DBAccessInfo WebSite WebMirror Logs
$ cvs co -d WebSite COMP/PHEDEX/Documentation/WebSite
$ cd WebSite
$ ln -s ../{DBPerfData,WebMirror,Documents} .
Modify the web server start-up service to source the correct environment, add
the module configuration and make sure mod_perl preload configuration is
correct, all as per DBS instructions. Then test and restart the server as
shown on the DBS instructions.
Add appropriate Alias, Location and Directory settings for the PhEDEx
directories. Make sure the scripts in "cgi-bin" can execute as CGI scripts;
the scripts don't have any suffic. PhEDEx also requires the server to include
PHP built with GD with TTF support; the scripts are also in "cgi-bin" and end
in .php. You'll normally get the required components by installing the
appropriate system RPMs.
PhEDEx web server should be ran with sufficient httpd servers. It's fine to
run with the suggested configuration on the DBS operations page. It is not
recommended to run with the "reduced" settings for development mentioned
there.
We are working on SSL-secured web pages for PhEDEx. Instructions for deploying
such a server with grid-certificate verification will be listed here once the
configuration has been completed.



* Cron jobs

*/11 * * * * (echo "PhEDEx CVS update $(date)"; CVS_PASSFILE=/data/.cvspass /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot /data/PHEDEX/V2.3-Test) >> /data/cvs-update-phedex-test.txt 2>&1
*/13 * * * * (echo "PhEDEx CVS update $(date)"; CVS_PASSFILE=/data/.cvspass /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot -rWebSite /data/PHEDEX/V2.3-Production) >> /data/cvs-update-phedex-prod.txt 2>&1
*/10 * * * * (echo "Heartbeat CVS update $(date)"; CVS_PASSFILE=/data/.cvspass /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot /data/HEARTBEAT) >> /data/cvs-update-heartbeat.txt 2>&1
