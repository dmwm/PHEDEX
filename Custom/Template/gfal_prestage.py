#!/usr/bin/env python

import sys, os
import re
import time
import getopt
import shelve

from gfalrequest import *

def parse_options():
    config = {}
    try:
        opts, args = getopt.getopt(sys.argv[1:], "p:", ["pin-time="])
    except getopt.GetoptError, err:
        sys.stderr.write('%s: %s\n' % (sys.argv[0],str(err)))
        sys.exit(1)

    for o, a in opts:
        if o in ("-p", "--pin-time"):
            config['pinlifetime'] = a

    if not args:
        sys.stderr.write("%s: No surls given\n" % sys.argv[0])
        sys.exit(1)

    config['surls'] = args

    return config

def terminate(req, code):
    try:
        req.abort()
    except RequestError, ex:
        print ex.message()
    req.free()
    sys.exit(code)

#
# Main program
#
if __name__ == "__main__":
    
# Parse input
    config = parse_options()

# Get cache map file name and open it
    mapfilename = os.getenv('STAGE_CACHEMAP')
    if not mapfilename:
        sys.stderr.write('prestage: STAGE_CACHEMAP undefined\n')
        sys.exit(1)
    try: 
        map = shelve.open(mapfilename)

# Delete entries in the cache map older than 1 day
        for surl in map.keys():
            token, t = map[surl]
            if time.time() - t > 86400:
                del map[surl]

    except:
        sys.stderr.write('%s: cannot open %s\n' % (sys.argv[0],mapfilename))
        
# Set keys in GFAL dictionary
    gfalreq = {}
    gfalreq['setype'] = 'srmv2'
    gfalreq['no_bdii_check'] = 1
    gfalreq['timeout'] = 86400    # will set 'desiredTotalRequestTime',
    if config.has_key('surls'):
        gfalreq['surls'] = config['surls']
    if config.has_key('pinlifetime'):
        gfalreq['srmv2_desiredpintime'] = config['pinlifetime']

# Create BringOnline request
    try:
        req = PrestageRequest(gfalreq)
    except RequestError, ex:
        print ex.message()
        sys.exit(1)

# Submit request
    start_time = time.time()
    try:
        req.submit()
    except RequestError, ex:
        print ex.message()
        sys.exit(1)

# Get request ID
    try:
        token = req.token()
        for surl in gfalreq['surls']:
            map[surl] = [token, start_time]
    except RequestError, ex:
        print ex.message()
        terminate(req, 1)
