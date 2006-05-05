This document explains how to participate in the CMS transfer load
test: continuous 20 MB/s sustained transfer load to every site.

** Creating a load test sample for your site

SITECONF/CERN/LoadTest has utilities you should use to prepare and
copy a load test sample to your site.  You will need to replace
"TX_Foo" with your site name, for example "T1_FNAL" or "T2_Spain".

   SITECONF/CERN/LoadTest/CreateSample TX_Foo
   SITECONF/CERN/LoadTest/CopySample TX_Foo srm://.../phedex_loadtest
   PHEDEX/Toolkit/Request/TMDBInject -strict -verbose \
     -db SITECONF/Foo/PhEDEx/DBParam:SC4/FOO \
     -nodes TX_Foo_Load -filedata LoadTest_TX_Foo.xml

The srm://.../phedex_loadtest should be the SRM directory into which
you want to copy the load test sample files, ideally on disk-only
storage or at the very least tape migration disabled.  There should be
several hundred gigabytes free space.

** Setting up agents

You need to set up agents for TX_Foo_Load (again adjust name):
  - FileDownload for transfers
  - FileDiskExport for exports.
  - FilePFNExport for PFN generation.
  - FileRecycler to delete the downloaded files.
  - InfoDropStatus to update agent status.

Of these, you may need to add just FileDownload and FileRecycler, and
reuse the rest of the agents from your normal site configuration.

You can examine the entire configuration CERN uses for SC4 and load
test in particular in SITECONF/CERN/PhEDEx/Config.SC4.  Note that the
file mentions many infrastructure agents you do not need to run; the
"normal" agents are in the section labeled "ConfigPart.Common", and
the agents specifically for the load test are in the section labeled
"ConfigPart.LoadTest".

Make sure your storage.xml is able to map the load test files from the
SRM directory you created.  See SITECONF/CERN/PhEDEx/storage.xml for
an example.


     
