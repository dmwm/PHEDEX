from kenosis import address
from kenosis import upnp_plugin
from kenosis import zeroconf_plugin
from kenosis import xmlrpclib_transport
from ds import dsqueue
from ds import dsthread
from ds import dsfile
from ds import dstime
from ds import dsunittest
from ds import task
from ds import ui

from ds import IPy

import copy
from sets import Set
import Queue
import random
import SimpleXMLRPCServer
import os
import random
import socket
import SocketServer
import sys
import time
import threading
import traceback
import urllib2
import xmlrpclib

protocolVersion = 96
version = "0.96"

#defaultBootstrapNetAddress = "root.kenosisp2p.org:5005"
#defaultBootstrapNetAddress = "192.168.0.4:5005"
defaultBootstrapNetAddress = "69.55.229.46:5005" # john.redheron.com
defaultPorts = range(5005, 50150)
staleInfoTime = 300
kenosisFindNodesTimeout = 2
kenosisRpcNetworkConnectionTimeout = 30
userRpcTimeout = 20
maxTimeBetweenBucketOperations = 60 * 60


NetworkErrorClasses = (xmlrpclib.Fault,
                       xmlrpclib.ProtocolError,
                       xmlrpclib.expat.ExpatError,
                       urllib2.URLError,
                       socket.error,
                       socket.timeout)
NodeAddressObjectUnknown = address.NodeAddressObjectUnknown

allServicesServiceName = "all"

# returns None for port if no port is specified in that case, urllib2
# controls the port number which will depend on whether the request is
# HTTP or HTTPS
def hostAndPortFromNetAddress(netAddress):
    if ":" in netAddress:
        return netAddress.split(":", 1)
    else:
        return netAddress, None

def netAddressIsPrivate(netAddress):
    host, port = hostAndPortFromNetAddress(netAddress=netAddress)
    try:
        ip = IPy.IP(host)
    except ValueError:
        return False
    return ip.iptype() == 'PRIVATE'
    
class GrowingQueue:
    def __init__(self, iterator, realQueue):
        self.iterator_ = iterator
        self.realQueue_ = realQueue
        self.fromIterator_ = None
        self.iteratorEmpty_ = 0
        ret = self._getFromIterator()
        assert ret is None

    def empty(self):
        return self.realQueue_.empty() and self.iteratorEmpty_

    def get(self):
        if self.empty():
            raise Queue.Empty()
        assert not self.empty()
        if not self.iteratorEmpty_ and not self.realQueue_.empty():
            fromQueue = self.realQueue_.get()
            if self.fromIterator_ < fromQueue:
                self.realQueue_.put(fromQueue)
                return self._getFromIterator()
            else:
                return fromQueue
        elif self.iteratorEmpty_:
            return self.realQueue_.get()
        else:
            return self._getFromIterator()
                
    def _getFromIterator(self):
        try:
            temp = self.fromIterator_
            self.fromIterator_ = self.iterator_.next()
        except StopIteration:
            self.iteratorEmpty_ = 1
        return temp

def newRpcHeader(sourceNodeAddressObject, destNodeAddressObject):
    return {"sourceNodeAddress":sourceNodeAddressObject,
            "version": protocolVersion,
            "destNodeAddress":destNodeAddressObject}

def assertRpcHeaderMightBeValid(rpcHeader):
    assert type(rpcHeader) == type({}), "assertRpcHeaderMightBeValid: %s is not a valid rpcHeader" % repr(rpcHeader)
    assert rpcHeader.has_key("sourceNodeAddress")
    assert rpcHeader.has_key("destNodeAddress")

def assertRpcHeaderValid(rpcHeader):
    assertRpcHeaderMightBeValid(rpcHeader=rpcHeader)
    assert rpcHeader.has_key("sourceNetHost")
    assert rpcHeader.has_key("sourceNetPort")

def sourceNodeAddressObjectFrom(rpcHeader):
    return rpcHeader["sourceNodeAddress"]

def sourceNetAddressFrom(rpcHeader):
    assertRpcHeaderMightBeValid(rpcHeader=rpcHeader)
    return "%s:%s" % (rpcHeader["sourceNetHost"], rpcHeader["sourceNetPort"])

def destNodeAddressObjectFrom(rpcHeader):
    assertRpcHeaderMightBeValid(rpcHeader=rpcHeader)
    return rpcHeader["destNodeAddress"]

def versionNumberFrom(rpcHeader):
    return rpcHeader.get("version", 92)

def versionClientUsesServices(rpcHeader):
    return versionNumberFrom(rpcHeader=rpcHeader) >= 93

class Rpc:
    def __init__(self, rpcHeader, toplevelRpc, attributeNames, nodeKernel):
        self.rpcHeader_ = rpcHeader
        self.toplevelRpc_ = toplevelRpc
        self.attributeNames_ = attributeNames
        self.nodeKernel_ = nodeKernel
        self.serverProxy_ = None

    def __getattr__(self, name):
        # Note: we deliberately do not use nameIsPrivate() here
        # becuase that is a stronger test than we need. We only want
        # to prevent python from thinking that we support __eq__, etc.
        if name.startswith("__") and name.endswith("__"):
            raise AttributeError(name)
        return Rpc(
            rpcHeader=self.rpcHeader_,
            toplevelRpc=self.toplevelRpc_ or self,
            attributeNames=self.attributeNames_ + [name],
            nodeKernel=self.nodeKernel_)
        
    def __call__(self, *args):
        try:
            if not self.toplevelRpc_.serverProxy_:
                destNodeAddressObject = destNodeAddressObjectFrom(rpcHeader=self.rpcHeader_)
                self.toplevelRpc_.serverProxy_ = self.nodeKernel_._serverProxyForNodeAddressObject(
                    nodeAddressObject=destNodeAddressObject, serviceName=self.attributeNames_[0])

            sp = self.toplevelRpc_.serverProxy_
            for name in self.attributeNames_:
                sp = getattr(sp, name)
            return sp(self.rpcHeader_,  *args)

        except NetworkErrorClasses, e:
            raise NetworkError(e)

