Readme for T0 fake data creator and PhEDEx feeder
-------------------------------------------------

The purpose of these agents are to provide easy means to create large
data samples using the T0 StorageManager and then inject those samples
into PhEDEx using the T0 FeedExporter. Both components were modified
such that they can run independently from the T0 software area.

  The StorageManager
  Config file: Config/FillExportBuffer.conf

  This agent starts a server process on a machine to be defined in the
  config file and using a port also defined there. It will steer the
  creation speed of files by throttling the worker processes. The
  speed can be adjusted in the configuration file and defaults to
  300MB/s. In order to achieve a sufficiently high speed, multiple
  worker processes submitted to the LSF batch system are
  necessary. This can be done using the submitWorkerJobs.sh script.

  - StorageManagerWorker
  Config file: Config/FillExportBuffer.conf

  This agent is doing the actual work by creating the files requested
  using small file fragments to be found in the file list
  'Config/filelist'. Currently Tony's file fragments for the T0
  exercise are used for that. The workers are typically started using
  the 'submitWorkerJobs.sh' script and submitted to LSF.

  - FeedExporter
  Config file: Config/ExportFeeder.conf

  The purpose of this agent is to scan a directory structure on Castor
  and create the XML drops needed for PhEDEx injection.


How to deploy the scripts:
1. CVS checkout 'PHEDEX/Testbed/T0FeedTest'

2. Get the POE (Perl object environment) modules from 'http://poe.perl.org'

3. extract the tar ball somewhere and copy the content of
   <POE-Base>/lib to the Perl-libs directory:
   cp -r <POE-Base>/lib/* Perl-libs/

Please make sure, that you deploy the scripts somewhere on AFS or any
other area, which can be accessed directly from the worker
nodes. Otherwise you won't be able to run the StorageManager workers
using a batch system. You can still directly start individual workers
using the 'run_StorageManagerWorker.sh' script. But in order to obtain
a decent performance you are strongly advised to submit the worker
jobs using a batch system.


In order to run those agents the following procedure should be
followed:

1. Edit Config/env.sh and adjust the path to the basedir and the
PhEDEx drop box location

2. Edit the corresponding config files for the agents in Config

3. Source the environment: source Config/env.sh

4. Start the StorageMaster: ./run_StorageManager.sh

5. Start 'N' StorageManager workers using LSF (you might need to adjust
   the queue in the script): ./submitWorkerJobs.sh <N>

6. Run the ExportFeeder if you want to create the drops for
   PhEDEx. They are automatically put in the mouth of the injection
   drop-box agent, which needs to be defined in 'Config/env.sh'.

