This document is supposed to give you some examples on how to delete
replicas from your site using the FileDeleteTMDB script.

First you need to set up your PhEDEx environment, by issuing the following command:
  source PHEDEX/etc/profile.d/env.[c]sh

Let's assume you want to delete a single PFN from your site in the Dev
instance. To do this, you can issue the following command:

<snip>
PHEDEX/Utilities/FileDeleteTMDB \
 -db <path>/DBConfig:Dev/Writer \
 -storage <path>/TFC.xml \
 -list pfn:<PFN to delete> \
 -node <your node>
</snip>

This will delete pfn <PFN to delete> from site <your node> in the Dev
instance. Instead of giving a pfn you can also give an lfn by using
the prefix 'lfn:' or you can delete a whole block by using the 'block:'
prefix.

The '-list' argument accepts a comma separated list of arguments or an
ASCII txt file containing a list of files to remove. In the txt file you
specify one file or block per line and use the corresponding
prefix. Here an example for such an ASCII txt file. It contains lfns,
pfns and blocks:

<snip>
lfn:/store/1234.root
pfn:/local/disk/store/5678.root
block:/mydataset/myblock
</snip>

The above example file would delete two individual files plus all
files belonging to the specified block if given as argument to the
'-list' option of FileDeleteTMDB.

