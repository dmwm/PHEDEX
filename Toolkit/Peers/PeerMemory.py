import kenosis, time, pickle
from optparse import OptionParser
from ds import dsthread
from UtilsCommand import *
from UtilsLogging import *

class PeerMemory:
  def __init__ (self, node, svcopts):
    cmds = OptionParser(usage="usage: Memory --file FILE")
    cmds.add_option ("--file", type="string", dest="file", help="Persistent state file")
    opts, args = cmds.parse_args (svcopts)
    if not getattr (opts, 'file', None):
      cmds.error ("--file required")

    self.node_ = node
    self.file_ = opts.file
    self.thread_ = dsthread.newThread (self.runMemoryThread)

  def read (self):
    if os.path.exists (self.file_):
      f = open (self.file_, 'r')
      history = []
      for line in f.readlines():
	(stamp, peerid, netaddr, nodeaddr) = line.split(' ')
	history.append({ 'stamp' : float(stamp), 'nodeaddr' : nodeaddr,
			 'netaddr' : netaddr, 'peerid' : peerid })
      f.close ()
      return history
    return []

  def save (self, history):
    str = "\n".join([ " ".join([`x['stamp']`, x['peerid'], x['netaddr'], x['nodeaddr']]) for x in history])
    output (self.file_, str + "\n")

  def prune (self, history):
    # Delete anything older than a day
    old = time.time() - 86400
    return [h for h in history if h['stamp'] >= old]

  def update (self, history, discovered):
    # Update history with discovered.  Returns a new history with
    # obsolete items removed and newly discovered ones added.
    seen = [d['peerid'] for d in discovered]
    return self.prune (discovered + [h for h in history if h['peerid'] not in seen])

  def discover (self):
    result = []
    peerlist = self.node_.findNearestNodes (kenosis.randomNodeAddress(), "identity")
    now = time.time()
    for nodeaddr, netaddr in peerlist:
      if nodeaddr != self.node_.nodeAddress():
	peerid = self.node_.rpc(nodeaddr).identity.identity()
      logmsg ("saw peer %s at %s (%s)" % (peerid, netaddr, nodeaddr))
      result.append ({ 'stamp' : now, 'nodeaddr' : nodeaddr,
		       'netaddr' : netaddr, 'peerid' : peerid })
    return result

  def runMemoryThread (self):
    # First read back old peer history, prune old entries from it
    recent = self.prune (self.read ())

    # Run an infinite loop polling on nodes and updating history.
    # Note that we poll random node addresses, allowing us to
    # scooter over the node space over time.
    while not self.node_.stopEvent_.isSet():
      recent = self.update (recent, self.discover ())
      self.save (recent)
      time.sleep (10) # 600
