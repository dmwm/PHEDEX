import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest


class Test(dsunittest.TestCase):
    def testWebpageExample(self):
        import kenosis
        n = kenosis.Node(bootstrapNetAddress=None)
        n2 = kenosis.Node(bootstrapNetAddress=None)
        n2.bootstrap("localhost:%s" % n.port())
        n2.rpc(nodeAddress=n.nodeAddress()).kenosis.ping()
        class Handler:
            def returnInt(self, invocationInfo, arg):
                return int(arg)
        n.registerNamedHandler(name="test", handler=Handler())
        self.assertEqual(n2.rpc(nodeAddress=n.nodeAddress()).test.returnInt(42), 42)
        self.assertEqual(n2.rpc(nodeAddress=n.nodeAddress()).test.returnInt(1234321), 1234321)
        n.rpc(nodeAddress=n2.nodeAddress()).kenosis.ping()

        n.stopEvent_.set()
        n2.stopEvent_.set()

    def testFindNearestOnRealNetwork(self):
        import kenosis
        n = kenosis.Node()

        # findNearestNodes is slow because it wants to find 20 working
        # nodes but most of the time our network does not have that
        # many nodes so it has to try to contact every on the network
        # before giving up.
        nodeAddress = kenosis.randomNodeAddress()
        for x in range(2):
            nodeInfos = n.findNearestNodes(
                nodeAddress=nodeAddress, serviceName="kenosis")
            print("Found nodes: %s" % nodeInfos)

        n.stopEvent_.set()

    # This requires that you have the ports open to your computer.
    def testRpcOnRealNetwork(self):
        import kenosis
        n = kenosis.Node(ports=[6885])
        n2 = kenosis.Node(ports=[6886])

        class Handler:
            def returnInt(self, invocationInfo, arg):
                return int(arg)
        n.registerNamedHandler(name="test", handler=Handler())

        # This will happen eventually but we want to make sure that
        # this happens now, so that the rpc can work.
        n.step()

        self.assertEqual(n2.rpc(nodeAddress=n.nodeAddress()).test.returnInt(123), 123)

        n.stopEvent_.set()
        n2.stopEvent_.set()

    def testJunk(self):
        import kenosis
        n = kenosis.Node(useUpnp=False, useZeroconf=False)
        print("node %s on port %s" % (n.nodeAddress(), n.port()))
        print("found: %s" % n.findNearestNodes(nodeAddress=kenosis.randomNodeAddress(), serviceName="kenosis"))

if __name__ == "__main__":
    dsunittest.main()
