#!/usr/bin/env python
#
# Logging stuff that mirrors UtilsLogging.pm

import sys, os, datetime

def logmsg (arg):
    prefix = ("%s: %s[%d]: " %
        (datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
	 os.path.split (sys.argv[0])[1], os.getpid ()))
    print prefix + arg

def alert (arg): logmsg ("alert: " + arg)
def warn (arg):  logmsg ("warning: " + arg)
def note (arg):  logmsg ("note: " + arg)
