* Setting up for using PhEDEx

This document describes how to set up your site for CMS data movement.
The intended audience are site data managers that need to import or
export CMS data.

** Related documents

README-Overview.txt explains where this document fits in.
README-Operations.txt explains how things are done at CERN.
README-Transfer.txt explains how to set up transfer agents.
README-Export.txt explains how to set up export agents.

**********************************************************************
** Overview

To use PhEDEx to transfer files you need:
  Hardware:
  HW.1) Disk pool / MSS system to transfer from/to
  HW.2) Machine for running the agents
  HW.3) Machine for file catalogue

  Software:
  SW.1) PhEDEx itself
  SW.2) LCG POOL tools
  SW.3) ORACLE client libraries
  SW.4) Prerequisite perl modules
  SW.5) Transfer utilities: globus, srm, lcg-rep or similar

  Services:
  SV.1) A site-local file catalogue
  SV.2) Certificate management

  Configuration:
  CF.1) Get registered to the transfer topology
  CF.2) Site-specific scripts

** Getting the hardware

To act as a transfer node in the PhEDEx network, you obvioulsy need a
storage system.  This can be either local or mounted disks, a managed
pool (Castor, dCache, ...), and may or may not be backed up by a tape
mass storage system.

Some commonly used configurations:
  - Castor pools with automatic/configurable migration to tape,
    accessed for transfers via gridftp servers, but also directly
    with rf* commands
  - dCache pools, both stand-alone and linked to mass store,
    accessed for transfers either directly or via gridftp servers
  - NFS-mounted GPFS disk pools
  - Other directly mounted disk pools

It is important that you have high-speed network connection to your
disk pool.  It is advisable there to be a gridftp network access path
that bypasses firewalls.

You will also need a computer on which you will run the agents.  This
needs to be either CERN RedHat 7.3.x or SLC3/IA32 system.  You must
have access to local or mounted disk space on the machine; AFS will
not do.  You do not need large amounts of memory, disk space, network
bandwidth or CPU capacity on this machine.  You do need to have all
the prerequisite software installed on this machine.

You can choose to install your site-local file catalogue on the same
machine on which you run the agents, in which case it needs a little
more horsepower, and obvioulsy needs proper backup etc. services.
On the other hand, if you have central database support, you will
probably want to have them run your file catalogue.  Most CMS sites
use a MySQL file catalogue; CERN is about to switch to ORACLE one.

**********************************************************************
** Getting the software

This document assumes you will install the software on "agenthost"
in directory "/home/phedex".  We assume the PhEDEx node name for
your site is "FOO_Transfer" (and possibly "FOO_MSS").

*** Set up directories

  mkdir -p /home/phedex/{state,logs,tools,gridcert}
  chmod 700 /home/phedex/gridcert

*** PhEDEx

  cd /home/phedex
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
  cvs login # password is "98passwd"
  cvs co PHEDEX

*** LCG POOL tools

The POOL tools are required for CMS transfers, but not by core PhEDEx.
Skip this section if you don't intend to participate in CMS transfers.

You can either use an existing POOL installation on your system, or
make a standalone installation from RPMs.  We assume you use a tool
provided in PHEDEx to set things up for the sake of simplicity.  You
need POOL version 1.6.2 or later.  We recommend versions 1.6.4, 1.6.5
or 2.0.x; do not use 1.8.x versions.

If you have CMS software installed such that "scram" command can be used
to choose among OSCAR and/or ORCA releases, set up PhEDEx like this:
  PHEDEX/Deployment/InstallPOOL --cms /home/phedex/tools

If CMS software is not available on the node where you will run the
agents, or you don't want to use it for any other reason, make a local
standalone installation like this:
  PHEDEX/Deployment/InstallPOOL --standalone /home/phedex/tools

The script automatically detects whether you run on RedHat 7.x or
Scientic Linux 3.x and sets things up appropriately.

*** ORACLE client libraries

You need to install Oracle client: the libraries and "sqlplus" utility.
CERN license covers CMS use LCG-wide.  For the sake of simplicity we
suggest you download Oracle Instant Client kits and set them up using
a script provided in PhEDEX, even if you already have a local Oracle
installation.

