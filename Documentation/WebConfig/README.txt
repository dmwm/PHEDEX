This document describes how to set up the web server.

* Overview

There are PhEDEx instances, each with an associated database (TMDB).
Separately there is a PhEDEx web site, which allows clients to look
into what is happening in the databases.  A single web service can
show the status of any number of PhEDEx database instances.

The web service serves only a small number of static files, most of
the content is dynamically generated from the state of the PhEDEx
database instance by a CGI script.  The operation of the web service
depends on a number of PhEDEx service agents running somewhere else.
This is because the web site rarely displays the true state of the
full database, the queries would be far too expensive; and of course
it would not be able to show historical information.  The PhEDEx
service agents monitor the state of the entire system and make the
current and historical metrics available for quick access by the web
service.

There should be two separate web service locations, one for the
production use and another for testing and development.  Normally both
services would serve the same set of databases, the test one possibly
adding development databases.  It is possible to host both services in
different directories on the same server.

* Security

The secure portions of the site are expected to be accessed with https
authenticated using the grid certificate of a person signed up to be a
PhEDEx administrator.  The https negotiation can be done either by the
server hosting the site, or by a front-end proxy server.  In the
latter case the configuration needs to be done with extreme care to
avoid opening security holes.  The standard service at CERN operates
behind a proxy.

* Server configuration overview

The PhEDEx web server is designed to run under Apache and mod_perl.
It is no doubt possible to make it work under other configurations,
only we have not tested any.  In theory mod_perl could be avoided, but
it is essential for a pleasant user experience.

At CERN the site is visible via proxy-only server cmsdoc.cern.ch,
which hands the actual requests to a back end server.  We describe
the configurations for both.

The front-end server runs Apache 2.2.x on a Solaris system.  For the
insecure part, it just does the normal proxy for the service URL using
"RewriteRule ... [P,L]" rules.  The secure part does SSL negotiation
with optional client verification, matching the user's certificate
public key against the grid certificate authority certificates (CA
certs).  The results of the user verification are passed to the back
end server in extra HTTP header parameters.

In the front end server, the SSL client verification is restricted
inside the PhEDEx service <Location>, i.e. it's not global to the
whole server -- asking all secure access to cmsdoc.cern.ch to present
a certificate would be inappropriate.  This means that at protocol
level a SSL re-negotiation is triggered.  Due to various Apache bugs
and security concerns in the interactions of buffering POST requests
and the SSL session re-negotiation, it is mandatory to use Apache 2.2
at least for the secure part of the web.  To our knowledge there is
no way to get Apache 2.0.x to work reliably.

The back end server is a Scientific Linux 4 system running the system
Apache 2.0.52.  The system mod_perl however is not usable, it is an
odd RedHat hybrid of mod_perl versions 1 and 2.  We installed mod_perl
2.0.2 into /opt/mod_perl2.  In addition we installed the mod_php from
the system distribution, with PHP support for GD, TrueType and MySQL.
The system firewall was configured to restrict connections to the web
server port (80) to be from the proxy server only.  The back end
server is not enabled to listen for secure connections.

The PhEDEx web service administrators have no access to the front end
server.  For the back end server they are given sudo access to manage
the Apache /etc/httpd/conf.d configuration file for PhEDEx, to restart
the server using /etc/rc.d/init.d/httpd, and to watch the server logs
in /var/log/httpd.

* Front end server configuration

The front end needs the following proxy redirect rule, assuming the
back end server is cmslcgco03 and expects the same URL structure as
the front-end:

  RewriteEngine  on
  RewriteRule ^(/cms(/test)?/aprom/phedex.*) http://cmslcgco03$1 [P,L]

For the secure part the above needs to be preceded by the following
in the <VirtualHost> for port 443, in addition to standard SSL stuff:

  # Grid CA certificates for authentication
  SSLCACertificateFile  /etc/httpd/conf/ca-bundle-client.crt
  SSLCARevocationFile /etc/httpd/conf/ca-bundle-revocation.crl

  # Pass SSL_CLIENT_CERT, SSL_CLIENT_S_DN, SSL_CLIENT_VERIFY
  # into the proxy request to the back-end server.
  RequestHeader set SSL_CLIENT_CERT %{SSL_CLIENT_CERT}e
  RequestHeader set SSL_CLIENT_S_DN %{SSL_CLIENT_S_DN}e
  RequestHeader set SSL_CLIENT_VERIFY %{SSL_CLIENT_VERIFY}e
  RequestHeader set HTTPS %{HTTPS}e

  # Require authentication to the PhEDEx service
  <LocationMatch ~ "^/cms(/test)?/aprom/phedex">
    SSLRequireSSL
    SSLVerifyDepth 1
    SSLVerifyClient optional
    SSLOptions +StdEnvVars +StrictRequire +CompatEnvVars +ExportCertData
    SSLRequire %{SSL_CIPHER_USEKEYSIZE} >= 128
  </LocationMatch>

Note that you should not use "SSLVerifyClient require", or restrict
proxy to only pass through successful authentications.  The back end
takes care of that gracefully using the additional headers.

