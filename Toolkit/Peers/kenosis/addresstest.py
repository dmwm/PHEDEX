import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName(testName="address.py")

from kenosis import address

class Test(dsunittest.TestCase):
    def testAddressStringConversion(self):
        addressPairs = (
            ("0x0", 0),
            ("0x1", 1L),
            ("0x" + "F" * 40, 2 ** 160 - 1))
        for addressString, addr in addressPairs:
            self.assertEqual(address.NodeAddressObject(numericAddress=addr), address.NodeAddressObject(nodeAddress=addressString))
            self.assertEqual("address:%s" % addressString, str(address.NodeAddressObject(numericAddress=addr)))

    def testDistance(self):
        tuples = (
            ("0000", "0000", 0),
            ("0001", "0000", 1),
            ("1010", "0101", 0xf),
            ("1010", "1010", 0))
        for address0String, address1String, distance in tuples:
            address0 = address.NodeAddressObject(nodeAddress=address0String)
            address1 = address.NodeAddressObject(nodeAddress=address1String)
            self.assertEqual(address.distance(address0=address0, address1=address1), distance)
            self.assertEqual(address.distance(address0=address1, address1=address0), distance)
            self.assertRaises(TypeError, cmp, address0, 42)

    def testHash(self):
        address0 = address.NodeAddressObject(nodeAddress="101")
        h = { address0: 1}
        self.assertEqual(h[address0], 1)
        l = [address0]
        assert address0 in l
        
    def testIsTextAddress(self):
        assert not address.isTextAddress(string="bob")
        assert address.isTextAddress(string="address:bob")
        assert not address.isTextAddress(string=[])
        assert isinstance(address.randomAddress(), address.NodeAddressObject)

if __name__ == "__main__":
    dsunittest.main()
