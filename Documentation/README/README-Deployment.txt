* Setting up for using PhEDEx

This document describes how to set up your site for CMS data movement.
The intended audience are site data managers that need to import or
export CMS data.

** Related documents

README-Overview.txt explains where this document fits in.
README-Operations.txt explains how things are done at CERN.
README-Transfer.txt explains how to set up transfer agents.

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
  mkdir -p /home/phedex/FOO/{state,logs}
  mkdir -p /home/phedex/certficates
  mkdir -p /home/phedex/tools/perl

  chmod 700 /home/phedex/certificates

*** PhEDEx

  cd /home/phedex
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/PHEDEX
  cvs login # password is "98passwd"
  cvs co PHEDEX

*** LCG POOL tools

Install POOL somewhere on your system, e.g. in /home/phedex/tools/POOL.
You need version 1.6.2 or later.  We recommend installing with xcmsi.

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


**********************************************************************
** Installing services

*** File catalogue

You need a POOL file catalogue for your site.  The same catalogue
should be shared for EVD files (and only EVD files) for both PubDB
if you have one, and PhEDEx.  It should be RDBMS-based, MySQL or
ORACLE, not EDG RLS or XML catalogue.

The file catalogue does not need to be accessible from outside your
site.  Only programs from within your own site will ever access the
catalogue.

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
certificates/proxy.cert):

  1) Once a week, load a proxy certificate to myproxy service
        grid-proxy-init
	myproxy-init

  2) Extract the proxy into the certificate directory
	cp /tmp/x509up_u$(id -u) $X509_USER_PROXY

  3) Make sure the $X509_USER_PROXY is set in the environment
     when you start transfer agents.

  4) Periodically (e.g. every four hours in cron job) update the proxy:
        myproxy-get-delegation -a $X509_USER_PROXY -o $X509_USER_PROXY

For using a service certificate the instructions are similar, but
slightly more complicated because the certificates must be properly
protected.  First of all, you need to obtain a service certificate,
e.g. for "phedex/agenthost.your.site.edu".   Then obtain a unix
group, and make all service administrators members of this group.
Make /home/phedex/certificates owned by this group, and make the
directory group-writeable.  Copy the "hostcert.pem" and "hostkey.pem"
certificate files into this directory.

Then the administrator starting the service should:

  1) Once a week, load a proxy certificate to myproxy service
        grid-proxy-init
	myproxy-init -l phedex -R "phedex/agenthost.your.site.edu"

  2) As yourself, extract the proxy into the certificate directory
	cp /tmp/x509up_u$(id -u) $X509_USER_PROXY.$(id -u)
	chmod g+r $X509_USER_PROXY.$(id -u)

The "phedex" admin account should:

  3) As the "phedex" admin account, copy the certificate
       cp $X509_USER_PROXY.* $X509_USER_PROXY
       rm $X509_USER_PROXY.*

  4) Make sure $X509_USER_CERT and _KEY are set to /home/phedex/
     certificates/hostcert.pem and hostkey.pem, respectively.
     Make sure $X509_USER_PROXY is set to /home/phedex/certificates/
     proxy.cert.  These must be set before starting transfer agents.

  6) Periodically (e.g. every four hours in cron job) update the proxy:
       myproxy-get-delegation -l phedex -a $X509_USER_PROXY -o $X509_USER_PROXY

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
in the "PHEDEX" checkout area.  You can use the environment
setup and agent control scripts from CERN or other sites as
an example.  Typically you'll create Environ.sh, Start.sh
and Stop.sh.  Into the first file you put everything that
you need to prepare for running the agents at your site.

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

To export data you must run in addition some set of export
agents.  If you are exporting files from disk, you may get
away with just running FileDiskExport.  If you are exporting
directly from Castor, you may be able to reuse FileMSSPublish,
FileCastorExport, FileCastorStager.  If you have separate
import/export buffer, you will most likely have to come up
with something a little more sophisticated.

Soon with V2.1 for data export you will also need to run an
agent to generate transfer names (TURLs) for files.  If you
have a single local catalogue for all files, you can simply
run FilePFNExport with suitable site script argument.

*** Writing site glue scripts

You will need glue scripts for linking the agents and your
site.  At present for imports you need to write a script to
generate file names for downloaded files.  See FileDownloadDest
scripts in various Custom/* directories.

Soon with V2.1 you will also need to provide scripts to
wrap access to your site catalogue.  The idea is that your
catalogue should store file names as they will be accessed
by the analysis jobs.  You then write a couple of scripts
to generate a transfer name (usually sticking "gridftp://
somehost.your.site.edu/" prefix to the PFN), and the other
way around to import catalogue data for a file after import.
See README-Transfer.txt and Custom/* scripts for further
details.

**********************************************************************
** Support

If you have any questions or comments, please contact the developers
at <cms-phedex-developers@cern.ch>.  You are welcome to file bug reports
and support requests at our Savannah site at
  http://savannah.cern.ch/projects/phedex
