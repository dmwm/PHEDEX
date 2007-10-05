Monarc Test's goal is to have a possibility of transfer of infinite 
number of files (blocks) to some site using sample of initially 
created files.

This document describes how you can make MonarcTest samples at
your site, and start the MonarcTest drop-box and file injector.


MonarcTest sample creation

MonarcTest sample is a 256 file sample. Each file size is ~ 2.5GB. 
In PHEDEX/Utilities there is a script 'MonarcFileCreator'.    
You should start it from somewhere from where you can submit batch
or grid jobs (an NFS or AFS mounted area or a UI machine).
This script creates a 'jobs/' directory and stores all (256) job files 
in it. It also creates a 'SubmitAllJobs.sh' file which is used to submit
all job files to the batch system. Each job file creates one file of
approximately 2.5 GB size, calculates it's cksum, retrieves it's file
size and copies the file to the storage system.
File creation is done in two steps. First there is a creation of a
seed (23KB) file, filled with random characters. The seed file is then
automatically copied (or defined in InputSandbox) to the batch machine 
from an NFS or AFS mounted area along with the CreateFile script 
(which is created with 'MonarcFileCreator' script). 'CreateFile' script 
creates the resulting ~ 2.5 GB file which is then copied to storage 
system and removed from the batch machine.


Starting of Monarc drop-box agents and a file injector
 
When you have created your initial data sample, you should start the
drop-box agents and the MonarcFileInjector (i.e. as a cron job). 
If you are not running the 'drop-publish' agent at your site you 
could use Monarc drop-box. The example configuration for a Monarc 
drop-box agent is in SITECONF/CERN/PhEDEx/Config.Monarc. 
Before you start the drop-box agent, you should also modify the 
local file catalog. In SITECONF/CERN/PhEDEx/storage.xml there is a part, 
which is specfic to MonarcTest. You should take that part and change 
the name of the site and a result path. I.e. to the storage.xml add:

  <!-- Specific for Monarc test  -->
  <lfn-to-pfn protocol="direct"
    path-match=".*/MonarcTest_SITE_(.*)_.*_.*"
    result="/some/your/path/phedex_monarctest/MonarcTest_SITE_$1"/>

The example SITECONF/CERN/PhEDEx/MonarcFileInjector script creates 
the LFN's and drops them into the drop-box.
This way you could create an infinite number of files divided in 20
streams (datasets) and grouped in 100 file closed blocks. 
What's left, is the subscription of these datasets to other sites.

