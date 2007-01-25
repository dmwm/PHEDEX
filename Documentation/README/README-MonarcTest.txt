Here you can find the information how you can make MonarcTest samples
at your site, and start the MonarcTest drop-box and file injector.

MonarcTest file creation:

In PHEDEX/Utilities there is a script MonarcFileCreator.    

You should start it from somewhere you can submit batch jobs.

This script creates a jobs/ directory and stores all job files in it. 
Also creates SubmitAllJobs.sh file which is used to submit all job
files to batch system. Each job file creates file around 2.5 GB, 
calculates it's cksum and retrieves it's file size and copies the 
file to storage system.

File creation is done in two steps. First there is a creation of a 
seed (23KB) file filled with random characters. Seed file is then 
automaticaly copied copied to batch machine from fs area along with 
the CreateFile script (created with this script). CreateFile script 
creates the resulting ~ 2.5 GB file which is then copied to storage 
sysetem and removed from batch machine.

When you have you initial dataset, you should start the start the 
drop-box agents and the MonarcFileInjector (as a cron job).
The example configuration for a Monarc drop-box agents is in 
SITECONF/CERN/PhEDEx/Config.Monarc. Before you start this agent, 
you should also modify the local file catalog. 
In SITECONF/CERN/PhEDEx/storage.xml there is a part of which is 
specfic to MonarcTest. You should take that part and change the
CERN name in to the name of you site.   
The example SITECONF/CERN/PhEDEx/MonarcFileInjector script creates 
the LFN's and drops them to Monarc drop-box.
This way, there could be created the infinite number of files 
divided in 20 streams (datasets) and grouped in a 100 file blocks.
What was left is to subscribe this dataset to other sites.

