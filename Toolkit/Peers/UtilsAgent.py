#!/usr/bin/env python
#
# Stuff for agents, much like UtilsAgent.pm

import sys, os, os.path, re
from optparse import OptionParser
from time import sleep
from UtilsLogging import *
from UtilsCommand import output

class Agent:
    def __init__ (self, opts):
	if not getattr (opts, 'statedir', None):
	    raise "fatal error: no drop box directory"

    	self._me       = os.path.split (sys.argv[0])[1];
    	self._statedir = getattr (opts, 'statedir')
	# self._nextdir  = []
	self._inbox    = os.path.join (self._statedir, "inbox")
	self._workdir  = os.path.join (self._statedir, "work")
	self._outdir   = os.path.join (self._statedir, "outbox")
	self._stopflag = os.path.join (self._statedir, "stop")
	self._pidfile  = os.path.join (self._statedir, "pid")
	self._waittime = getattr (opts, 'waittime', None) or 7
	# self._junk     = {}
	# self._bad      = {}
	# self._starttime = []

	if not os.path.isdir (self._statedir):
	    os.makedirs (self._statedir)
	if not os.path.isdir (self._inbox):
	    os.makedirs (self._inbox)
	if not os.path.isdir (self._workdir):
	    os.makedirs (self._workdir)
	if not os.path.isdir (self._outdir):
	    os.makedirs (self._outdir)

        if os.path.isfile (self._stopflag):
	    warn ("removing (old?) stop flag")
	    os.remove (self._stopflag)

	if os.path.isfile (self._pidfile):
            oldpid = open (self._pidfile).read().strip ("\n")
            warn ("removing (old?) pidfile (%s)" % oldpid)
            os.remove (self._pidfile)

        output(self._pidfile, os.getpid())

    # Hooks for derived classes
    def init (self): pass
    def stop (self): pass
    def idle (self):
	self.nap (self._waittime)

    # Check if we should stop.  If stop flag is set, clean up and quit.
    # Remove the pid file and the stop flag before exiting.
    def maybeStop (self):
	if not os.path.isfile (self._stopflag): return
	note ("exiting from stop flag")
	try:
	    os.remove (self._stopflag)
	    os.remove (self._pidfile)
	except: pass
	self.stop ()
	sys.exit (0)

    def nap (self, delta):
	target = datetime.datetime.utcnow () + datetime.timedelta (seconds=delta)
        while (datetime.datetime.utcnow () < target
	       and not os.path.isfile (self._stopflag)):
            sleep (1)
            
    def process (self):
	self.init ();
	while True:
	     drop = None
	     self.maybeStop ()
	     # readInbox()
	     # readPending()
	     # readOutbox()
	     self.idle ()

    # def readInbox (self):
    # def readPending (self):
    # def readOutbox (self):
    # def renameDrop (self):
    # def relayDrop (self, drop):
    # def inspectDrop (self, drop):
    # def markBad (self, drop):
    # def processDrop (self, drop):
