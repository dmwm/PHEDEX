import socket

from ds import dsthread
from ds import dsunittest
from kenosis import Zeroconf
from kenosis import address

kenosisLocalDomain = '_kenosis._tcp.local.'

import xmlrpclib
import urllib2
import socket
NetworkErrorClasses = (xmlrpclib.Fault,
                       xmlrpclib.ProtocolError,
                       xmlrpclib.expat.ExpatError,
                       urllib2.URLError,
                       socket.error,
                       socket.timeout)

class ZeroconfPlugin:
    def __init__(self, node):
        self.node_ = node
        self.zeroconf_ = Zeroconf.Zeroconf()
        self.advertizedNetAddress_ = None
        #print "zeroconf_ init"

    # Zeroconf listener methods
    def removeService(self, server, type, name):
        dsunittest.trace("Service %r removed" % name)

    def addService(self, server, type, name):
        #print "Service %r added" % name
        # Request more information about the service
        info = server.getServiceInfo(type, name)
        #print 'Additional info: %s' % info
        if not info:
            return
        #print 'pinging: %s' % info
        netAddress = "%s:%s" % (socket.inet_ntoa(info.getAddress()), info.port)
        if netAddress != self.advertizedNetAddress_:
            #print("my address is %s, his address is %s" % (self.advertizedNetAddress_, netAddress))
            try:
                self.node_.nodeKernel_.bootstrap(netAddress=netAddress, serviceName="kenosis")
            except NetworkErrorClasses:
                dsunittest.traceException("Failed pinging node found via Zeroconf: %s" % netAddress)
                return
            
    # Kenosis plugin methods
    def onListeningOnInternalPort(self, internalPort):
        #print "zeroconf_ onListeningOnInternalPort: %s" % internalPort
        # Get local IP address
        local_ip = socket.gethostbyname(socket.gethostname())
        #print "Zeroconf: local_ip %s" % local_ip
        self.advertizedNetAddress_ = "%s:%s" % (local_ip, internalPort)
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

    def stop(self):
        #globals()['_GLOBAL_DONE'] = 1
        #Zeroconf._GLOBAL_DONE = 1
        self.zeroconf_.close()
        self.browser_.cancel()
