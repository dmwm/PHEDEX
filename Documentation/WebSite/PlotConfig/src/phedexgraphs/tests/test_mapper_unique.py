#!/usr/bin/env python

"""
test_mapper_unique.py Records the amount of time needed for a unique mapping.
"""

import time, urllib2

from phedexgraphs.tests.multithread_framework import multithread

def test_unique(site, lfn):
    return urllib2.urlopen('http://t2.unl.edu/phedex/tfc/map/%s?lfn=%s' % \
        (site, lfn)).read()

if __name__ == '__main__':

    work = [(test_unique, ('T2_Nebraska_Buffer', '/store/mc/lfn%i' % i)) \
        for i in range(100)]
    work_time = -time.time()
    results = multithread(list(work), threads=10)
    work_time += time.time()
    print "Total work time: %.2f; %.2f events / second" % (work_time, \
        len(work) / work_time)


