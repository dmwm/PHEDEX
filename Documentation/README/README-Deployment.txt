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

  mkdir -p /home/phedex
  mkdir -p /home/phedex/{state,logs}
  mkdir -p /home/phedex/gridcert
  mkdir -p /home/phedex/tools/perl

  chmod 700 /home/phedex/gridcert

*** PhEDEx

  cd /home/phedex
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
  cvs login # password is "98passwd"
  cvs co PHEDEX

*** LCG POOL tools

Install POOL somewhere on your system, e.g. in /home/phedex/tools/POOL.
You need version 1.6.2 or later.  We recommend installing with xcmsi.
(NB: POOL 1.8.x versions have serious bugs in the file catalogue
python implementation; we recommend using version 1.6.4 for now.)

*** ORACLE client libraries

You need to install Oracle client libraries.  A license at CERN covers
all CMS use (in fact, LCG-wide).  See the following links for further
information.  We recommend using a single Oracle version: use the same
Oracle as used by your version of POOL.

See:
  - License agreement
     http://cern.ch/wwwdb/oracle/oracle-license-agreement.html
  - Server deployment statement
     http://cern.ch/wwwdb/oracle/oracle-server-deployment.html
  - Description of how and what to install for 10g.
     https://savannah.cern.ch/projects/lcg-orat1/
  - File download
     https://savannah.cern.ch/files/?group=lcg-orat1

*** Perl modules

You need DBI and DBD::Oracle modules.  DBD::Oracle versions older
than 1.16 have significant memory leaks; we recommend you install
DBI 1.46 and DBD::Oracle 1.16 unless your system already has these
installed.  We also recommend installing DBD::mysql if you will be
installing a local MySQL catalogue.

We installed everything something like this:

   BASE=/home/phedex/tools
   mkdir -p $BASE/perl/src
   eval `cd $BASE/POOL/POOL_1_6_2/src; scram -arch rh73_gcc32 runtime -sh`

   cd $BASE/src
   wget http://search.cpan.org/CPAN/authors/id/R/RU/RUDY/DBD-mysql-2.9004.tar.gz
   wget http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBD-Oracle-1.16.tar.gz
   wget http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBI-1.46.tar.gz
   wget http://search.cpan.org/CPAN/authors/id/P/PE/PETDANCE/Test-Harness-2.42.tar.gz
   wget http://search.cpan.org/CPAN/authors/id/M/MS/MSCHWERN/Test-Simple-0.51.tar.gz

   for x in Test-Harness-2.42 Test-Simple-0.51 DBI-1.46 DBD-Oracle-1.16 DBD-mysql-2.9004; do
     tar zxf $x.tar.gz
     cd $x
     perl -I$BASE/perl/lib/perl5/site_perl/5.6.1/i386-linux Makefile.PL prefix=$BASE/perl
     make; make install
     cd ..
   done

*** Transfer utilities

Finally you will need to install the software for the transfer tools
you will use.  For most sites this is either globus-url-copy or srmcp.
You will probably need to install also myproxy-related packages.  You
need to arrange the relevant setup scripts to run; normally this would
be done automatically for all users via /etc/profile.d/UI.sh or alike.

Ensure the following commands exist and work:
  globus-url-copy
  edg-gridftp-ls
  edg-gridftp-mkdir
  grid-proxy-init
  grid-proxy-info
  myproxy-init
  myproxy-get-delegation
  [srmcp]


*** Configuring environment

Make sure various environment variables are correctly set for all the
above tools:

  PATH
  LD_LIBRARY_PATH
  PERL5LIB
  MYPROXY_SERVER
  X509_USER_CERT
  X509_USER_KEY
  X509_USER_PROXY


**********************************************************************
** Installing services

*** File catalogue

You need a POOL file catalogue for your site.  The same catalogue
should be shared for EVD files (and only EVD files) for both PubDB
if you have one, and PhEDEx.  It should be RDBMS-based, MySQL or
ORACLE, not EDG RLS or XML catalogue.

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

If you have a separate MSS node, you must also run some kind
of MSS migration agent.  You may be able to use some of the
existing agents (FileCastorMigrate, FileDownload with DCCP
backend, ...), or you'll have to write your own.  Depending
on your setup you may also want to run a cleaner agent (see
FileDiskCleaner).

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
