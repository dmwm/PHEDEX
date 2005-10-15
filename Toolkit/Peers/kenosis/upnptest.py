import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName(testName="upnp.py")

from kenosis import upnp

class Test(dsunittest.TestCase):
    def testMapping(self):
        mappingTuple1 = ("", 50050, "TCP", "purpose1")
        mappingTuple2 = ("", 50051, "TCP", "purpose1")
        mappingTuple3 = ("0.0.0.0", 50050, "TCP", "purpose3")
        mappingTuple4 = ("", 50051, "UDP", "purpose4")

        mapper1 = upnp.UPnPMapper()
        host1, port1 = mapper1.map(mappingTuple1)
        host1v1, port1v1 = mapper1.map(mappingTuple1)
        self.assertEqual(host1, host1v1)
        self.assertEqual(port1, port1v1)

        mapper2 = upnp.UPnPMapper()
        host2, port2 = mapper2.map(mappingTuple2)
        host4, port4 = mapper2.map(mappingTuple4)

        mapper3 = upnp.UPnPMapper()
        host3, port3 = mapper3.map(mappingTuple3)

        self.assertNotEqual(port1, port2)
        self.assertNotEqual(port2, port3)
        self.assertEqual(port2, port4)

        # mapper3 decides that it can safely re-use mapper1's mapping
        self.assertEqual(port3, port1)
        
        self.assertEqual(host1, host2)
        self.assertEqual(host1, host3)

        self.assertEqual(mapper1.info(mappingTuple1), (host1, port1))
        self.assertRaises(ValueError, mapper1.info, mappingTuple2)
        self.assertRaises(ValueError, mapper1.unmap, mappingTuple2)

        mapper1.unmap(mappingTuple1)
        mapper2.unmap(mappingTuple2)
        mapper2.unmap(mappingTuple4)

        # because mapper3 re-used mapper1's mapping, the gateway
        # reports an error here
        self.assertRaises(upnp.UPnPError, mapper3.unmap, mappingTuple3)

if __name__ == "__main__":
    dsunittest.main()
