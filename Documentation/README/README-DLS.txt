* How to set up automatic DLS updating fom PhEDEx

Here we describe briefly how to install and set up the automatic DLS
update agent BlockDLSUpdate and all prerequisits.  The purpose of this
agent is to announce new file replicas transferd via PhEDEx to CMS'
data location system DLS.


* Setting up BlockDLSUpdate agent

The agent is part of the PhEDEx distribution and resides in
PHEDEX/Toolkit/Workflow. It requires the following arguments:

-db:   the database contact string, something like <ParthToDBParam>/DBParam:Dev/Writer
-node: the name of your node, e.g. T1_FNAL_Buffer
-se:   the name of your storage element, e.g. srm.cern.ch

A template configuration including this agent is available from
"PHEDEX/Custom/Template".  Have a look in particular at the files
"Config" and "ConfigPart.Common".


* Making sure, all prerequirements are met

In order to test your readiness for using DLS updates with PhEDEx,
please source the PhEDEx environment and perform the following simple
checks.  If you followed the deployment guide, the following command
will set up your environemnt:

"source /home/phedex/PHEDEX/etc/profile.d/env.[c]sh"

1. voms-proxy-init is installed on the machine hosting PhEDEx and you
   can create a proxy as CMS VOMS.
   - voms-proxy-init does exists executes fine.

   - you have a "cms" entry in $HOME/.glite/vomses.  If not, please
     create one by issuing the following command:

     <snip>
     mkdir -p $HOME/.glite/vomses echo '"cms" "lcg-voms.cern.ch"
     "15002" "/C=CH/O=CERN/OU=GRID/CN=host/lcg-voms.cern.ch" "cms"' >
     $HOME/.glite/vomses/cms-lcg-voms.cern.ch
     </snip>

   - "voms-proxy-init -voms cms" executes fine and gives you a valid
     certificate proxy

2. DLS is installed on your system and "dls-get-se -h" executes fine,
   giving you online help about the command.  DLS is installed as part
   of the PhEDEx deployment.

3. LFC client tools are installed on your system and can be used with
   DLS.  This is an external package and comes with the "Glite 3.0
   UI". In order to properly test DLS with LFC, please follow the
   instructions described on the DLS WiKi page:
   "https://twiki.cern.ch/twiki/bin/view/CMS/DLSClientInstallation"
	       
   Here you will also find instructions on how to deploy LFC, if it
   turns out to be missing on your host.

