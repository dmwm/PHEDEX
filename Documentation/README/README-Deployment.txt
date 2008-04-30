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
needs to be either SL3/IA32 or SL4/IA32 system.  You need access to
local or mounted disk space on the machine; AFS will not do.  You do
not need large amounts of memory, disk space, network bandwidth or CPU
capacity on this machine.  You do need to have all the prerequisite
software installed on this machine.

Yuo can also try to request a formal VO box for CMS at your site. It
will  be configured as a LCG UI plus VO box specific services: gsissh
and proxy-renewal.  Please read README-VOBOX.txt for more details.

** Installing the software

In this manual, we will make the following assumptions:

    * PhEDEx is installed on agenthost.site.edu.
    * The phedex user is "phedex".
    * The site name is TX_FOO_Buffer. 

Before installing the software, you should create a few empty directories:

  cd /home/phedex
  mkdir -p state logs sw gridcert
  chmod 700 gridcert
  export sw=$PWD/sw

The state directory is where agents keep their working states; logs is
where logs are kept for each agent; sw is the software install
directory; and gridcert is where you should keep your grid proxies.

Software installation is done through the CMS aptinstaller program.
[https://twiki.cern.ch/twiki/bin/view/CMS/CMSSW_aptinstaller]

First set a variable for the version of PhEDEx you are going to install:

  version=3_0_1

Next set a variable for your architecture. If you are on a 32-bit, RHEL-3 derivate:

  myarch=slc3_ia32_gcc323

If you are on a 32-bit, RHEL-4 derivate:

  myarch=slc4_ia32_gcc345

If you are using a 64-bit operating system, you may want to try
substituting ia32 with the string amd64. (See notes below)

  myarch=slc4_amd64_gcc345

Now install the software with the following commands:

  wget -O $sw/bootstrap-${myarch}.sh http://cmsrep.cern.ch/cmssw/bootstrap-${myarch}.sh
  sh -x $sw/bootstrap-${myarch}.sh setup -path $sw
  source $sw/$myarch/external/apt/0.5.15lorg3.2-CMS3/etc/profile.d/init.sh
  apt-get update
  apt-get install cms+PHEDEX+PHEDEX_$version
  rm -f PHEDEX; ln -s $sw/$myarch/cms/PHEDEX/PHEDEX_$version PHEDEX

** Software Install Notes

Here are some things to note about the software install:

    * Whole process should take around 30 minutes.
    * There have been previously reported problems with apt-get and
      64-bit machines. You might have the best luck with a 32-bit
      operating system as of now.
    * Make sure that the bit-endness of your system perl is the same
      as your PhEDEx install. Make sure the 32-bit PhEDEx finds a
      32-bit perl install by default, not a 64-bit perl.
    * If you are trying to install 32-bit PhEDEx on a 64-bit system,
      there have been problems reported using the 64-bit version of
      apt-get. If apt-get claims cms+PHEDEX+PHEDEX_${version} cannot be
      found, try uninstalling the 64-bit apt-get and replacing it with
      the 32-bit one.

*** Get site configuration

We very strongly recommend that all site configurations are kept in
the CMS CVS repository, in COMP/SITECONF.  If your site already has
a CVS module, proceed to check it as shown below.  Otherwise please
ask cms-phedex-admins@cern.ch for a SITECONF module for your site;
we recommend the site name is the same as in the node name (in our
example: FOO).  You may also check out SITECONF/CERN or other sites
for an example.  PhEDEx provides a site configuration templates in
Custom/Template.

  cd /home/phedex
  export CVSROOT=:pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/CMSSW
  cvs login # password is "98passwd"
  cvs co SITECONF/FOO

*** Post-installation verification

The RPMs include environment setup scripts you should use to prepare
your environment.  You will invoke the scripts from your site "Config"
as will be explained below.  If you used the commands above, use the
following command, but substitute "slc4_ia32_gcc345" if applicable:

  source $sw/slc3_ia32_gcc323/cms/PHEDEX/PHEDEX_3_0_0/etc/profile.d/env.sh

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
  glite-transfer-submit
  glite-sd-query

Of these, only srmcp comes with the RPMs.  The rest you need to make
available by installing appropriate grid middleware on the host.  For
LCG, this means installing the "UI" (user interface) environment.
  
**********************************************************************
** Installing services

*** Certificate management

To run the transfer agents, you need to have a grid certficate and be
registered to the CMS VO, including in VORMS.  All transfers will take
place using your own personal certificate.

(If you are in a hurry to set things up or to try things out, you may
wish to skip this section and come back to the certificate management
once you have all the rest running fine.  Just create a normal grid
proxy certificate and off you go.)

We recommend obtaining a service or host certificate, loading a
long-lived personal proxy into myproxy, then using the service
certificate to renew a short-lived proxy which is then used by the
transfers.  This is not easy to get right, mainly because myproxy
generally gives useless error messages if anything happens to go
wrong, but it does reduce operational burden considerably.

An alternative to this process is asking grid admins at your site 
to set up a VO box.  Proxy renewal will come "for free" with properly 
installed VO box.  More details in README-VOBOX.txt.  If you are not
using a VO box, then the following will help.

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
        myproxy-init -l foo_phedex -R "phedex/agenthost.your.site.edu" -c 720

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
for suggestions giving as many details as you can.

  1) Type of your site (Tier-1, Tier-2, Tier-3).  If you are a
     part of a federated site, please mention which other sites
     belong to the same federation.

  2) The kind of storage you have: disk buffers, MSS, etc.
     Please mention the kind of technology used such as "dCache"
     or "Castor" or "DPM", and whether you have tape or just disk.

  3) The name of your site.  PhEDEx uses node names that are a
     combination of site name and type of storage node, such as
     "T1_FNAL_Buffer", "T2_DESY_MSS", "T2_Spain_CIEMAT".  The site
     name is usually institution name, or a geographical name with
     institute names specifying specific federation locations as
     with T2_Spain.

  4) The grid storage element (SE) name of your storage system.

  5) The details mentioned in REAMDE-Auth.txt.

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

All nodes should run three agents: "FileDownload", "FileExport" and
"FileRemove".  Sites with a tape storage (PhEDEx MSS node) also need
to run tape migration agents such as "File{Castor,DCache}Migrate"
and a stager agent such as "File{Castor,DCache}Stager".  You can use
"FileDownload" with suitable options to copy between local storage
nodes, for example if you have separate disk and tape storage systems.

Details on exporting files to the other sites is covered separately
in README-Export.txt, and download side in README-Transfer.txt.  The
central agents take care of the rest, including synchronisation with
DBS and DLS.

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

Please contact <hn-cms-phedex@cern.ch> for support and check out the
documentation at http://cmsdoc.cern.ch/cms/aprom/phedex.  Please file
bugs and feature requests at http://savannah.cern.ch/projects/phedex.
