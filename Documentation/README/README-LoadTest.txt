Instructions on how to use the LoadTest07 sample creator.  Scripts are
found in PHEDEX/Toolkit/LoadTest/

The main tool here is the CreateFile script which explains itself hopefully well 
enough when executed without arguments. It creates basically a single file of the 
sample and the relevant info files for injection. There are other tools present 
to help in automating the process of full sample creation as well as merging the 
output injection files into a single file. 

There are a number of copy scripts which are used in different environments to 
stage the created file out to storage. I have provided two scripts: cp.sh and 
srm.sh. The first one is just a basic cp of the file from local dir to the 
target directory and should serve as a template on what people can base their 
copy script based on their storage. Basically changing the command used from 
cp to say rfcp and supplying the relevant arguments should be enough to make 
it work. srm.sh is a script which will perform the srmcp command with debug 
enabled and with 3 retries. If you need any extra options, feel free to 
update the script. In any case you need to update the srm basename to where
you want to copy the files.

Now to actually create the full sample of 256 files you have three options:

1. Create locally all in one go.

 To do that you can use the create_locally.sh which will take about 21 - 24
hours based on your local machine performance. It basically creates the files
in sequence, hence the delay. Also modify the script to suit your copy script
as it currently uses srm.sh.

2. Over Grid using a WMS and parametric job

 The supplied template jdl is present in the file create_parallel.jdl. Modify
it again according to your need. Basically all you need to change is the
Arguments to match the sample filename and the matching process to match to
you local compute element. It uses srm.sh as the stageout so please fix the
srm basename in srm.sh as well.

3. In local batch system

To be done :) Volunteers welcome. 

In the end you will need to merge the injection files to one and for that I
have provided the merge_injection_files.sh script. It searches in the current
folder and subfolder for the relevant files and merges them together to
LoadTest07_files_info file. As it uses subdirs as well, then the output
directory of the parametric job will do just fine as long as it's in the
current working directory.

Once you have done all of the above, you have the sample in your storage and
the file needed for injection. Now all you have to do is send the information
with the injection data and your LFN for the LT07 sample files to
cms-phedex-admins@cern.ch for central injection.

If you have any more questions, just ask: mario.kadastik@cern.ch
