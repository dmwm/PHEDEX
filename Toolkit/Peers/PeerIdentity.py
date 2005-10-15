class PeerIdentity:
  def __init__ (self, node, name):
    class Service:
      def identity (self): return name
    node.registerNamedHandler ("identity", Service ())