class NodeInfo:
    def __init__(self, nodeAddressObject, netAddress):
        self.nodeAddressObject_ = nodeAddressObject
        self.netAddress_ = netAddress
        self.updateFreshness()
        self.failedContacts_ = 0

    def __repr__(self):
        return "NodeInfo(%s, %s, %s)" % (self.nodeAddressObject_, self.netAddress_, self.timeSinceLastSuccessfulContact())

    def updateFreshness(self, newNetAddress=None):
        self.lastSuccessfulContact_ = dstime.time()
        self.lastAttemptedContact_ = self.lastSuccessfulContact_
        if newNetAddress is not None:
            self.netAddress_ = newNetAddress
        self.failedContacts_ = 0

    def notifyFailedContact(self):
        self.failedContacts_ += 1
        self.lastAttemptedContact_ = dstime.time()

    def timeSinceLastAttemptedContact(self):
        return dstime.time() - self.lastAttemptedContact_
        
    def timeSinceLastSuccessfulContact(self):
        if not self.shouldCommunicateWithNode():
            return sys.maxint
        return dstime.time() - self.lastSuccessfulContact_

    def shouldCommunicateWithNode(self):
        if self.isStale():
            return False
        if self.failedContacts_ == 0:
            return True
        # Kademlia paper suggests exponential backoff - should we do that?
        penaltyTime = self.failedContacts_ * kenosisRpcNetworkConnectionTimeout
        return self.timeSinceLastAttemptedContact() > penaltyTime
    
    def isStale(self):
        return self.failedContacts_ >= 5

    def netAddress(self):
        return self.netAddress_

    def nodeAddressObject(self):
        return self.nodeAddressObject_

    def __eq__(self, otherNodeInfo):
        assert isinstance(otherNodeInfo, NodeInfo)
        return self.nodeAddressObject_ == otherNodeInfo.nodeAddressObject_

    def asTuple(self):
        return (self.nodeAddressObject_, self.netAddress_)

class KenosisError(Exception): pass
class NodeNotFound(KenosisError): pass
class NetworkError(KenosisError): pass
class RpcProtocolError(KenosisError): pass

class _StaleInfo(Exception): pass

def RecursiveConversion(data, matcher, converter):
    try:
        matched = matcher(data)
    except AttributeError:
        matched = 0
    if matched:
        return converter(data)
    elif type(data) == type({}):
        d = {}
        for k, v in data.items():
            k = RecursiveConversion(data=k, matcher=matcher, converter=converter)
            d[k] = RecursiveConversion(data=v, matcher=matcher, converter=converter)
        return d
    elif type(data) in (type(tuple()), type([])):
        d = []
        for v in data:
            d.append(RecursiveConversion(data=v, matcher=matcher, converter=converter))
        return d
    else:
        return data

def ConvertAddressToStringRecursively(data):
    return RecursiveConversion(
        data=data, matcher=lambda x:isinstance(x, address.NodeAddressObject),
        converter=lambda x:str(x))

def ConvertStringToAddressRecursively(data):
    return RecursiveConversion(
        data=data, matcher=lambda x:x.startswith("address:"),
        converter=lambda x:address.NodeAddressObject(nodeAddress=x[len("address:"):]))

class NodeRpcFilter:
    def __init__(self, nodeKernel):
        self.nodeKernel_ = nodeKernel


def nameIsPrivate(name):
    return name.startswith("_") or name.endswith("_")

class RpcServerAdapter:
    def __init__(self, adaptee, nodeKernel, serviceName):
        """serviceName is None for top-level adapters"""
        self.adaptee_ = adaptee
        self.nodeKernel_ = nodeKernel
        if serviceName:
            assert not nameIsPrivate(serviceName), serviceName
        self.serviceName_ = serviceName
        self.extraBuiltinMethods_ = ["ping", "findNode"]

    def _listPublicMethod(self):
        return SimpleXMLRPCServer.list_public_methods(self.adaptee_) + self.extraBuiltinMethods_

    def __getattr__(self, name):
        if nameIsPrivate(name=name):
            raise AttributeError(name)
        
        return RpcServerAdapter(
            adaptee=getattr(self.adaptee_, name),
            nodeKernel=self.nodeKernel_,
            serviceName=self.serviceName_ or name)

    def findNode(self, rpcHeader, nodeAddressObject):
        rpcHeader = ConvertStringToAddressRecursively(data=rpcHeader)
        nodeAddressObject = ConvertStringToAddressRecursively(data=nodeAddressObject)

        self._processHeader(rpcHeader=rpcHeader, validateDestNodeAddress=False)

        sourceNetAddress = sourceNetAddressFrom(rpcHeader=rpcHeader)
        if netAddressIsPrivate(netAddress=sourceNetAddress):
            includePrivateAddresses = True
        else:
            includePrivateAddresses = False
        
        resultTuples = self.nodeKernel_.rpcFindNode(
            nodeAddressObject=nodeAddressObject, serviceName=self.serviceName_,
            includePrivateAddresses=includePrivateAddresses)
        if versionClientUsesServices(rpcHeader=rpcHeader):
            ret = {"nodes":resultTuples,
                   "nodeAddress": self.nodeKernel_.nodeAddressObject_,
                   "supportsService":self._supportsService()}
        else:
            ret = resultTuples

        return ConvertAddressToStringRecursively(data=ret)

    def ping(self, rpcHeader):
        rpcHeader = ConvertStringToAddressRecursively(data=rpcHeader)

        self._processHeader(rpcHeader=rpcHeader, validateDestNodeAddress=False)
        if versionClientUsesServices(rpcHeader=rpcHeader):
            ret = {"nodeAddress":self.nodeKernel_.nodeAddressObject_,
                   "supportsService":self._supportsService()}
        else:
            ret = self.nodeKernel_.nodeAddressObject_

        return ConvertAddressToStringRecursively(data=ret)
    
    def _supportsService(self):
        return not isinstance(self.adaptee_, NullHandler)
    
    def _processHeader(self, rpcHeader, validateDestNodeAddress):
        destNodeAddr = destNodeAddressObjectFrom(rpcHeader=rpcHeader)
        sourceNodeAddr = sourceNodeAddressObjectFrom(rpcHeader=rpcHeader)
        if validateDestNodeAddress:
            assert destNodeAddr == self.nodeKernel_.nodeAddressObject_ or \
                   destNodeAddr == NodeAddressObjectUnknown, \
                   "%s != %s" % (destNodeAddr, self.nodeKernel_.nodeAddressObject_)

        if sourceNodeAddr != self.nodeKernel_.nodeAddressObject_:
            self.nodeKernel_._updateRoutingTableWith(
                netAddress=sourceNetAddressFrom(rpcHeader=rpcHeader),
                nodeAddressObject=sourceNodeAddressObjectFrom(rpcHeader=rpcHeader),
                serviceName=self.serviceName_)
        assertRpcHeaderValid(rpcHeader=rpcHeader)

    def __call__(self, *args):
        args = ConvertStringToAddressRecursively(data=args)
        rpcHeader = args[0]
        self._processHeader(rpcHeader=rpcHeader, validateDestNodeAddress=True)

        class InvocationInfo:
            def __init__(self, rpcHeader):
                self.sourceNodeAddr_ = sourceNodeAddressObjectFrom(rpcHeader=rpcHeader).numericRepr()
            def sourceNodeAddr(self):
                return self.sourceNodeAddr_
        invocationInfo = InvocationInfo(rpcHeader=rpcHeader)

        otherArgs = args[1:]
        ret = self.adaptee_(invocationInfo, *otherArgs)
        return ConvertAddressToStringRecursively(data=ret)

