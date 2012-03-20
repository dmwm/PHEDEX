Prototype for stress-testing DBS3 with the PhEDEx Lifecycle agent.
=================================================================

DBS3-Lifecycle.conf contains the configuration. The configuration file is 
executable Perl code, defining a single object that is used to drive the 
Lifecycle agent. Most of this is boilerplate, the interesting bits are the 
'Templates', Defaults, and 'Workflows'. See also the documentation in the 
file itself.

Templates is an array, in this case there is only one entry, called 
'DBS3Workflow'. It defines a sequence of Events, and Intervals between 
them. It also contains other parameters needed to kick-start the process, 
in this case the InitialRequest string.

Defaults are used to fill in the blanks for Templates. In this case, the 
Event names are mapped to the scripts that will carry out that event, 
stored in the Exec array of the Defaults. These could easily be put in the 
Templates themselves, but if one of the scripts were to be shared between 
several Templates, that would cause duplication of code.

The only entry in the Workflows array has a Name and the name of a 
Template. It picks up all its internals from the Template, augmented by 
the Defaults if the Template is not complete.

So this particular workflow, when it starts, will call dbs3GetDatasets.py 
(the action-script for the first event in the sequence). It calls it with 
two arguments: '--in <input-file> --out <output-file>'. The input file 
contains a JSON object with the payload for that particular step of the 
workflow. The payload also contains the full structure defining the 
workflow, so the script has access to everything it could possibly need to 
be able to do it's work. Look at dbs3GetDatasets.py and you'll see how it 
picks out the InitialRequest string and feeds it to the listDatasets API 
of DBS3, for example.

dbs3GetDatasets.py then creates a clone of the original payload for every 
dataset that it finds, and adds one dataset-name to each cloned payload. 
The array of new payload objects is stored, in JSON format, in the output 
file. The Lifecycle agent reads the output, and launches the next step in 
the workflow for each of the payloads.

The second step is like the first, feeding a JSON object via an input file 
to the dbs3GetBlocks.py script. This is almost identical to the 
dbs3GetDatasets.py script, simply getting the list of blocks in the 
dataset named in the payload. It returns, via the output file, an array of 
payloads with a single block-name in each. This step is called once for 
each payload object returned by dbs3GetDatasets.py.

You can see how that works using the sample input and output files in this 
directory. I saved the input file from a run of the agent, then ran this 
command by hand:

> dbs3GetBlocks.py --in demo-getBlocks.in --out demo-getBlocks.out
 Dataset name: /QCD_Pt80/StoreResults-Summer09-MC_31X_V3_7TeV-Jet30U-JetAODSkim-0a98be42532eba1f0545cc9b086ec3c3/USER
 Found 2 blocks

I've edited the output file by hand to make it clearer what's going on. 
You can see that it contains an array of two objects, which only differ by 
their 'block_name' attribute.

This is repeated with the third step, dbs3GetFiles.py, which gets the 
files belonging to the block specified in its payload.

So, starting from the InitialRequest string in the configuration file, the 
Lifecycle agent drives the three scripts to list all the files in all the 
blocks in all the datasets in DBS3. It uses parallelism to increase the 
throughput, with a limit on the number of concurrent processes (NJobs, in 
the configuration file). It doesn't care what the scripts do, they 
communicate with each other via their payloads, so the Lifecycle agent and 
the DBS3 scripts are very largely decoupled.

If you copy the Workflow entry in the configuration file and add a 
different InitialRequest string, you will end up driving two parallel 
workflows, which will stress the system for longer.

To run this for yourself, you have two choices. You can install from RPM,
in which case you can skip steps 0 and 1 here. Or you can use the scripts
here and install by hand. If you install from the RPM, you will need to
ensure that the DBS_READER_URL variable is set in your environment.

0) set up the environment:
Use the LifeCycleAgentDBS3.sh script to install the DBS3 environment and
software:

./LifeCycleAgentDBS3.sh -install

The important environment variables have been copied to the 'env.sh' file
in this directory. Check it, and copy it locally and modify if needed.

1) source the environment (unless you already have one set up):
. ./env.sh

If you want to remain independant of my AFS area, so you are not impacted
by any code-changes I make, you should copy the entire perl_lib directory
(~wildish/public/COMP/PHEDEX_CVS/perl_lib) to some place you control, and
update the PERL5LIB variable in the env.sh accordingly.

N.B. You must copy the directory, at the moment, it's not enough to make
a CVS checkout. Not all the code here is in CVS yet.

2) create your proxy
voms-proxy-init --voms cms

3) run the lifecycle agent
./Lifecycle-DBS3.pl --config DBS3Lifecycle.conf

You should see lots of logfiles appearing in /tmp/$USER!

If you want to add another step to the workflow, you need to:

1) add another entry to the Events array in the Templates
2) add another entry to the Intervals object in the Templates
3) add another entry to the Exec object in the Defaults
4) then write a script to actually perform the action, giving it the name 
   you specified in the line you add to the Exec object

the script that you write must conform to the following rules:
1) it must accept a '--in' argument, giving the name of an existing file
   with a JSON object in it. The script must take its configuration from 
   the contents of that file, and nowhere else
2) it must accept a '--out' argument, giving the name of a file to which 
   the script will write an output payload, or an array of output 
   payloads, derived from the input in some way
3) if the output payload is identical to the input payload, then there is 
   no need to write the output payload file, it can be ignored
4) if the script encounters an error that would prevent the rest of the 
   chain from working, it should return a non-zero status code. If it 
   completes normally, it must exit with status=0
5) the script is free to write output to a logfile or to the screen. If it 
   writes to the terminal, the output will be captured by the Lifecycle 
   agent and saved in a separate logfile, as well as being printed to the
   Lifecycle agent logfile with a header attached to allow unique 
   identification of the instance of the script
6) the script should execute synchronously, not exiting until it has 
   completed everything it is expected to do
7) the script should not use any shared resources, such as hardwired file 
   names for locks or logs. It may be executed in parallel in many 
   instances, so should not tread on its own toes
