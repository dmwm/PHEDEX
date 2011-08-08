#!/usr/bin/python2.6
# -*- encoding: utf-8 -*-

"""
Created on 2011-07-29

@author: Rapolas Kaselis <rapolas.kaselis@cern.ch>

Checks files for existing replicas on phedex. Used mostly when some
site asks to invalidate files at their storage system.

Requires python2.6 or newer, simplejson and argparse
modules (all available on lxplus)

--------------------------------------------------

USAGE:

    python2.6 file_replicas_checker.py list_of_files sitename
    
        - list_of_files - one file per line, can be either lfn,
          or pfn. Doesn't matter.
        - sitename - name of the site, understands shortnames, like
          CAF, CERN and similar. But better to provide full name, as it
          can be that replica "exists" on Buffer, but not on MSS.

    For example:
        python2.6 file_replicas_checker.py lfn_list.txt T2_CH_CAF

    Produces list of 3 possible lines:
        1. Couldn't understand where lfn starts - means, that the script
           didn't find /store/ in the filename
        2. Unknown - File is not known to PhEDEx
        3. Not registered at site: {lfn} - File is either invalidated,
           or wasn't yet registered at site

    And also two files in the same directory:
        1. Files, which should be invalidated at the site
        2. Files, which should be invalidated globally

    @TODO make a threaded version to increase the speed in calling dataservice.

    !NOTE - not tested thoroughly.
"""
                                                                            
import urllib2
import os
import sys
import simplejson
import re
import argparse

DATASVC = \
    "https://cmsweb.cern.ch/phedex/datasvc/json/prod/filereplicas?lfn={lfn}"

def get_lfn(filename):
    """
    Gets lfn from given filename
    """
    out = re.subn(".*/store/", "/store/", filename)
    if out[1] > 0:
        return out[0]
    else:
        print "Couldn't understand where lfn starts {0}".format(filename)
        return None

def get_replicas(lfn):
    """
    Gets sites where file replica exists
    """
    url = DATASVC.format(lfn = lfn)
    try:
        response = urllib2.urlopen(url)
        json = simplejson.load(response)["phedex"]
        if "block" in json and json["block"]:
            replicas = json["block"][0]["file"][0]["replica"]
            return [node["node"].lower() for node in replicas if node["node"]]
        else:
            print "Unknown: {lfn}".format(lfn=lfn)
    except Exception:
        print sys.exc_info()
    
    return None

def check_existency(sites, inspected_site):
    """
    Checks that file is registered at site,
    and file has a copy elsewhere.
    """
    regexp = re.compile(inspected_site.lower())
    subscr = False
    exists = False
    for site in sites:
        if regexp.search(site):
            subscr = True
        else:
            exists = True
    return exists, subscr


def parse_args():
    """
    Parses command line arguments
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("list", metavar="list.txt", action="store",
            type=str, 
            help="""List of files (one file per line), 
            can be any form, as long as it contains lfn""")
    parser.add_argument("site", metavar="site", action="store",
            type=str,
            help="""Site name against which to check replicas""")
    return parser.parse_args()

def main():
    args = parse_args()
    lost_buf = []
    recopy_buf = []
    try:
        for line in open(args.list):
            lfn = get_lfn(line.strip())
            if lfn:
                sites = get_replicas(lfn)
                if sites:
                    exists, subscribed = check_existency(sites, args.site)

                    if exists and subscribed:
                        recopy_buf.append(lfn)
                    elif exists:
                        print "Not registered at site: {lfn}".format(lfn=lfn)
                    else:
                        lost_buf.append(lfn)

    except IOError:
        sys.exit('There was an error reading {0} file'.format(args.list))

    if recopy_buf:
        recopy = open(args.site + "_recopy.txt" ,"w")
        for lfn in sorted(recopy_buf):
            recopy.write(lfn)
            recopy.write("\n")
        recopy.close()


    if lost_buf:
        lost = open(args.site + "_lost.txt" ,"w")
        for lfn in lost_buf:
            lost.write(lfn)
            lost.write("\n")

        lost.close()

if __name__ == "__main__":
    main()