class NullHandler:
    def __init__(self, serviceName):
        self.serviceName_ = serviceName
    def __getattr__(self, name):
        raise xmlrpclib.Fault("service %s is not supported" % self.serviceName_, 11)
    def __call__(self, *args):
        raise xmlrpclib.Fault("service %s is not supported" % self.serviceName_, 11)

class NodeRpcFrontend:
    def __init__(self, nodeKernel):
        self.nodeKernel_ = nodeKernel
        self.kenosis = RpcServerAdapter(
            adaptee=NodeRpcFilter(nodeKernel=nodeKernel),
            nodeKernel=self.nodeKernel_, serviceName="kenosis")

    def __getattr__(self, name):
        return RpcServerAdapter(adaptee=NullHandler(serviceName=name), nodeKernel=self.nodeKernel_, serviceName=name)
    
    def registerNamedHandler(self, name, handler):
        if nameIsPrivate(name=name):
            raise Exception("invalid handler: %s" % name)
        setattr(
            self, name,
            RpcServerAdapter(adaptee=handler, nodeKernel=self.nodeKernel_, serviceName=name))

    def _listMethods(self):
        ret = []
        for attrName in dir(self):
            attr = getattr(self, attrName)
            if isinstance(attr, RpcServerAdapter): 
                for methodName in attr._listPublicMethod():
                    ret.append("%s.%s" % (attrName, methodName))
        return ret

    def _methodHelp(self, method):
        for attrName in dir(self):
            attr = getattr(self, attrName)
            if isinstance(attr, RpcServerAdapter): 
                for methodName in attr._listPublicMethod():
                    n = "%s.%s" % (attrName, methodName)
                    if method == n:
                        realMethodProxy = getattr(attr, methodName)
                        assert callable(realMethodProxy)
                        realMethod = realMethodProxy.adaptee_
                        assert callable(realMethod)
                        func = realMethod.im_func
                        defaults = func.func_defaults
                        codeObject = func.func_code
                        argNames = list(codeObject.co_varnames)
                        argCount = codeObject.co_argcount
                        if argNames[0] == "self":
                            argNames = argNames[1:]
                        if argNames[0] == "invocationInfo":
                            argNames = argNames[1:]
                        # add the implicit rpcHeader
                        argNames.insert(0, "rpcHeader")
                        argCount = len(argNames)
                        import pydoc
                        return "%s: doc '%s' argCount %s, argNames %s, defaults %s" % (method,
                                                                                       pydoc.getdoc(realMethod),
                                                                                       argCount, argNames, defaults)

                        
        raise "no such method %s" % method
                              

class NodeXMLRPCRequestHandler(SimpleXMLRPCServer.SimpleXMLRPCRequestHandler):
    def do_POST(self):
        self.server.client_address = self.client_address
        return SimpleXMLRPCServer.SimpleXMLRPCRequestHandler.do_POST(self)

class DsThreadingMixIn(SocketServer.ThreadingMixIn):
    def process_request(self, request, client_address):
        """Start a new thread to process the request."""
        dsthread.runInThread(self.process_request_thread,
                             request, client_address)

class NodeXMLRPCServer(
    DsThreadingMixIn,
    SimpleXMLRPCServer.SimpleXMLRPCServer):
    def __init__(self, addr):
        self.allow_reuse_address = True
        SimpleXMLRPCServer.SimpleXMLRPCServer.__init__(self, requestHandler=NodeXMLRPCRequestHandler, logRequests=0, addr=addr)

    def _dispatch(self, method, params):
        try:
            host, port = self.client_address[:2]
            if not method.startswith("system"):
                rpcHeader = params[0]
                assertRpcHeaderMightBeValid(rpcHeader=rpcHeader)
                rpcHeader["sourceNetHost"] = host
            return SimpleXMLRPCServer.SimpleXMLRPCServer._dispatch(self, method, params)
        except:
            dsunittest.traceException("converting to xmlrpclib.Fault")
            e = sys.exc_info()[1]
            raise RpcProtocolError(str(e))

    def system_methodSignature(self, method):
        try:
            # check to see if a matching function has been registered
            func = self.funcs[method]
        except KeyError:
            if self.instance is not None:
                # check for a _dispatch method
                # not supported yet
                #                 if hasattr(self.instance, '_dispatch'):
                #                     return "_dispatch signatures not supported"
                #                 else:
                    assert not hasattr(self.instance, '_dispatch')
                    try:
                        func = SimpleXMLRPCServer.resolve_dotted_attribute(
                            self.instance,
                            method
                            )
                    except AttributeError:
                        raise "no such method: %s" % method

        isMemberFunc = False
        assert isinstance(func, RpcServerAdapter) 
        if isinstance(func, RpcServerAdapter): 
            func = func.adaptee_.im_func
            isMemberFunc = True
#         else:
#              try:
#                  func = func.im_func
#                  isMemberFunc = True
#              except AttributeError:
#                  isMemberFunc = False
        defaults = func.func_defaults
        codeObject = func.func_code
        argNames = list(codeObject.co_varnames)
        argCount = codeObject.co_argcount
        if isMemberFunc:
            assert argNames[0] == "self" and argNames[1] == "invocationInfo"
            argNames = argNames[2:]
            argCount -= 2

        # add the implicit rpcHeader
        argNames.insert(0, "rpcHeader")

        returnType = "unknown"
        signature = [returnType, "struct"] + (["unknown"] * argCount)


        #return "func is %s argCount %s, argNames %s, defaults %s" % (func, argCount, argNames, defaults)
        return signature
        
class RpcClientAdapter:
    def __init__(self, serverProxy, rpcHeaderAdditions):
        self.serverProxy_ = serverProxy
        self.rpcHeaderAdditions_ = rpcHeaderAdditions
        
    def __getattr__(self, name):
        gottenAttr = getattr(self.serverProxy_, name)
        return RpcClientAdapter(serverProxy=gottenAttr,
                                rpcHeaderAdditions=self.rpcHeaderAdditions_)
    def __call__(self, *args):
        rpcHeader = args[0]
        rpcHeader = rpcHeader.update(self.rpcHeaderAdditions_)
        args = ConvertAddressToStringRecursively(args)
        try:
            ret = self.serverProxy_(*args)
        except xmlrpclib.Fault, f:
            f.faultString = "%s (%s)" % (rpcHeader, f.faultString)
            raise
        return ConvertStringToAddressRecursively(data=ret)
        
def RpcServerProxyFactory(netAddress, port, timeout):
    uri = "http://%s" % netAddress
    serverProxy = xmlrpclib.ServerProxy(
        uri,transport=xmlrpclib_transport.HTTPTransport(uri, socketTimeout=timeout))
    return RpcClientAdapter(
        serverProxy=serverProxy, rpcHeaderAdditions={"sourceNetPort": port})

