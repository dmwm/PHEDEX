import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName("dns/__init__.py")

from kenosis import address
from kenosis import dns
from ds import dstime

import socket

class Test(dsunittest.TestCase):
    def setUp(self):
        dstime.setTestingTime(0)
        socket.setdefaulttimeout(0.5)

    def tearDown(self):
        pass

    def testSimple(self):
        na, serviceName = dns.nodeAddressAndServiceNameFrom(
            url="http://FFFAAFFF.node.bt.kenosisp2p.org:1234/asdfasdf/asdf/d/")
        self.assertEqual(na, "0xFFFAAFFF")
        self.assertEqual(serviceName, "bt")
        na, serviceName = dns.nodeAddressAndServiceNameFrom(
            domain="FFFAAFFF.node.bt.kenosisp2p.org")
        self.assertEqual(serviceName, "bt")
        self.assertEqual(na, "0xFFFAAFFF")
        na, serviceName = dns.nodeAddressAndServiceNameFrom(domain="adfasdf")
        self.assertEqual(na, None)

        na, serviceName = dns.nodeAddressAndServiceNameFrom(domain="foo.bt.kenosisp2p.org")
        import sha
        ob = sha.sha()
        ob.update("foo")
        addr = "0x%s" % ob.hexdigest()
        self.assertEqual(na, addr)
        
        self.assertRaises(AssertionError, dns.hostNameFor, nodeAddress="0xna", serviceName="bt")
        self.assertEqual(
            dns.hostNameFor(nodeAddress="0x123", serviceName="zz"), "123.node.zz.kenosisp2p.org")
        self.assertEqual(
            dns.hostNameFor(nodeAddress="123fa3", serviceName="zz"),
            "123fa3.node.zz.kenosisp2p.org")

if __name__ == "__main__":
    dsunittest.main()
