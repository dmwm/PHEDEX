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
        opts, args = getopt.getopt(sys.argv[1:], "r:", ["request="])
    except getopt.GetoptError, err:
        sys.stderr.write('%s: %s\n' % (sys.argv[0],str(err)))
        sys.exit(1)
        
    for o, a in opts:
        if o in ("-r", "--request"):
            config['request'] = a

    if not args:
        sys.stderr.write("%s: No surls given\n" % sys.argv[0])
        sys.exit(1)

    config['surls'] = args
    
    return config

#
# Main program
#
if __name__ == "__main__":
    
# Parse input
    config = parse_options()

# Set keys in GFAL dictionary
    knownsurls = []
    gfalreq = {}
    gfalreq['setype'] = 'srmv2'
    gfalreq['no_bdii_check'] = 1
    gfalreq['timeout'] = 86400
    if config.has_key('surls'):
        gfalreq['surls'] = config['surls']
    
# Prepare list of request tokens to query
    tokens = []

# If request token provided, use it
    if config.has_key('request'):
        tokens[0] = config['request']
    else:
    
# Otherwise, use the cache map file
        mapfilename = os.getenv('STAGE_CACHEMAP')
        if not mapfilename:
            sys.stderr.write('prestage: STAGE_CACHEMAP undefined\n')
            sys.exit(1)
        try:
            map = shelve.open(mapfilename)
            for surl in map.keys():
                token, t = map[surl]

# Delete entries older than 1 day
                if time.time() - t > 86400:
                    del map[surl]
                    continue
                    
                if surl in gfalreq['surls'] and not token in tokens:
                    tokens.append(token)
        except:
            sys.stderr.write('%s: cannot open %s\n' % (sys.argv[0],mapfilename))
            sys.exit(1)

# Exit with error if no request token was found
        if len(tokens) == 0:
            sys.stderr.write('%s: no requests submitted.\n' % sys.argv[0])
            sys.exit(1)

# Loop over all request tokens
    for token in tokens:
        reqsurls = []
        for k, v in map.iteritems():
            if v[0] == token:
                reqsurls.append(k)

# Create BringOnline request
        try:
            req = PrestageRequest(gfalreq)
        except RequestError, ex:
            sys.stderr.write(ex.message())
            sys.exit(1)

# Use known request token
        try:
            req.set_token(token)
        except RequestError, ex:
            sys.stderr.write(ex.message())
            sys.exit(1)

# Get status
        try:
            req.poll()
            files = req.status()
        except RequestError, ex:
            sys.stderr.write(ex.message())
            continue

        for file in files:
            surl = file['surl']
            knownsurls.append(surl)
            explanation = file['explanation']
            status = file['status']
            if surl in gfalreq['surls'] and surl in reqsurls and status == 0:
                print surl

# Check if some input surl is not in any request
    for surl in gfalreq['surls']:
        if not surl in knownsurls:
            sys.stderr.write('%s: no prestage request for %s\n' % (sys.argv[0],surl))
