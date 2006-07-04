* Setting up for using PhEDEx

This document describes how to set up a site for CMS data transfers.
The intended audience are site data managers that need to import or
export CMS data.

** Related documents

README-Overview.txt explains where this document fits in.
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
  SW.1) PhEDEx RPMs

  Services:
  SV.1) A site-local file (trivial) catalogue
  SV.2) Certificate management

  Configuration:
  CF.1) Get registered to the transfer topology
  CF.2) Site-specific scripts

** Getting the hardware

To act as a transfer node in the PhEDEx network, you obvioulsy need a
storage system.  This can be either local or mounted disks, a managed
pool (Castor, dCache, ...), and may or may not be backed up by a tape
mass storage system.  CMS requires SRM storage.

It is important that you have high-speed network connection to your
disk pool.  It is advisable there to be a gridftp network access path
that bypasses firewalls.

You will also need a computer on which you will run the agents.  This
needs to be either SL3/IA32 system, though with a little creativity
other platforms can be supported as well.  You must have access to
local or mounted disk space on the machine; AFS will not do.  You do
not need large amounts of memory, disk space, network bandwidth or CPU
capacity on this machine.  You do need to have all the prerequisite
software installed on this machine.

**********************************************************************
** Getting the software

This document assumes you will install the software on "agenthost"
in directory "/home/phedex".  We assume the PhEDEx node name for
your site is "TX_FOO_Buffer" (and possibly "TX_FOO_MSS").

*** Set up directories

  cd /home/phedex
  mkdir -p state logs sw gridcert
  chmod 700 gridcert
  sw=$PWD/sw

*** Install the software

  wget -O $sw/aptinstaller.sh \
    http://cmsdoc.cern.ch/cms/cpt/Software/download/lt4/aptinstaller.sh
  chmod +x $sw/aptinstaller.sh
  
  $sw/aptinstaller.sh -path $sw setup
  eval `$sw/aptinstaller.sh -path $sw config -sh`
  apt-get update
  apt-get install cms+PHEDEX+PHEDEX_2_3_10
  rm -f PHEDEX; ln -s $sw/slc3_ia32_gcc323/cms/PHEDEX/PHEDEX_2_3_10 PHEDEX

*** Get site configuration

  cd /home/phedex
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
  cvs login # password is "98passwd"
  cvs co SITECONF/CERN
  cvs co SITECONF/FOO

*** Post-installation verification

The RPMs include environment setup scripts you should use to prepare
your environment.  You will invoke the scripts from your site "Config"
as will be explained below.  If you used the commands above, use:
  source $sw/slc3_ia32_gcc323/cms/PHEDEX/PHEDEX_2_3_10/etc/profile.d/env.sh

You should verify the following environment variables are set correctly:

  PATH
  LD_LIBRARY_PATH
  PERL5LIB
  MYPROXY_SERVER
  X509_USER_CERT
  X509_USER_KEY
  X509_USER_PROXY
  ORACLE_HOME

Ensure the following commands exist and work:

  srmcp
  grid-proxy-init
  grid-proxy-info
  myproxy-init
  myproxy-get-delegation

Of these, only srmcp comes with the RPMs.  The rest you need to make
available by installing appropriate grid middleware on the host.  For
LCG, this means installing the "UI" (user interface) environment.
  
**********************************************************************
** Installing services

*** Certificate management

To run the transfer agents, you need to have a grid certficate and be
registered to the CMS VO, including in VORMS.  All transfers will take
place using your own personal certificate.

We recommend obtaining a service or host certificate, loading a
long-lived personal proxy into myproxy, then using the service
certificate to renew a short-lived proxy which is then used by the
transfers.  This is not easy to get right, mainly because myproxy
generally gives useless error messages if anything happens to go
wrong, but it does reduce operational burden considerably.

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
e.g. for "phedex/agenthost.your.site.edu".  Then obtain a unix group
with all service administrators as members.  Change directory
/home/phedex/gridcert to this group and make it group-writeable.  Copy
the service "hostcert.pem" and "hostkey.pem" certificate files into
this directory.

Then the administrator starting the service should:

  1) Once a week, load a proxy certificate to myproxy service
        grid-proxy-init
        myproxy-init -l phedex -R "phedex/agenthost.your.site.edu" -c 720

  2) As yourself, extract the proxy into the certificate directory
        mv /tmp/x509up_u$(id -u) /home/phedex/gridcert/
        chmod 660 /home/phedex/gridcert/x509*

The "phedex" admin account should run something like
SITECONF/CERN/PhEDEx/ProxyRenew once an hour as a cron job.

**********************************************************************
** Configuration

*** Registering your node to the topology

To be able to transfer any files in our out, your site must become
part of the CMS transfer topology.  Please send an e-mail to
   cms-phedex-admins@cern.ch

In your mail, please include the following information -- or ask
for suggestions giving as many details as you can:

  1) Type of your site (Tier-1, Tier-2, Tier-3)

  2) Where you would be preferred to be attached; for Tier-N where
     N>1, you should be attached to a Tier above you.  If there is no
     Tier-1 that can serve you right now, we may exceptionally let you
     attach to CERN, but this will be granted only on temporary basis.
     Note that the tier attachment is something you need to negotiate
     yourself, PhEDEx just records the CMS policy.

  3) The kind of storage you have: disk buffers, MSS, etc.

  4) The name of your site.  PhEDEx uses node names that are a
     combination of site name and type of storage node, such as
     "T1_FNAL_Buffer", "T2_DESY_MSS", "T2_Spain_Buffer".  The site
     name is usually institution name, or a geographical name as in
     T2_Spain (a federated pseudo-site).

*** Setting up agent configuration

CMS encourages all sites to keep the configurations of their CMS
services in the SITECONF area in the CVS repository (CMSSW CVS
repository, COMP/SITECONF).  If you do not have a SITECONF directory
for your site, please request one from cms-phedex-admins@cern.ch.

PhEDEx uses a simple text configuration file that describes the agents
that should run for your site.  The purpose of the configuration file
is to make the agent management easy, and to capture a self-contained
environment including everything required to run the agents.  The file
typically begins with an environment section, followed by agents to
run.  It is possible to split the configuration file into multiple
parts.  This allows you to share large portions of the configuration
across multiple PhEDEx instances: tests, production, and so on.

For downloads, run "FileDownload" and "InfoDropStatus".  In an
integration challenge environment, you may need to add "FileRecycler";
you would never run that agent in a production environment.

If you have a MSS node, you must run a MSS migration agent.  Migration
agents exist for Castor and dCache (File{Castor,DCache}Migrate).  If
your disk and tape storages are separate, you can use FileDownload
with a suitable backend to copy between storage systems.  You should
also run a cleaner agent for the buffer node, FileFakeCleaner for a
shared disk/tape storage node, and FileDiskCleaner for a separate disk
buffer backed up by a tape node.

Exporting data to other sites requires export agents, which are
described in more detail in README-Export.txt.

*** Writing site glue scripts

More details about the site glue scripts are in README-Transfer.txt.
You would normally have:

  1) FileDownload:
     1.1) FileDownloadVerify to validate downloaded file.
     1.2) FileDownloadDelete to clean up failed downloads.

  2) Archive all your logs to a safe place.  See AFSCrontab and
     LogArchive in SITECONF/CERN/PhEDEx.

  3) Renew your proxy.  See ProxyRenew in SITECONF/CERN/PhEDEx.

**********************************************************************
** Support

Please contact <hn-cms-phedex@cern.ch> for support and/or check out
the documentation at http://cern.ch/cms-project-phedex.  Please file
bugs and feature requests at http://savannah.cern.ch/projects/phedex.
