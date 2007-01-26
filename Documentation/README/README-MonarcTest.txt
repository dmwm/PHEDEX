Monarc Test's goal is to have a possibility of transfer of infinite 
number of files (blocks) to some site using small set of initially 
created files.


This document describes how you can make MonarcTest samples at
your site, and start the MonarcTest drop-box and file injector.


MonarcTest file creation:

In PHEDEX/Utilities there is a script MonarcFileCreator.    
You should start it from somewhere from where you can submit batch
or grid jobs (an NFS or AFS mounted area or a UI machine).
This script creates a 'jobs/' directory and stores all job files in
it.  It also creates a SubmitAllJobs.sh file which is used to submit
all job files to the batch system. Each job file creates a file of
approximately 2.5 GB size, calculates it's cksum, retrieves it's file
size and copies the file to the storage system.
File creation is done in two steps. First there is a creation of a
seed (23KB) file filled with random characters. The seed file is then
automaticaly copied or defined in InputSandbox to the batch machine 
from an NFS or AFS mounted area along with the CreateFile script 
(created with this script). CreateFile script creates the resulting 
~ 2.5 GB file which is then copied to storage sysetem and removed 
from the batch machine.


Starting of Monarc drop-box agents and a file injector
 
When you have your initial dataset, you should start the
drop-box agents and the MonarcFileInjector (as a cron job). The
example configuration for a Monarc drop-box agents is in
SITECONF/CERN/PhEDEx/Config.Monarc. Before you start this agent, you
should also modify the local file catalog. In
SITECONF/CERN/PhEDEx/storage.xml there is a part, which is specfic
to MonarcTest. You should take that part and change the CERN name in
to the name of your site. The example
SITECONF/CERN/PhEDEx/MonarcFileInjector script creates the LFN's and
drops them to Monarc drop-box.
This way you could create an infinite number of files divided in 20
streams (datasets) and grouped in 100 file blocks. What is left, is
the subscription of this dataset to other sites.