Here, /etc/httpd/conf/ca-bundle-client.crt is the combination of all
the grid CA certificate public keys, and should be automatically
updated as the public keys are on any grid user interface system.
The file can be generated simply with:

  gridcerts=/etc/grid-security/certificates # (where ever they are)
  cat $gridcerts/*.[0-9] > /etc/httpd/ssl/ca-bundle-client.crt

The /etc/httpd/conf/ca-bundle-revocation.crl needs to be updated
automatically similarly for the list of revoked grid certificates.
[FIXME: instructions to generate the file!]

Make sure httpd is automatically started on system startup.

* Back end server configuration

** System setup

This sub-section needs to be done by the system administrator.  Nearly
all the rest can be done by the PhEDEx web service administrator.

Install Scientific Linux 4 with httpd RPMs (Apache 2.0.52).  You need
also the development bits; mod_deflate is included in the httpd RPM.
Install the PHP RPMs: php, php-pear, php-gd, php-mysql (4.3.9).

Next download and install mod_perl 2.x into a location of your choice.
If you are installing as root, you can install from CPAN, otherwise
build it into some non-root location.  Installation with CPAN would go
as follows:

  $ perl -MCPAN -e shell
  cpan> install mod_perl2
  cpan> quit

Install other basic perl modules if not already available on the
system.  Most of these should be present or at least available as
system RPMs, but if not you can install them from CPAN:

  $ perl -MCPAN -e shell
  cpan> install Apache-DBI
  cpan> install CGI
  cpan> install CGI::Untaint
  cpan> quit

Give sudo access to the administrators.  They need to at least edit
the service configuration files under /etc/httpd/conf.d, manage the
server using /etc/rc.d/init.d/httpd, and to see the logs in
/var/log/httpd.

Change the firewall to accept connections only from the proxy server.
This is a highly recommended additional security measure.  Doing so
prevents anyone from even attempting to spoof the HTTPS parameters
passed by the front end server to the back end in extra headers.

** Configure CMS web service directories

We will assume that the PhEDEx web services are installed into /data,
each service into its own subdirectory.  The service operators should
have full write access to this directory.

  cd /data
  mkdir Tools PHEDEX HEARTBEAT
  cd PHEDEX
  mkdir DBAccessInfo V2.3-Production V2.3-Test V2.3-Old

** Install CMS basic web service kit

  cd /data/Tools
  wget http://cmsdoc.cern.ch/cms/cpt/Software/download/cms.phedex/aptinstaller.sh
  chmod +x aptinstaller.sh

  ./aptinstaller.sh -path $PWD -arch slc4_ia32_gcc345 -repository cms.phedex setup
  eval `./aptinstaller.sh -path $PWD config -sh`
  apt-get update
  apt-get install cms+PHEDEX-server+1.0

** Install PhEDEx and heart beat web services

  cd /data/PHEDEX
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
  cvs co -d V2.3-Production -r WebSite PHEDEX
  cvs co -d V2.3-Test PHEDEX
  cvs co -d V2.3-Old -r PHEDEX_2_3_12 PHEDEX

  cd /data
  cvs co HEARTBEAT

** Configure automatic updates

Add the following cron jobs; the "update-cvsshot" script is available
in CMSToolBox/CommonScripts/Snapshot/bin in the CMSToolBox CVS
repository.

  */11 * * * * (echo "PhEDEx CVS update $(date)"; CVS_PASSFILE=/data/.cvspass
    /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot
    /data/PHEDEX/V2.3-Test) >> /data/cvs-update-phedex-test.txt 2>&1
  */13 * * * * (echo "PhEDEx CVS update $(date)"; CVS_PASSFILE=/data/.cvspass
    /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot
     -rWebSite /data/PHEDEX/V2.3-Production) >> /data/cvs-update-phedex-prod.txt 2>&1
  */10 * * * * (echo "Heartbeat CVS update $(date)"; CVS_PASSFILE=/data/.cvspass
    /afs/cern.ch/user/l/lat/dev/CommonScripts/Snapshot/bin/update-cvsshot
    /data/HEARTBEAT) >> /data/cvs-update-heartbeat.txt 2>&1

** Configure PhEDEx web service and database access

Create the following configuration files in /data/PHEDEX/DBAccessInfo.
The files need to be owned by the service administrator, group apache
(or whatever group the httpd runs under), and have mode 0640.

