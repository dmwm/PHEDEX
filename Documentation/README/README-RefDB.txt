*** Generating data from the RefDB

** Background

We have several utilities to help in inserting data into the transfer
system from RefDB and CERN Castor MSS. "RefDB tools" allow the user to
generate summary information to guide insertion of data.  "Drop*"
tools are used to process that summary information and use it to
insert data files into the transfer system.

The objective of the RefDB tools is to simulate the output of a
reconstruction or simulation farm: they produce output in the same
format, in packets of information we call "drops", as a normal job
would.  Each drop must have at least two files, a XML catalogue
fragment and a summary file, and optionally a checksum file.  The
catalog fragment lists the files created by the job, using relative
PFNs.  The summary file defines the base directory in which those
files exist at that site, at CERN a path in Castor.

The expected minimal drop processing chain is then something like
this:
  - DropXMLUpdate: Expand the XML fragment to complete POOL catalogue
    and remap relatives PFNs to full paths using the summary file.
  - DropCastorStageIn: Stage in the files.
  - DropCastorChecksum: Generate checksums if they are missing.
  - DropCastorGridPFN: Update PFNs to sfn://castorgrid.cern.ch format.
  - DropCatPublish: Publish the XML to the local/rls catalogue.
  - DropTMDBPublish: Publish the files for transfer.

** Overview of the RefDB tools

Typically data is inserted into the transfer system using the
following process:
  1. Given a list of data requests, determine the full list of
     dataset/owner pairs.
  2. Map the dataset/owner pairs to RefDB assignments.
  3. Generate "drops" for each job in each such assignment: extract
     the XML fragment saved in RefDB, figure out where in Castor the
     data producer uploaded the files and record the location in the
     summary file.
  4. Check if all the files have been uploaded into Castor.  If they
     are all available, mark all the drops in the assignment ready for
     transfer.

The main tool, "RefDBReady", performs all these steps in one go.
There is a separate script for each of these tasks, which RefDBReady
simply invokes.

