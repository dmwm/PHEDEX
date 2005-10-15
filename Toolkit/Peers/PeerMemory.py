import kenosis, time
from ds import dsthread
class PeerMemory:
  def __init__ (self, node, file):
    self.thread_ = dsthread.newThread (function=self.runSave, params=(node, file,))
  def runSave (self, node, file):
    # FIXME: Maintain a list of node identities.
    while not node.stopEvent_.isSet():
      nodes = node.findNearestNodes (node.nodeAddress (), "identity")
      for nodeaddr, netaddr in nodes:
	if nodeaddr != node.nodeAddress():
          print "Peer %s at %s (%s)" % (node.rpc(nodeaddr).identity.identity (), netaddr, nodeaddr)
      time.sleep (600)
