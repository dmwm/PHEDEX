#!/usr/bin/env python
#
# Stuff for agents, much like UtilsAgent.pm

import sys, os

def output(file, contents):
    try:
        backup = "%s.%d.tmp" % (file, os.getpid())
        f = open (backup, "w")
        f.write (str (contents))
        f.close ()
        os.rename (backup, file)

    except:
	t,e,i = sys.exc_info()
        try: os.remove (backup)
        except: pass
	raise t,e,i