class NodeServer:
    def __init__(self, nodeKernel, ports):
        self.frontend_ = nodeKernel._frontend()

        if ports is None:
            portsToTry = defaultPorts
        else:
            portsToTry = ports

        for port in portsToTry:
            try:
                self.xmlrpcServer_ = NodeXMLRPCServer(addr=('',port))
            except socket.error, e:
                if port == portsToTry[-1]:
                    dsunittest.traceException("could not find a port in portsToTry %s" % portsToTry)
                    raise
            else:
                break
        self.port_ = port
        
        self.xmlrpcServer_.register_introspection_functions()
        self.xmlrpcServer_.register_multicall_functions()
        self.xmlrpcServer_.register_instance(self.frontend_)
        # This is a lame hack so that we can work with older versions of xmlrpclib.
        self.xmlrpcServer_.allow_dotted_names=True

    def port(self):
        return self.port_
    
    def serveOneRequest(self):
        self.xmlrpcServer_.handle_request()
    
# Node addresses in Node's public interface are always strings.
class Node(ui.GenericUi):
    def __init__(
        self,
        nodeAddress=None, configPath=None,
        ports=None,
        serve=True, stopEvent=None,
        bootstrapNetAddress=defaultBootstrapNetAddress,
        runThreadedFunc=None,
        useUpnp=True, useZeroconf=True):

        """creates a Kenosis Node. all arguments are optional.

        - do not pass both of nodeAddress and configPath.

        - configPath need not exist; it will be created as necessary.

        - ports: an array or tuple of ports to try to bind to. The
        first one that can be bound to will be used.

        - serve: if true the new node will automatically respond to
        requests from other nodes. The only reason to turn this off is
        allow unit testing.

        - stopEvent: changes automatic serving (if serve is
        True) or the serving started by threadedServeUntilEvent (if
        the provided event is None) to use this event. This is useful
        if you want to be able to stop the service later.

        - bootstrapNetAddress: the net address and port (as a string) of
        the node to bootstrap form. Pass None to avoid bootstrapping.

        - runThreadedFunc: sometimes (such as when you are using
        twisted) you want to avoid using threads. This parameter
        defuls to None but if you provide it it should be a function
        that accepts a callable. When provided (in addition to
        serve=False), kenosis will not create any threads of its own.

        """

        ui.GenericUi.__init__(self)

        assert not (configPath and nodeAddress)

        self.configPath_ = configPath
        if configPath and os.path.exists(configPath):
            stateDict = dsfile.fileObject(path=configPath)
            nodeAddress = stateDict["nodeAddress"]
            routingTuples = stateDict["routingTuples"]
            savedBootstrapTuples = stateDict.get("bootstrapTuples", [])
        else:
            routingTuples = []
            savedBootstrapTuples = []
            
        if nodeAddress is None:
            realNodeAddressObject = address.randomAddress()
        else:
            assert address.isTextAddress(string=nodeAddress), \
                   "invalid nodeAddressObject (string form): %s" % nodeAddress
            realNodeAddressObject = address.NodeAddressObject(nodeAddress=nodeAddress)
            
        # Leaving this as 0 will mean that we save as soon as the fist
        # change is made
        self.lastSaveTime_ = 0

        if useUpnp:
            self.upnpPlugin_ = upnp_plugin.UpnpPlugin(node=self)
        else:
            self.upnpPlugin_ = None

        if useZeroconf:
            self.zeroconfPlugin_ = zeroconf_plugin.ZeroconfPlugin(node=self)
        else:
            self.zeroconfPlugin_ = None

        self.nodeKernel_ = NodeKernel(
            nodeAddressObject=realNodeAddressObject, serverProxyFactory=self.__newServerProxy,
            runThreadedFunc=runThreadedFunc)
        self.nodeKernel_.bootstrapTuples_ = savedBootstrapTuples
        self.server_ = NodeServer(nodeKernel=self.nodeKernel_, ports=ports)
        self.internalPort_ = self.server_.port()
        self.externalPort_ = self.internalPort_
        if self.upnpPlugin_:
            self.upnpPlugin_.onListeningOnInternalPort(internalPort=self.internalPort_)
        if self.zeroconfPlugin_:
            self.zeroconfPlugin_.onListeningOnInternalPort(internalPort=self.internalPort_)
            
        if stopEvent is not None:
            self.stopEvent_ = stopEvent
        else:
            self.stopEvent_ = threading.Event()

        for nodeAddressObject, netAddress, serviceName in routingTuples:
            self.nodeKernel_._updateRoutingTableWith(
                nodeAddressObject=nodeAddressObject, netAddress=netAddress, serviceName=serviceName)
        
        if serve:
            self.threadedServeUntilEvent(event=self.stopEvent_)

        if bootstrapNetAddress is not None:
            assert bootstrapNetAddress, repr(bootstrapNetAddress)
            while not self.stopEvent_.isSet():
                try:
                    self.nodeKernel_._trace(
                        "attempting to boostrap from address %s" % bootstrapNetAddress)
                    result = self.bootstrap(netAddress=bootstrapNetAddress)
                except NetworkErrorClasses:
                    dsunittest.traceException(
                        "could not bootstrap from address %s" % bootstrapNetAddress)
                    time.sleep(1)
                else:
                    self.nodeKernel_._trace(
                        "succesfully boostrapped from address %s (result %s)" %
                        (bootstrapNetAddress, result))
                    break

    def save(self, configPath=None):
        """save to the specified configPath, using the configPath
        passed to __init__ if None is passed"""

        if configPath is None:
            assert self.configPath_ is not None
            configPath = self.configPath_
            
        routingTuples = []

        for serviceName in self.nodeKernel_.serviceBuckets_.keys():
            nodeInfos = self.nodeKernel_._nodeInfosInBucketAndSuccessors(
                bucketIndex=0, serviceName=serviceName)

            routingTuples.extend([
                (n.nodeAddressObject(), n.netAddress(), serviceName) for a,b,n in nodeInfos])

        stateDict = { "nodeAddress": self.nodeAddress(),
                      "version": protocolVersion,
                      "routingTuples": routingTuples,
                      "bootstrapTuples": self.nodeKernel_.bootstrapTuples_}

        dsfile.setFileObject(path=configPath, object=stateDict)
        
    def __newServerProxy(self, netAddress, timeout):
        return RpcServerProxyFactory(netAddress=netAddress, port=self.externalPort_, timeout=timeout)

    # setup methods
    def registerService(self, name, handler):
        dsunittest.trace("registerService: name=%s" % name)
        self.server_.frontend_.registerNamedHandler(name=name, handler=handler)
        self.nodeKernel_.servicesToBootstrap_.append(name)
    registerNamedHandler = registerService

    def registerStreamService(self, name, streamType, streamPort, handler=None):
        """
        register a service that supports a TCP or UDP-based service:
        - streamType should be one of 'TCP' or 'UDP'
        - streamPort should be the port that the service is listening on
        - if you don't pass the optional handler argument, we'll construct a handler for you
          that supports a tcpPort() or udpPort() (or both) argument as necessary
        """
        class StreamServiceHandler:
            def __init__(self, port):
                self.port_ = port
        class TCPStreamServiceHandler(StreamServiceHandler):
            def tcpPort(self, invocationInfo):
                return self.port_
        class UDPStreamServiceHandler(StreamServiceHandler):
            def udpPort(self, invocationInfo):
                return self.port_
        
        assert streamType in ("TCP", "UDP")
        if self.upnpPlugin_:
            newPort = self.upnpPlugin_.notifyNewStreamService(name=name, streamPort=streamPort, streamType=streamType)
            streamPort = newPort
        if handler is None:
            klass = locals()["%sStreamServiceHandler" % streamType]
            handler = klass(port=streamPort)
        self.registerService(name=name, handler=handler)
        return streamPort

    def bootstrap(self, netAddress):
        return self.nodeKernel_.bootstrap(netAddress=netAddress, serviceName="kenosis")

    def stepUntilEvent(self, event):
        while not event.isSet():
            self.step()
            event.wait(1.0)

    def step(self):
        # There is a race condtion here where we might lose an update
        # to the routing table but that does not seem like a big deal.
        if self.configPath_ is not None and self.nodeKernel_.needToSave_ and self.lastSaveTime_ + 59 < dstime.time():
            self.lastSaveTime_ = dstime.time()
            self.nodeKernel_.needToSave_ = False
            self.save()
        self.nodeKernel_.step()

    def stop(self):
        self.stopEvent_.set()
        self.nodeKernel_.taskList_.stop(wait=True)
        if self.zeroconfPlugin_:
            self.zeroconfPlugin_.stop()

    def serveOneRequest(self):
        return self.server_.serveOneRequest()

    def serveUntilEvent(self, event):
        while not event.isSet():
            self.serveOneRequest()

    def threadedServeUntilEvent(self, event=None):
        if event is None:
            event = self.stopEvent_
        #self.thread_ = dsthread.newThread(function=self.serveUntilEvent, params=(event,))
        #self.stepThread_ = dsthread.newThread(function=self.stepUntilEvent, params=(event,))
        dsthread.runInThread(self.stepUntilEvent, event)
        dsthread.runInThread(self.serveUntilEvent, event)
        
    def rpc(self, nodeAddress):
        nodeAddressObject = address.NodeAddressObject(nodeAddress=nodeAddress)
        return self.nodeKernel_.rpc(nodeAddressObject=nodeAddressObject)

    def findNode(self, nodeAddress, serviceName):
        """find the netAddress ('host:port') for a given nodeAddress"""
        nodeAddressObject = address.NodeAddressObject(nodeAddress=nodeAddress)
        if nodeAddressObject == self.nodeKernel_.nodeAddressObject_:
            return "127.0.0.1:%s" % self.port()
        else:
            return self.nodeKernel_._nextHopNetAddressForNodeAddressObject(
                nodeAddressObject=nodeAddressObject, serviceName=serviceName)

    def findNodeAsync(self, nodeAddress, serviceName, callback):
        """find the netAddress ('host:port') for a given
        nodeAddress. Instead of returning it call the callback,
        passing this as 'netaddress'"""
        def lf():
            kwargs = dict(nodeAddress=nodeAddress, serviceName=serviceName)
            try:
                dsunittest.trace("Starting findNodeAsync for %s/%s" % (nodeAddress, serviceName))
                result = self.findNode(**kwargs)
                dsunittest.trace("Finished findNodeAsync for %s/%s" % (nodeAddress, serviceName))
                exc_info = None
            except:
                dsunittest.trace("Error from findNodeAsync for %s/%s" % (nodeAddress, serviceName))
                result = None
                exc_info = sys.exc_info()
            callback(kwargs=kwargs, result=result, exc_info=exc_info)
        dsunittest.trace("Requested findNodeAsync for %s/%s" % (nodeAddress, serviceName))
        self.nodeKernel_.runThreadedFunc_(lf)

    def port(self):
        """Return the local or internal port that the node is bound
        to. In the case of NAT this may be different than the external
        port."""
        return self.internalPort_

    def findNearestNodes(self, nodeAddress, serviceName):
        """Returns an array of pairs of node address string and the
        network address and port of the node with that address."""
        nodeAddressObject = address.NodeAddressObject(nodeAddress=nodeAddress)
        nodeAddressObjectNetAddressPairs = self.nodeKernel_._findNearestNodeAddressObjectNetAddressTuples(
            nodeAddressObject=nodeAddressObject, serviceName=serviceName)
        return [(nodeAddressObject.numericRepr(), netAddress) for
                nodeAddressObject, netAddress in nodeAddressObjectNetAddressPairs]

    def nodeAddress(self):
        return self.nodeKernel_.nodeAddressObject_.numericRepr()

    def setExternalPort(self, externalPort):
        dsunittest.trace("Changing external port from %s to %s" % (self.externalPort_, externalPort))
        if self.externalPort_ != externalPort:
            self.externalPort_ = externalPort

            for serviceName in self.nodeKernel_.serviceBuckets_.keys():
                self.nodeKernel_.servicesToBootstrap_.append(serviceName)
    