"RefDBList" expands dataset.owner patterns to full names.  The
patterns are shell file globs, given either on the command line or in
a file.  (Note that patterns given on the command line may need to be
quoted so your shell doesn't try to expand them!)

"RefDBAssignments" maps dataset.owner names to lists of assignments.

"RefDBDrops" generates drops for assignments: a drop with the XML
fragment and the summary file for each job in each of the assignments
it is given.

"RefDBCheck" checks which fraction of the files are available in
Castor and marks fully available assignments ready for transfer.
Files become available as production sites upload them to CERN, and
submit their status to RefDB.

Invoking any of these scripts with the "-h" option will produce a
brief guide to usage.

** Examples of using the tools

* Download tools from CVS

  setenv CVSROOT :pserver:anonymous@cmscvs.cern.ch:/cvs_server/repositories/TMAgents
  cvs login # password is "98passwd"
  cvs co AgentToolkitExamples/DropBox
  cd AgentToolkitExamples/DropBox

* Generate drops for assignments of mu03b_DY2mu*.*PU761*

  $ ./RefDBReady 'mu03b_DY2mu*.*PU761*'
  Generating drops for 6103
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800001
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800002
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800003
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800004
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800005
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800006
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800007
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800008
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800009
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800010
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800011
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800012
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800013
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800014
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800015
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800016
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800017
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800018
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800019
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800020
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800021
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800022
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800023
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800024
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800025
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800026
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800027
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800028
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800029
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800030
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800031
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800032
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800033
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800034
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800035
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800036
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800038
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800039
  Generating drop mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC.6103-Digi-2x1033PU761_TkMu_2.67800040
  6103: 117/117 files present in castor: ready for transfer

* Generate drops for assignment 4961-4965

  $ ./RefDBReady -a 4961 4962 4963 4964 4965
  Generating drops for 4961
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900001
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900002
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900003
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900004
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900005
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900006
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900007
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900008
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900009
  Generating drop hg03_hzz_2e2mu_115a.hg_2x1033PU761_TkMu_g133_CMS.4961-Digi-2x1033PU761_TkMu.130900010
  Generating drops for 4962
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000001
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000002
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000003
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000004
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000005
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000006
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000007
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000008
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000009
  Generating drop hg03_hzz_2e2mu_120a.hg_2x1033PU761_TkMu_g133_CMS.4962-Digi-2x1033PU761_TkMu.131000010
  Generating drops for 4963
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100001
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100002
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100003
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100004
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100005
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100006
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100007
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100008
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100009
  Generating drop hg03_hzz_2e2mu_130a.hg_2x1033PU761_TkMu_g133_CMS.4963-Digi-2x1033PU761_TkMu.131100010
  Generating drops for 4964
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200001
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200002
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200003
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200004
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200005
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200006
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200007
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200008
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200009
  Generating drop hg03_hzz_2e2mu_140a.hg_2x1033PU761_TkMu_g133_CMS.4964-Digi-2x1033PU761_TkMu.131200010
  Generating drops for 4965
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300001
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300002
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300003
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300004
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300005
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300006
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300007
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300008
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300009
  Generating drop hg03_hzz_2e2mu_150a.hg_2x1033PU761_TkMu_g133_CMS.4965-Digi-2x1033PU761_TkMu.131300010
  4961: 30/30 files present in castor: ready for transfer
  4962: 30/30 files present in castor: ready for transfer
  4963: 30/30 files present in castor: ready for transfer
  4964: 30/30 files present in castor: ready for transfer
  4965: 30/30 files present in castor: ready for transfer

* List dataset.owner pairs for mu03b data

  $ ./RefDBList 'mu03b*'
  mu03b_DY2mu_Mll2000.mu_2x1033PU752_TkMu_2_g133_OSC
  mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC
  mu03b_DY2mu_Mll2000.mu_DST813_2_g133_OSC
  mu03b_DY2mu_Mll2000.mu_Hit241_g133
  mu03b_DY2mu_Mll2000.mu_Hit245_2_g133
  mu03b_DY2mu_Mll2000.mu_NoPU752_TkMu_g133_OSC
  mu03b_DY2mu_Mll2000.sw_Hit2404_g133
  mu03b_DY2mu_Mll2000.sw_Hit2451_g133
  mu03b_MBforPU.eg_Hit241_g133
  mu03b_MBforPU.mu_cms133_g133
  mu03b_MBforPU.mu_Hit244_g133
  mu03b_MBforPU.mu_Hit244_g133
  mu03b_MBforPU.mu_Hit245_g133
  mu03b_MBforPU.mu_Hit245_g133
  mu03b_MBforPU.mu_Hit750_g133
  mu03b_MBforPU.mu_Hit750_g133
  mu03b_MBforPU.sw_Hit2451_g133
  mu03b_MBforPU.sw_Hit245462_g133
  mu03b_MBforPU.sw_Hit323_2_3_g133
  mu03b_zbb_4mu_compHEP.mu_2x1033PU761_TkMu_2_g133_OSC
  mu03b_zbb_4mu_compHEP.mu_2x1033PU761_TkMu_2_g133_OSC
  mu03b_zbb_4mu_compHEP.mu_Hit245_2_g133
  mu03b_zbb_4mu_compHEP.mu_Hit245_2_g133_OSC

* List assignments for mu03b_DY2mu dataset.owners

  $ ./RefDBList 'mu03b_DY2mu*' | xargs ./RefDBAssignments -v
  4272 mu03b_DY2mu_Mll2000.mu_2x1033PU752_TkMu_2_g133_OSC
  6103 mu03b_DY2mu_Mll2000.mu_2x1033PU761_TkMu_2_g133_OSC
  6116 mu03b_DY2mu_Mll2000.mu_DST813_2_g133_OSC
  3618 mu03b_DY2mu_Mll2000.mu_Hit241_g133
  4144 mu03b_DY2mu_Mll2000.mu_Hit245_2_g133
  4259 mu03b_DY2mu_Mll2000.mu_NoPU752_TkMu_g133_OSC
  3288 mu03b_DY2mu_Mll2000.sw_Hit2404_g133
  3868 mu03b_DY2mu_Mll2000.sw_Hit2451_g133

* Check whether previously created drops are now ready to go

  $ ./RefDBCheck drops-for-*
  3288: 0/0 files present in castor: not ready for transfer
  3618: 0/190 files present in castor: not ready for transfer
  3868: 0/69 files present in castor: not ready for transfer
  4144: 120/120 files present in castor: ready for transfer
  4259: 0/160 files present in castor: not ready for transfer
  4272: 0/140 files present in castor: not ready for transfer
  6103: 117/117 files present in castor: ready for transfer
  6116: 114/114 files present in castor: ready for transfer
