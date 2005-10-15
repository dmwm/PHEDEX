import socket

from ds import dsthread
from ds import dsunittest
from kenosis import Zeroconf
from kenosis import address

kenosisLocalDomain = '_kenosis._tcp.local.'

class ZeroconfPlugin:
    def __init__(self, node):
        self.node_ = node
        self.zeroconf_ = Zeroconf.Zeroconf()

    # Zeroconf listener methods
    def removeService(self, server, type, name):
        dsunittest.trace("Service %r removed" % name)

    def addService(self, server, type, name):
        dsunittest.trace("Service %r added" % name)
        # Request more information about the service
        info = server.getServiceInfo(type, name)
        dsunittest.trace('Additional info: %s' % info)
        if not info:
            return
        netAddress = "%s:%s" % (socket.inet_ntoa(info.getAddress()), info.port)
        resultDict = self.node_.nodeKernel_._pingNode(
            nodeAddressObject=address.NodeAddressObjectUnknown,
            netAddress=netAddress,
            serviceName="kenosis")
        nodeAddressObject = resultDict["nodeAddress"]
        if nodeAddressObject != self.node_.nodeKernel_.nodeAddressObject_:
            self.node_.nodeKernel_._updateRoutingTableWith(
                netAddress=netAddress, nodeAddressObject=nodeAddressObject,
                serviceName="kenosis")

    # Kenosis plugin methods
    def onListeningOnInternalPort(self, internalPort):
        # Get local IP address
        local_ip = socket.gethostbyname(socket.gethostname())
        local_ip = socket.inet_aton(local_ip)

        nodeAddress = self.node_.nodeAddress()
        self.browser_ = Zeroconf.ServiceBrowser(self.zeroconf_,
                                                kenosisLocalDomain,
                                                self) # listener object
        svc1 = Zeroconf.ServiceInfo(kenosisLocalDomain,
                                    'Kenosis %s.%s' % (nodeAddress, kenosisLocalDomain),
                                    address = local_ip,
                                    port = internalPort,
                                    weight = 0, priority=0,
                                    properties = {'description':
                                                  'Kenosis node %s' % nodeAddress}
                                    )
        self.zeroconf_.registerService(svc1)
