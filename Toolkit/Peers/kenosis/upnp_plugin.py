from ds import dsthread
from ds import dsunittest
from kenosis import upnp

class UpnpPlugin:
    def __init__(self, node):
        self.node_ = node
        self.mapper_ = upnp.UPnPMapper()

    def onListeningOnInternalPort(self, internalPort):
        dsthread.runInThread(function=self.__onListeningOnInternalPort, internalPort=internalPort)

    def notifyNewStreamService(self, name, streamPort, streamType):
        try:
            publicNetAddress = self.mapper_.map(port=("", streamPort, streamType, "kenosis-%s" % name))
            print "upnp_plugin mapped internal stream port %s to public address %s" % (streamPort, publicNetAddress)
            return publicNetAddress[1]
        except upnp.NoUPnPFound:
            dsunittest.traceException(text="UpnpPlugin.notifyNewStreamService: no upnp found")
            return streamPort
        
    def __onListeningOnInternalPort(self, internalPort):
        try:
            publicNetAddress = self.mapper_.map(port=("", internalPort, "TCP", "kenosis"))
        except upnp.UPnPError:
            dsunittest.traceException(text="UPnP not supported")
            return
        print "upnp_plugin mapped internal port %s to public address %s" % (internalPort, publicNetAddress)
        self.__portMappingDone(publicNetAddress=publicNetAddress)

    def __portMappingDone(self, publicNetAddress):
        self.node_.setExternalPort(publicNetAddress[1])

