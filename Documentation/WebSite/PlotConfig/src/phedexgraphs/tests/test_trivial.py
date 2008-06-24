#!/usr/bin/env python

"""
test_trivial.py Demonstrates how to use the threading framework.
"""

import time
from phedexgraphs.tests.multithread_framework import multithread
import urllib2

def test_echo( work ):
    return work

def test_web(*args):
    return urllib2.urlopen('http://pcp031228pcs:8080').read()

if __name__ == '__main__':

    work = [(test_web, (i, )) for i in range(500)]
    work_time = -time.time()
    results = multithread(list(work), threads=10)
    work_time += time.time()
    print "Total work time: %.2f; %.2f events / second" % (work_time, \
        len(work) / work_time)

