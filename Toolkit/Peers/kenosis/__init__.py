from kenosis.node import \
     Node, defaultBootstrapNetAddress, defaultPorts, KenosisError, NodeNotFound, version
from kenosis.address import nodeAddressFromArbitraryString

def randomNodeAddress():

    """Returns a random string address for a node. This can be useful
    to pass to Node.findNearestNodes() if you want to get a random
    group of nodes to talk to."""

    return address.randomAddress().numericRepr()

def isNodeAddress(nodeAddress):

    """Returns True if nodeAddress is a valid node address"""

    return address.isTextAddress(string=nodeAddress)