To install everything required, go to http://otn.oracle.com, select
"DOWNLOAD", select "Oracle Instant Client", select "Instant client for
Linux x86", read and agree to the license if you can, and select each
of the three zips listed below.  The zip links to a page that will sign
into OTN; create yourself an account if you don't have one yet.  Save
the zips to some directory TMP (does not have to be a new one, e.g.
"/tmp" will do).  Then:
  PHEDEX/Deployment/InstallOracleClient TMP /home/phedex/tools

The zips you should download are:
  instantclient-basic-linux32-10.1.0.3.zip
  instantclient-sqlplus-linux32-10.1.0.3.zip
  instantclient-sdk-linux32-10.1.0.3.zip

You can delete the zips you downloaded after you've ran the script.

*** Perl modules

You need certain perl modules to use PhEDEx.  Many of these may be
installed on your system, but quite probably are versions with bugs
that really need to be corrected.  We recommend you simply install
all modules with the following command; it requires you already
installed the Instant Client kits as explained above:
   PHEDEX/Deployment/InstallPerlModules /home/phedex/tools

*** Transfer utilities

Finally install the software for the transfer tools you will use.
For most sites this is either globus-url-copy or srmcp.  You will
probably need to install also myproxy-related packages.  You need
to arrange the relevant setup scripts to run; normally this would
be done automatically for all users via /etc/profile.d/UI.sh or
alike.

We provide no instructions on how to install this component; we
do not even know which packages you need to install.  Try making
"UI" installation or whatever corresponds to that in your grid.

Ensure the following commands exist and work:
  Either:
    globus-url-copy
    edg-gridftp-ls     (optional)
    edg-gridftp-mkdir  (optional)
  or:
    srmcp

  grid-proxy-init
  grid-proxy-info
  myproxy-init
  myproxy-get-delegation

*** Configuring environment

The Deployment/Install* tools leave behind "env.sh" scripts you use
to prepare your environment.  You will invoke them from your site
"Config" as explained below.  If you used the commands listed
above, you would:
   source /home/phedex/tools/poolenv.sh
   source /home/phedex/tools/oraenv.sh
   source /home/phedex/tools/perlenv.sh

You should verify the following environment variables are set correctly:

  PATH
  LD_LIBRARY_PATH
  PERL5LIB
  MYPROXY_SERVER
  X509_USER_CERT
  X509_USER_KEY
  X509_USER_PROXY
  ORACLE_HOME

**********************************************************************
** Installing services

*** File catalogue

You need a POOL file catalogue for your site.  The same catalogue
should be shared for EVD files (and only EVD files) for both PubDB
if you have one, and PhEDEx.  It should be RDBMS-based, MySQL or
ORACLE, not EDG RLS, XML or EGEE catalogue.

The file catalogue does not need to be accessible from outside your
site.  Only programs from within your own site will ever access the
catalogue.  Do note that PhEDEx may under certain circumstances hit
your file catalogue *very hard*.

You need to create a database and at least one database account for
the catalogue.  To set up a MySQL catalogue on host "cathost":

 1) Create user phedex (password: phedex), and database phedexcat
 2) Load the schema and seed data from PHEDEX/Schema/FC-MySQL.sql

*** Certificate management

To run the transfer agents, you need to have a grid certficate and
be registered to the CMS VO.  All transfers will take place using
your own personal certificate.  However if you like to, you can
obtain a service certificate and use that to renew a personal
proxy certificate.

If there will be only one person administering the agents at your
site, it's simplest to use your personal certificate.  We recommend
following these conventions (X509_USER_PROXY is /home/phedex/
gridcert/proxy.cert):

  1) Once a month, load a proxy certificate to myproxy service
        grid-proxy-init
        myproxy-init -c 720

  2) Extract the proxy into the certificate directory
        cp /tmp/x509up_u$(id -u) $X509_USER_PROXY

  3) Make sure the $X509_USER_PROXY is set in the environment
     when you start transfer agents.  Make sure $X509_USER_KEY
     and $X509_USER_CERT are *not* set.

  4) Periodically (e.g. every four hours in cron job) update the proxy:
        myproxy-get-delegation -a $X509_USER_PROXY -o $X509_USER_PROXY

For using a service certificate the instructions are similar, but
slightly more complicated because the certificates must be properly
protected.  First of all, you need to obtain a service certificate,
e.g. for "phedex/agenthost.your.site.edu".   Then obtain a unix
group with all service administrators as members.  Change directory
/home/phedex/gridcert to this group and make it group-writeable.
Copy the service "hostcert.pem" and "hostkey.pem" certificate files
into this directory.