class NodeKernel:
    def __init__(self, nodeAddressObject, serverProxyFactory, runThreadedFunc):
        self.nodeAddressObject_ = nodeAddressObject

        self.serviceBuckets_ = {}
        self.bucketLock_ = threading.RLock()
        self.constantsK_ = 20
        self.constantsAlpha_ = 3
        self.staleInfoTime_ = staleInfoTime
        self.needPingPairs_ = []
        self.serverProxyFactory_ = serverProxyFactory
        self.frontend_ = NodeRpcFrontend(nodeKernel=self)

        if runThreadedFunc:
            self.runThreadedFunc_ = runThreadedFunc
        else:
            self.taskList_ = task.TaskList(maxThreads=10 * self.constantsAlpha_)
            self.taskList_.start(wait=0)
            self.runThreadedFunc_ = self.taskList_.addCallableTask

        self.newResultsEvent_ = dsthread.MultithreadEvent()
        self.results_ = {}
        self.bootstrapTuples_ = []
        self.servicesToBootstrap_ = []

        self.needToSave_ = False

    def __repr__(self):
        return "NodeKernel(%s)" % self.nodeAddressObject_
    
    def rpc(self, nodeAddressObject):
        rpcHeader=self._rpcHeaderFor(nodeAddressObject=nodeAddressObject)
        if nodeAddressObject == self.nodeAddressObject_:
            rpcHeader["sourceNetHost"] = "localhost"
            rpcHeader["sourceNetPort"] = 123
            
        return Rpc(rpcHeader=rpcHeader, toplevelRpc=None, attributeNames=[], nodeKernel=self)

    def rpcFindNode(self, nodeAddressObject, serviceName, includePrivateAddresses):
        if nodeAddressObject == self.nodeAddressObject_:
            return []
        bucketI = self._bucketIndexForNodeAddressObject(nodeAddressObject=nodeAddressObject)
        ret = []
        for a, b, ni in self._nodeInfosInBucketAndSuccessors(bucketIndex=bucketI, serviceName=serviceName):
            if not ni.shouldCommunicateWithNode():
                continue
            netAddress = ni.netAddress()
            if not includePrivateAddresses:
                if netAddressIsPrivate(netAddress=netAddress):
                    continue
            ret.append((ni.nodeAddressObject(), netAddress))
            if len(ret) >= self.constantsK_:
                break
        return ret

    def _rpcHeaderFor(self, nodeAddressObject):
        return newRpcHeader(sourceNodeAddressObject=self.nodeAddressObject_, destNodeAddressObject=nodeAddressObject)

    def _bucketIndexForNodeAddressObject(self, nodeAddressObject):
        assert nodeAddressObject != self.nodeAddressObject_
        assert nodeAddressObject != NodeAddressObjectUnknown
        distance = address.distance(address0=self.nodeAddressObject_, address1=nodeAddressObject)
        for i in range(address.addressLengthInBits):
            if 2**i <= distance and distance < 2**(i+1):
                return i
        raise address.InvalidAddressError("distance is surprisingly large: %s" % (distance))

    # return constantsK_ nearest node infos
    def _findNearestNodeAddressObjectNetAddressTuples(self, nodeAddressObject, serviceName):
        self._trace(text="_findNearestNodeAddressObjectNetAddressTuples >>: %s" % nodeAddressObject, prio=1)
        try:
            ret = self.__findNodeNetAddress(nodeAddressObject=nodeAddressObject, requireExactMatch=False,
                                            serviceName=serviceName)
            def sorter(a,b,nodeAddressObject=nodeAddressObject):
                distA = address.distance(a[0], nodeAddressObject)
                distB = address.distance(b[0], nodeAddressObject)
                r = cmp(distA, distB)
                return r

            ret.sort(sorter)
        finally:
            self._trace(
                text="_findNearestNodeAddressObjectNetAddressTuples <<: %s" % nodeAddressObject,
                prio=1)
        return ret
        
    def _findNodeNetAddress(self, nodeAddressObject, serviceName):
        self._trace(text="_findNodeNetAddress >>: %s" % nodeAddressObject, prio=1)
        ret = None
        try:
            ret = self.__findNodeNetAddress(
                nodeAddressObject=nodeAddressObject, serviceName=serviceName, requireExactMatch=True)
        finally:
            self._trace(text="_findNodeNetAddress <<: %s" % ret, prio=1)
        return ret

    def __findNodeNetAddress(self, nodeAddressObject, serviceName, requireExactMatch):

        """If requireExactMatch is true returns the net address of
        the node with nodeAddressObject or raises NodeNotFound.

        If requireExactMatch is not true returns an array of
        (nodeAddressObject, netAddress) tuples in order of increasing
        distance from the requested nodeAddressObject."""

        if nodeAddressObject == self.nodeAddressObject_:
            bucketI = 0
        else:
            bucketI = self._bucketIndexForNodeAddressObject(nodeAddressObject=nodeAddressObject)
        # Maps nodeAddress, netAddress -> nodeInfo
        currentDict = {}
        successDict = {}
        successNodeInfo = None
        errorSet = Set()
        realQueue = dsqueue.PriorityQueue(0)
        mergeQueue = GrowingQueue(
            realQueue=realQueue,
            iterator=self._nodeInfosInBucketAndSuccessors(bucketI, serviceName=serviceName))
        numCurrentRequests = 0
        while len(successDict) < self.constantsK_:
            now = dstime.time()
            numCurrentRequests = len([t for x,t in currentDict.values() if now - t <= kenosisFindNodesTimeout])
            if numCurrentRequests < len(currentDict):
                self._trace("numCurrentRequests %s < len(currentDict) %s" % (numCurrentRequests, len(currentDict)))
            while numCurrentRequests < self.constantsAlpha_ and not mergeQueue.empty():
                bucketIndex, freshness, nodeInfo = mergeQueue.get()
                #self._trace("mergeQueue get: %s" % repr(nodeInfo))
                if not nodeInfo.shouldCommunicateWithNode():
                    #self._trace("  current node is marked not shouldCommunicateWithNode")
                    continue
                currentNodeAddressObject = nodeInfo.nodeAddressObject()
                currentNetAddress = nodeInfo.netAddress()
                if currentNodeAddressObject in successDict:
                    self._trace("  current node is in success dict")
                    continue
                currentTuple = (currentNodeAddressObject, currentNetAddress)
                if (currentTuple in currentDict) or (currentTuple in errorSet):
                    self._trace("  current node, net address is in current, error dict")
                    continue

                currentDict[currentTuple] = (nodeInfo, dstime.time())
                numCurrentRequests += 1
                del nodeInfo
                
            if numCurrentRequests == 0 and mergeQueue.empty():
                #self._trace("break because currentDict is empty and mergeQueue is empty")
                break

            self.newResultsEvent_.clear()
            anyCommandsCompleted = False
            for calledTuple, (calledNodeInfo, timeAdded) in currentDict.items():
                calledNodeAddressObject, calledNetAddress = calledTuple
                try:
                    resultDict = self._nodeCommandResult(
                        netAddress=calledNetAddress, nodeAddressObject=calledNodeAddressObject,
                        commandName="findNode", commandArgs=(nodeAddressObject, serviceName))
                except _StaleInfo:
                    continue
                except NetworkErrorClasses:
                    calledNodeInfo.notifyFailedContact()
                    dsunittest.traceException(text="Error while talking to node %s" % repr(calledTuple));
                    resultDict = None
                anyCommandsCompleted = True
                del currentDict[calledTuple]
                #self._trace("called %s, foundNodes=%s (desired=%s)" % (repr(calledTuple),
                #                                                            resultDict,
                #                                                            nodeAddressObject), prio=1)
                if resultDict is not None:
                    # The default value is for backward compatibility with 0.93 and before.
                    responseNodeAddressObject = resultDict.get("nodeAddress", calledNodeAddressObject)

                    if responseNodeAddressObject != self.nodeAddressObject_:
                        self._updateRoutingTableWith(
                            nodeAddressObject=responseNodeAddressObject,
                            netAddress=calledNetAddress, serviceName=serviceName)
                    if responseNodeAddressObject == nodeAddressObject:
                        if requireExactMatch:
                            # we heard back from the right node,
                            # regardless of whom we tried to call.
                            return calledNetAddress

                    result = resultDict["nodes"]
                    for foundNodeAddressObject, netAddress in result:
                        if foundNodeAddressObject == self.nodeAddressObject_:
                            continue
                        resultNodeInfo = NodeInfo(
                            nodeAddressObject=foundNodeAddressObject, netAddress=netAddress)
                        resultTuple = (0, 0, resultNodeInfo)
                        #self._trace("adding resultTuple %s to realQueue %s" % (resultTuple, realQueue))
                        realQueue.put(resultTuple)
                    if responseNodeAddressObject != calledNodeAddressObject:
                        # We managed to talk to someone, but it was
                        # not the node that we were expecting. Mark
                        # the node that we tried to talk to as an
                        # error to prevent us from trying to reach it
                        # again, since we can't put it in the success
                        # list since it was not really at that net
                        # address.
                        errorSet.add((calledNodeAddressObject, calledNetAddress))
                    if resultDict["supportsService"]:
                        successDict[responseNodeAddressObject] = calledNetAddress
                    else:
                        errorSet.add((responseNodeAddressObject, calledNetAddress))
                    if len(successDict) == self.constantsK_:
                        break
                else:
                    errorSet.add((calledNodeAddressObject, calledNetAddress))

            # If no commands have completed then there is nothing to
            # do until one does complete.
            if not anyCommandsCompleted:
                self._trace("Waiting on newResultsEvent_")
                self.newResultsEvent_.wait(kenosisFindNodesTimeout) # ===
                self._trace("Finished waiting on newResultsEvent_")
        assert numCurrentRequests == 0 or len(successDict) == self.constantsK_
        if requireExactMatch:
            assert not nodeAddressObject in successDict
            raise NodeNotFound(nodeAddressObject)
        else:
            return successDict.items()

    def _bucketsFor(self, serviceName):
        self.bucketLock_.acquire()
        try:
            if not serviceName in self.serviceBuckets_:
                self.serviceBuckets_[serviceName] = [[] for x in range(address.addressLengthInBits)]
                for nodeAddressObject, netAddress in self.bootstrapTuples_:
                    self._updateRoutingTableWith(
                        nodeAddressObject=nodeAddressObject, netAddress=netAddress,
                        serviceName=serviceName)
            return self.serviceBuckets_[serviceName]
        finally:
            self.bucketLock_.release()

    def __threadsafeCopyOfBucket(self, bucketIndex, serviceName):
        self.bucketLock_.acquire()
        try:
            buckets = self._bucketsFor(serviceName)
            return copy.copy(buckets[bucketIndex])
        finally:
            self.bucketLock_.release()
            
    def _nodeInfosInBucketAndSuccessors(self, bucketIndex, serviceName):
        for i in range(bucketIndex, address.addressLengthInBits):
            for nodeInfo in self.__threadsafeCopyOfBucket(bucketIndex=i, serviceName=serviceName):
                yield (i, nodeInfo.timeSinceLastSuccessfulContact(), nodeInfo)
        for i in range(bucketIndex-1, 0-1, -1):
            for nodeInfo in self.__threadsafeCopyOfBucket(bucketIndex=i, serviceName=serviceName):
                yield (i, nodeInfo.timeSinceLastSuccessfulContact(), nodeInfo)
        
    def _nextHopNetAddressForNodeAddressObject(self, nodeAddressObject, serviceName):
        ni = self._nodeInfoForNodeAddressObject(
            nodeAddressObject=nodeAddressObject, serviceName=serviceName)
        if ni:
            return ni.netAddress()
                                          
        netAddress = self._findNodeNetAddress(nodeAddressObject=nodeAddressObject, serviceName=serviceName)
        return netAddress

    def _serverProxyForNodeAddressObject(self, nodeAddressObject, serviceName):
        if nodeAddressObject == self.nodeAddressObject_:
            return self.frontend_

        netAddress = self._nextHopNetAddressForNodeAddressObject(
            nodeAddressObject=nodeAddressObject, serviceName=serviceName)
        return self._serverProxyForNetAddress(netAddress=netAddress, timeout=userRpcTimeout)

    def _serverProxyForNetAddress(self, netAddress, timeout):
        return self.serverProxyFactory_(netAddress=netAddress, timeout=timeout)

    def _updateRoutingTableWith(self, nodeAddressObject, netAddress, serviceName):
        self.bucketLock_.acquire()
        try:
            bucketIndex = self._bucketIndexForNodeAddressObject(nodeAddressObject)
            bucket = self._bucketsFor(serviceName=serviceName)[bucketIndex]

            for nodeInfo in bucket:
                if nodeInfo.nodeAddressObject() == nodeAddressObject:
                    nodeInfo.updateFreshness(newNetAddress=netAddress)
                    break
            else:
                nodeInfo = NodeInfo(nodeAddressObject=nodeAddressObject, netAddress=netAddress)
                if len(bucket) < self.constantsK_:
                    bucket.append(nodeInfo)
                else:
                    toRemoveNodeInfo = bucket[-1]
                    if toRemoveNodeInfo.isStale():
                        bucket[-1] = nodeInfo
                    else:
                        toInsertTuple = (nodeInfo, bucket, serviceName)
                        self.needPingPairs_.append(toInsertTuple)
                    return
            self._sortBucket(bucket=bucket)
        finally:
            self.bucketLock_.release()
        self.needToSave_ = True


    def _considerServiceBootstraps(self):
        for serviceName in self.servicesToBootstrap_:
            for nodeAddressObject, netAddress in self.bootstrapTuples_:
                try:
                    self.bootstrap(netAddress=netAddress, serviceName=serviceName)
                except NetworkErrorClasses, e:
                    dsunittest.traceException(
                        text="Exception while considering service bootstraps for service %s on host %s" %
                        (serviceName, netAddress))
                    return
        self.servicesToBootstrap_ = []
            
    def _considerNeedPingPairs(self):
        for newNi, bucket, serviceName in self.needPingPairs_:
            oldNi = bucket[-1]
            try:
                result = self._pingNode(nodeAddressObject=oldNi.nodeAddressObject(),
                                        netAddress=oldNi.netAddress(),
                                        serviceName=serviceName)
                assert result
            except NetworkErrorClasses:
                self.bucketLock_.acquire()
                try:
                    bucket.remove(oldNi)
                    bucket.append(newNi)
                finally:
                    self.bucketLock_.release()
            else:
                oldNi.updateFreshness()
            self._sortBucket(bucket=bucket)
        self.needPingPairs_ = []

    def _sortBucket(self, bucket):
        self.bucketLock_.acquire()
        try:
            # The goal is to sort all stale node infos to the end, and
            # before that to put less fresh ones (higher freshness
            # value) after more fresh ones.
            def comparator(x, y):
                return cmp(x.timeSinceLastSuccessfulContact(), y.timeSinceLastSuccessfulContact())
            bucket.sort(comparator)
        finally:
            self.bucketLock_.release()

    def step(self):
        self._considerNeedPingPairs()
        self._considerServiceBootstraps()
        self._maybeRefreshBuckets()

    def _maybeRefreshBuckets(self):
        for serviceName, bucketList in self.serviceBuckets_.items():
            for bucketIndex, bucket in enumerate(bucketList):
                if len(bucket) == 0:
                    continue
                for nodeInfo in bucket:
                    if nodeInfo.timeSinceLastAttemptedContact() < maxTimeBetweenBucketOperations:
                        break
                else:
                    nodeInfo = random.choice(bucket)
                    dsunittest.trace(
                        "Perfoming findNearestNodes as part of refreshing bucket %s in service %s" %
                        (bucketIndex, serviceName))
                    self._findNearestNodeAddressObjectNetAddressTuples(
                        nodeAddressObject=nodeInfo.nodeAddressObject(), serviceName=serviceName)
                    
    def _nodeInfoForNodeAddressObject(self, nodeAddressObject, serviceName):
        """Returns None or a NodeInfo. Does not raise NodeNotFound"""

        bucketIndex = self._bucketIndexForNodeAddressObject(nodeAddressObject)
        self.bucketLock_.acquire()
        try:
            for ni in self._bucketsFor(serviceName=serviceName)[bucketIndex]:
                if ni.nodeAddressObject() == nodeAddressObject:
                    return ni
            return None
        finally:
            self.bucketLock_.release()

    def _pingNode(self, nodeAddressObject, netAddress, serviceName):
        self._trace(
            text="_pingNode >>: %s, %s, %s" %
            (nodeAddressObject, netAddress, serviceName), prio=1)
        sp = self._serverProxyForNetAddress(netAddress=netAddress, timeout=kenosisRpcNetworkConnectionTimeout)
        sp = getattr(sp, serviceName)
        resultDict = sp.ping(self._rpcHeaderFor(nodeAddressObject=nodeAddressObject))
        if nodeAddressObject != NodeAddressObjectUnknown:
            assert resultDict["nodeAddress"] == nodeAddressObject, \
                   "%s != %s" % (resultDict["nodeAddress"], nodeAddressObject)
        self._trace(text="_pingNode <<: %s" % nodeAddressObject, prio=1)
        return resultDict

    def _callRemoteFindNode(
        self, nextHopNodeAddressObject, nextHopNetAddress, nodeAddressObject, serviceName):
        self._trace(text="_callRemoteFindNode >>: %s" % (repr(locals())), prio=1)
        sp = self._serverProxyForNetAddress(netAddress=nextHopNetAddress, timeout=kenosisRpcNetworkConnectionTimeout)
        sp = getattr(sp, serviceName)
        ret = sp.findNode(
            self._rpcHeaderFor(nodeAddressObject=nextHopNodeAddressObject),
            nodeAddressObject)
        self._trace(text="_callRemoteFindNode (%s results)<<" % len(ret), prio=1)
        return ret

    def bootstrap(self, netAddress, serviceName):
        try:
            self._trace(text="bootstrap >>: %s:%s" % (serviceName, netAddress), prio=1)
            resultDict = self._pingNode(nodeAddressObject=NodeAddressObjectUnknown,
                                        netAddress=netAddress, serviceName=serviceName)
            nodeAddressObject = resultDict["nodeAddress"]
            if nodeAddressObject == self.nodeAddressObject_:
                self._trace(
                    "NodeKernel.bootstrap returning false because pinged node has my address")
                return False
            else:
                for otherServiceName in self.serviceBuckets_.keys():
                    self._updateRoutingTableWith(
                        netAddress=netAddress, nodeAddressObject=nodeAddressObject,
                        serviceName=otherServiceName)

                toAppend = (nodeAddressObject, netAddress)
                if not toAppend in self.bootstrapTuples_:
                    self.bootstrapTuples_.append(toAppend)
                return True
        finally:
            self._trace(text="bootstrap <<: %s:%s" % (serviceName, netAddress), prio=1)

    def _frontend(self):
        return self.frontend_


    def _nodeCommandResult(self, nodeAddressObject, netAddress, commandName, commandArgs=()):
        #self._trace("_nodeCommandResult(%s)" % locals())
        key = (nodeAddressObject, netAddress, commandName, commandArgs)
        try:
            resultInfo = self.results_[key]
        except KeyError:
            pass
        else:
            if resultInfo["pending"]:
                raise _StaleInfo()
            if dstime.time() - resultInfo["time"] < self.staleInfoTime_:
                try:
                    return resultInfo["result"]
                except KeyError:
                    raise resultInfo["error"]
            else:
                self._trace("resultInfo %s is stale" % resultInfo)
        self.results_[key] =  {"pending": True}
        self._addWork(
            nodeAddressObject=nodeAddressObject, netAddress=netAddress,
            commandName=commandName, commandArgs=commandArgs)
        raise _StaleInfo()

    def _setNodeCommandResult(self, nodeAddressObject, netAddress, commandName, commandArgs,
                              result=None, error=None):
        key = (nodeAddressObject, netAddress, commandName, commandArgs)
        resultInfo = {"time":dstime.time(), "pending":False}
        if error:
            resultInfo["error"] = error
        else:
            resultInfo["result"] = result
        self.results_[key] = resultInfo
        self._trace("set resultInfo %s for key %s" % (resultInfo,key))
        self.newResultsEvent_.set()

    def _addWork(self, nodeAddressObject, netAddress, commandName, commandArgs=()):
        self._trace("> addWork(): %s" % ((nodeAddressObject, netAddress, commandName, commandArgs),))
        if commandName == "findNode":
            work = self._callRemoteFindNode
        else:
            # For some reason this exception cannot be caught when it
            # has a space in it, though other strings can be.
            raise "invalidcommandName"

        def lf(work=work, args=commandArgs, nodeAddressObject=nodeAddressObject, netAddress=netAddress):
            try:
                result = work(nodeAddressObject, netAddress, *args)
                error = None
            except NetworkErrorClasses, e:
                error = e
                result = None
            self._setNodeCommandResult(
                nodeAddressObject=nodeAddressObject, netAddress=netAddress,
                commandName=commandName,
                commandArgs=commandArgs,
                result=result,
                error=error)
                
        self.runThreadedFunc_(lf)

    def _trace(self, text, prio=1):
        dsunittest.trace(text="%s: %s" % (self, text), prio=prio)

if __name__ == "__main__":
    n = Node(bootstrapNetAddress=None)
    n2 = Node(bootstrapNetAddress=None)
    n2.bootstrap("localhost:%s" % n.port())
