#!/usr/bin/env python

import sys, os

# pfns are passed blank-separated
pfns = sys.argv[1:]

if not pfns:
       sys.stderr.write("%s: No pfns given\n" % sys.argv[0])
       sys.exit(1)

for pfn in pfns:
       # check here the right pfn syntax for your site
       if not pfn.startswith('/pnfs'): 
              sys.stderr.write('%s: wrong pfn skipped: %s\n' % (sys.argv[0], pfn) )
              continue
       if os.system("dccp -P %s" % pfn):
              sys.stderr.write('%s: dccp -P %s returns error\n' % (sys.argv[0], pfn) )