Then the administrator starting the service should:

  1) Once a week, load a proxy certificate to myproxy service
        grid-proxy-init
        myproxy-init -l phedex -R "phedex/agenthost.your.site.edu" -c 720

  2) As yourself, extract the proxy into the certificate directory
        cp /tmp/x509up_u$(id -u) /home/phedex/gridcert/proxy.cert.$(id -u)
        chmod g+r /home/phedex/gridcert/proxy.cert.$(id -u)

The "phedex" admin account should:

  3) Copy the certificate
       cp /home/phedex/gridcert/proxy.cert.* /home/phedex/gridcert/proxy.cert
       rm /home/phedex/gridcert/proxy.cert.*

  4) For transfers agents make sure $X509_USER_CERT and $X509_USER_KEY
     are *not* set, and $X509_USER_PROXY is set to /home/phedex/gridcert
     /proxy.cert.

  5) Periodically, say hourly, refresh the proxy; this time make sure
     $X509_USER_CERT and $X509_USER_KEY are set to the host certificate:
       myproxy-get-delegation -l phedex -a $X509_USER_PROXY -o $X509_USER_PROXY

     See ProxyRenew and AFSCrontab in Custom/CERN for details.

**********************************************************************
** Configuration

*** Testing your installation

Verify that everything installed so far works correctly:
   PHEDEX/Deployment/TestInstallation -db devdb -dbuser cms_transfermgmt \
     -dbpass <password> -poolcat <catalogue>

*** Registering your node to the topology

To be able to transfer any files in our out, your site must become
part of the CMS transfer topology.  Please send an e-mail to
   cms-phedex-developers@cern.ch

In your mail, please include the following information -- or ask
for suggestions giving as many details as you can:

  1) Type of your site (Tier-1, Tier-2, Tier-3)

  2) Where you would be preferred to be attached; for Tier-N
     where N > 1, you should be attached to a Tier above you.
     If there is no Tier-1 that can serve you right now, we
     may exceptionally let you attach to CERN, but this will
     be granted only on temporary basis.

  3) The topology you plan to have at your site: disk buffers, MSS etc.

  4) The name(s) by which you would like your node(s) to be known.
     The names are a descriptive name for your site (e.g. INFN),
     plus underscore, plus node type (Transfer / MSS / ...)

  5) Catalogue contact for your site and unique match key on PFNS
     for your site (unnecessary with V2.1).

*** Setting up agent master scripts

You should create a directory "Custom/FOO" for your site "FOO"
in the "PHEDEX" checkout area.  Then create site configuration
file; you can use Custom/CERN/Config as a guide.  Typically you
will have an environment section followed by agent sections.
The environment section applies to all agents and should include
everything that it takes for them to run at your site.

To import data, you must run at least the following agents:
  1) FileDownload
  2) FileRouter
  3) NodeRouter
  4) InfoDropStatus

We also recommend that you run "PeerLogAccess".

If you have a separate MSS node, you must also run some kind
of MSS migration agent.  You may be able to use some of the
existing agents (FileCastorMigrate, FileDownload with DCCP
backend, ...), or you'll have to write your own.  Depending
on your setup you may also want to run a cleaner agent (see
FileDiskCleaner, FileFakeCleaner).

To export data from your site for others to download, you
need a separate set of agents.  This is described in more
detail in README-Export.txt.

*** Writing site glue scripts

You also need site-specific scripts to communicate between
your site (e.g. your file catalogue) and the agents.  You
can use the scripts from Custom/CERN as examples.  There
are more details about these in README-Transfer.txt.
  1) FileDownload wants the following:
     1.1) FileDownloadDest for download destination PFN.
     1.2) FileDownloadVerify to validate downloaded file.
     1.3) FileDownloadDelete to clean up failed downloads.
     1.4) FileDownloadPublish to import downloaded files
          to your site-local catalogue.

  2) Various agents will want to invoke a script to look up
     files either by GUID or PFN.  Use Custom/CERN/PFNLookup
     as an example.

  3) You'll probably want to archive all your logs to a
     safe place.  See AFSCrontab and LogArchive in
     Custom/CERN.

**********************************************************************
** Support

If you have any questions or comments, please contact the developers
at <cms-phedex-developers@cern.ch> and/or check out the documentation
at http://cern.ch/cms-project-phedex.  You are welcome to file bug
reports and support requests at our Savannah site at
  http://savannah.cern.ch/projects/phedex
