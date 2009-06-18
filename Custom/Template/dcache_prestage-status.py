#!/usr/bin/env python

import sys, os

# pfns are passed blank-separated
pfns = sys.argv[1:]

if not pfns:
       sys.stderr.write("%s: No pfns given\n" % sys.argv[0])
       sys.exit(1)

for pfn in pfns:
       # check here the right pnfs syntax for your site
       if not pfn.startswith('/pnfs'): 
              sys.stderr.write('%s: wrong pfn skipped: %s\n' % (sys.argv[0], pfn) )
              continue
       if not os.system("dccp -P -t -1 %s > /dev/null 2>&1" % pfn):
              print pfn

