from __future__ import division

import sha
import random
import types

def randomAddress():
    s = sha.sha()
    for i in range(10):
        s.update(str(random.random()))
    return stringToAddress("0x%s" % s.hexdigest())

class InvalidAddressError(Exception): pass
addressLengthInBits = 160

def distance(address0, address1):
    return address0.address_ ^ address1.address_

def _stringToAddress(string):
    if isTextAddress(string):
        string = string.replace("address:", "")
        
    if string.startswith("0x"):
        return long(string, 16)
    address = 0L
    validChars = ["0", "1"]
    for c in string:
        value = validChars.index(c)
        address = (address << 1) + value
    return address

class NodeAddressObject:
    def __init__(self, nodeAddress=None, numericAddress=None):
        """Pass nodeAddress or numericAddress"""
        assert nodeAddress is not None or numericAddress is not None
        if nodeAddress is not None:
            self.address_ = _stringToAddress(nodeAddress)
        else:
            self.address_ = long(numericAddress)

    def __repr__(self):
        return "address.NodeAddressObject(numericAddress=0x%x)" % self.address_

    def numericRepr(self, numBits=addressLengthInBits):
        """Return the hex string representation of the address"""

        # Remove the L because the number was a long.
        return hex(self.address_).replace("L", "")
            
    def __str__(self):
        return "address:%s" % self.numericRepr()

    def __cmp__(self, otherAddress):
        if isinstance(otherAddress, NodeAddressObject):
            return cmp(self.address_, otherAddress.address_)
        else:
            raise TypeError("cannot compare %s and %s" % (repr(self), repr(otherAddress)))

    def __hash__(self):
        return hash(self.address_)

def isTextAddress(string):
    if not type(string) in types.StringTypes:
        return False
    if string.startswith("address:"):
        return True
    try:
        hexAddr = int(string, 16)
        return True
    except ValueError:
        return False

def stringToAddress(nodeAddress):
    return NodeAddressObject(nodeAddress=nodeAddress)

NodeAddressObjectUnknown = NodeAddressObject(nodeAddress="1" * addressLengthInBits)

def nodeAddressFromArbitraryString(string):
    return "0x"+sha.sha(string).hexdigest()