*IMPORTANT*: These files contain passwords and must be kept secure!

 phedex_prod.conf:
   server-root:		http://cmsdoc.cern.ch
   ssl-server-root:	https://cmsdoc.cern.ch:8443
   service-path:	/cms/aprom/phedex

   instance:					\
    id            = prod			\
    title         = Production			\
    database-name = cms_transfermgmt		\
    user-name	  = cms_transfermgmt_reader	\
    password	  = <password>			\
    version	  = V2.3
 
   instance:					\
    id            = sc				\
    title         = SC4				\
    database-name = cms_transfermgmt_sc		\
    user-name     = cms_transfermgmt_sc_reader	\
    password      = <password>			\
    version       = V2.3
 
   instance:					\
    id            = test			\
    title         = Dev				\
    database-name = cms_transfermgmt_test	\
    user-name     = cms_transfermgmt_test_reader \
    password      = <password>			\
    version       = V2.3

   instance:					\
    id            = tbedi			\
    title         = Testbed			\
    database-name = cms_transfermgmt_test	\
    user-name     = cms_transfermgmt_testbed	\
    password      = <password>			\
    version       = V2.3

   instance:					\
    id	          = tbed			\
    title	  = Validation			\
    database-name = int2r_nolb			\
    user-name     = cms_transfermgmt_testbed	\
    password      = <password>			\
    version       = V2.3

 phedex_test.conf:
   server-root:		http://cmsdoc.cern.ch
   ssl-server-root:	https://cmsdoc.cern.ch:8443
   service-path:	/cms/test/aprom/phedex

   instance:					\
    id            = prod			\
    title         = Production			\
    database-name = cms_transfermgmt		\
    user-name	  = cms_transfermgmt_reader	\
    password	  = <password>			\
    version	  = V2.3
 
   instance:					\
    id            = sc				\
    title         = SC4				\
    database-name = cms_transfermgmt_sc		\
    user-name     = cms_transfermgmt_sc_reader	\
    password      = <password>			\
    version       = V2.3
 
   instance:					\
    id            = test			\
    title         = Dev				\
    database-name = cms_transfermgmt_test	\
    user-name     = cms_transfermgmt_test_reader \
    password      = <password>			\
    version       = V2.3

   instance:					\
    id            = tbedi			\
    title         = Testbed			\
    database-name = cms_transfermgmt_test	\
    user-name     = cms_transfermgmt_testbed	\
    password      = <password>			\
    version       = V2.3

   instance:					\
    id	          = tbed			\
    title	  = Validation			\
    database-name = int2r_nolb			\
    user-name     = cms_transfermgmt_testbed	\
    password      = <password>			\
    version       = V2.3

** Configure Apache

Make sure Apache is configured to run enough concurrent children.  The
default pre-fork web service settings should be suitable.  We use the
values shown below.  This change needs to be made by the system
administrator.

  <IfModule prefork.c>
  StartServers         8
  MinSpareServers      5
  MaxSpareServers      20
  ServerLimit          256
  MaxClients           256
  MaxRequestsPerChild  4000
  </IfModule>

Change the web server logs to include the upstream client host as
shown below.  This change must be made by the system administrator.

  LogFormat "%h %{X-Forwarded-For}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
  LogFormat "%h %{X-Forwarded-For}i %l %u %t \"%r\" %>s %b" common
  LogFormat "%{Referer}i -> %U" referer
  LogFormat "%{User-agent}i" agent
  CustomLog logs/access_log combined

Change /etc/rc.d/init.d/httpd to source the software environment for
the web server.  This change must be done by the system administrator.

    # Add below:
    #   if [ -f /etc/sysconfig/httpd ]; then
    #     . /etc/sysconfig/httpd
    #   fi
    . /data/PHEDEX/V2.3-Production/Documentation/WebConfig/httpd-env.sh

Create a "cms.conf" in /etc/httpd/conf.d.  This must be done by the
system administrator.

  cat > /etc/httpd/conf.d/cms.conf <<EOF
  include /data/PHEDEX/V2.3-Production/Documentation/WebConfig/mod-perl.conf
  include /data/PHEDEX/V2.3-Production/Documentation/WebConfig/dbs.conf
  include /data/PHEDEX/V2.3-Production/Documentation/WebConfig/heartbeat.conf
  include /data/PHEDEX/V2.3-Production/Documentation/WebConfig/phedex.conf
  EOF

Edit the configuration files to set the correct paths.  These can now
be done by the PhEDEx service administrator.

  - In httpd-env.sh:
    - Edit the path to where you installed the software.

  - In mod-perl.conf:
     - Check that LoadModule points to the right module
     - Check PerlSwitches if you installed in custom location
     - Check the path to PerlRequire if you use different paths

  - In mod-perl-preload.pm:
     - Nothing to do really, verify that all these modules are available

 - In dbs.conf and heartbeat.conf:
     - Adjust Alias for service URL
     - Adjust the Directory and Location paths
     - In dbs.conf set DBS_DBPARAM path

 - In phedex.conf:
    - Check the RewriteRules to match your directories.  There are
      common rules for both production and test service, then separate
      rules for each.
    - Update the DirectoryMatch for /data/PHEDEX to accept connections
      only from your front end server.  This is second line protection
      against spoofing bad HTTPS headers to the service.
    - Update PHEDEX_SERVICE_CONFIG in the first two (Production, Test)
      DirectoryMatch rules.  You shouldn't need to change any other
      options.

** (Re)start apache

First test your configuration:

  sudo /etc/rc.d/init.d/httpd configtest

If everything seems fine, restart apache:

  sudo /etc/rc.d/init.d/httpd graceful

Check the logs for accesses and errors while you access the pages:

  sudo tail -f /var/log/httpd/{access,error}_log
