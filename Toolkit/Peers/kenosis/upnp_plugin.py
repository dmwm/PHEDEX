from ds import dsthread
from ds import dsunittest
from kenosis import upnp

class UpnpPlugin:
    def __init__(self, node):
        self.node_ = node
        self.mapper_ = upnp.UPnPMapper()

    def onListeningOnInternalPort(self, internalPort):
        dsthread.runInThread(function=self.__onListeningOnInternalPort, internalPort=internalPort)

    def __onListeningOnInternalPort(self, internalPort):
        try:
            publicNetAddress = self.mapper_.map(port=("", internalPort, "TCP", "kenosis"))
        except upnp.UPnPError:
            dsunittest.traceException(text="UPnP not supported")
            return
        self.__portMappingDone(publicNetAddress=publicNetAddress)

    def __portMappingDone(self, publicNetAddress):
        self.node_.setExternalPort(publicNetAddress[1])

