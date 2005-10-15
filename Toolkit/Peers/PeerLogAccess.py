import os, os.path, re
from optparse import OptionParser
class LogAccess:
  def __init__ (self, dir):
    self.logdir = dir

  def list (self):
    # Return list of log files in self.logdir
    return filter(lambda x: os.path.isfile("%s/%s" % (self.logdir, x)),
        	  os.listdir (self.logdir))

  def tail (self, file, lines = None):
    # Return LINES of output from the end of FILE.  LINES may be None,
    # in which case all file contents is returned.
    if lines != None and not str(lines).isdigit(): return None
    if not re.compile("^[-A-Za-z0-9._]+$").match (file, 0): return None
    path = "%s/%s" % (self.logdir, file)
    if not os.path.isfile (path) or not os.access (path, os.R_OK):
      return None
    if lines == None:
      return os.popen ("cat %s" % path).readlines()
    else:
      return os.popen ("tail -%d %s" % (lines, path)).readlines()

class PeerLogAccess:
  def __init__ (self, node, svcopts):
    cmds = OptionParser(usage="usage: LogAccess --logdir DIR")
    cmds.add_option ("--logdir", type="string", dest="logdir", help="Log directory")
    opts, args = cmds.parse_args (svcopts)
    if not getattr (opts, 'logdir', None):
      cmds.error ("--logdir required")
    node.registerNamedHandler ("logs", LogAccess (opts.logdir))
