import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName("node.py")

from ds import dsqueue
from ds import message
from ds import mocktask
from ds import dsfile
from ds import dstime
from ds import task
from kenosis import address
from kenosis import node

RealTaskList = task.TaskList
import gc
from ds import Queue
import random
import socket
import tempfile
import threading
import time
import xmlrpclib

socket.setdefaulttimeout(0.5)

class MockKenosis:
    def __init__(self, parent):
        self.parent_ = parent
    knownNodes = [(address.stringToAddress("1000"),"b:c")]
        
    def findNode(self, rpcHeader, nodeAddressObject):
        if self.parent_:
            self.parent_.nodesCalled_.append(nodeAddressObject)
        return {"supportsService": True, "nodes":self.knownNodes}

    def ping(self, rpcHeader):
        return {"supportsService": True, "nodeAddress":rpcHeader["destNodeAddress"]}

class MockMessiah:
    def __init__(self, mockKenosis):
        self.mockKenosis_ = mockKenosis
        
    def test(self, rpcHeader, arg):
        return (rpcHeader, arg)
    def ping(self, rpcHeader):
        return self.mockKenosis_.ping(rpcHeader)
    def findNode(self, rpcHeader, nodeAddressObject):
        return self.mockKenosis_.findNode(rpcHeader, nodeAddressObject)
    
class MockServerProxy:
    def __init__(self, parent):
        self.kenosis = MockKenosis(parent=parent)
        self.messiah = MockMessiah(self.kenosis)
        
class MockXmlrpcModule:
    def __init__(self):
        self.nodesCalled_ = []
        self.kenosis = MockKenosis(parent=self)
    Fault = xmlrpclib.Fault
    def ServerProxy(self, netAddress):
        ret = MockServerProxy(self)
        ret.kenosis = self.kenosis
        return ret
    
def nullServerProxyFactory(*args, **kwargs):
    raise "never called"

def newRpcHeader(sourceNodeAddressObject, sourceNetHost, sourceNetPort, destNodeAddressObject):
    rpcHeader = {"sourceNodeAddress":sourceNodeAddressObject,
                 "sourceNetHost":sourceNetHost,
                 "sourceNetPort":sourceNetPort,
                 "destNodeAddress":destNodeAddressObject}
    node.assertRpcHeaderValid(rpcHeader=rpcHeader)
    return rpcHeader

def newNodeKernel(nodeAddress, serverProxyFactory=nullServerProxyFactory):
    return node.NodeKernel(nodeAddressObject=address.stringToAddress(nodeAddress),
                           serverProxyFactory=serverProxyFactory)

class Test(dsunittest.TestCase):
    def setUp(self):
        node.task.TaskList = mocktask.TaskList
        dstime.setTestingTime(0)
        socket.setdefaulttimeout(2)

    def tearDown(self):
        reload(node)
        reload(node.task)

    def testBucketIndex(self):
        n = newNodeKernel(nodeAddress="0000")
        self.assertEqual(
            n._bucketIndexForNodeAddressObject(nodeAddressObject=address.stringToAddress("0001")), 0)
        self.assertEqual(
            n._bucketIndexForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010")), 1)
        self.assertEqual(
            n._bucketIndexForNodeAddressObject(nodeAddressObject=address.stringToAddress("0011")), 1)
        self.assertEqual(
            n._bucketIndexForNodeAddressObject(nodeAddressObject=address.stringToAddress("0100")), 2)

        # address way out of range
        self.assertRaises(address.InvalidAddressError,
            n._bucketIndexForNodeAddressObject,
                          address.NodeAddressObject(numericAddress=1L<<(address.addressLengthInBits+10)))

    def testGrowingQueue(self):
        self.growingQueueHelper2(seq0=[0,2,4], seq1=[1,3,5], output=range(6))
        self.growingQueueHelper(
            iteratorSequence=[0,8,2,6,4], queueSequence=[1,3,5], output=[0,1,3,5,8,2,6,4])
        self.growingQueueHelper2(seq0=[0,2,4], seq1=[2,3,5], output=[0,2,2,3,4,5])
        self.growingQueueHelper2(seq0=[], seq1=[], output=[])

    def testConversion(self):
        data = ["a", 1, {"a":2}]
        self.assertEqual(node.ConvertAddressToStringRecursively(data=data), data)
        self.assertEqual(node.ConvertStringToAddressRecursively(data=data), data)

        self.assertEqual(node.ConvertStringToAddressRecursively("address:1"), address.NodeAddressObject(nodeAddress="1"))

        data = [address.NodeAddressObject(nodeAddress="1"),
                address.NodeAddressObject(nodeAddress="0"),
                address.NodeAddressObject(nodeAddress="1010")]
        self.assertEqual(node.ConvertAddressToStringRecursively(data=data), ["address:0x1", "address:0x0", "address:0xA"])
        self.assertEqual(node.ConvertStringToAddressRecursively(data=node.ConvertAddressToStringRecursively(data=data)), data)

        data = {'sourceNodeAddress': 0L, 'sourceNetPort': 50070, 'destNodeAddress': address.NodeAddressObject(nodeAddress="0")}
        self.assertEqual(node.ConvertStringToAddressRecursively(data=node.ConvertAddressToStringRecursively(data=data)), data)

        data = {'sourceNodeAddress': 0L, 'sourceNetPort': 50070, 'destNodeAddress': node.NodeAddressObjectUnknown}
        self.assertEqual(node.ConvertStringToAddressRecursively(data=node.ConvertAddressToStringRecursively(data=data)), data)

    def testEmptyGrowingQueue(self):
        rq = dsqueue.PriorityQueue(0)
        gq = node.GrowingQueue(iterator=[5].__iter__(), realQueue=rq)
        assert not gq.empty()
        rq.put(5)
        rq.put(5)
        
        assert not gq.empty()
        self.assertEqual(gq.get(), 5)
        assert not gq.empty()
        self.assertEqual(gq.get(), 5)
        assert not gq.empty()
        self.assertEqual(gq.get(), 5)
        assert gq.empty()
        self.assertRaises(Queue.Empty, gq.get)

    def growingQueueHelper2(self, seq0, seq1, output):
        self.growingQueueHelper(iteratorSequence=seq0, queueSequence=seq1, output=output)
        self.growingQueueHelper(iteratorSequence=seq0, queueSequence=[], output=seq0)
        self.growingQueueHelper(iteratorSequence=seq1, queueSequence=seq0, output=output)
        self.growingQueueHelper(iteratorSequence=[], queueSequence=seq0, output=seq0)

    def growingQueueHelper(self, iteratorSequence, queueSequence, output):
        queue = dsqueue.PriorityQueue(0)
        for x in queueSequence:
            queue.put(x)
        gq = node.GrowingQueue(iterator=iteratorSequence.__iter__(), realQueue=queue)
        values = []
        while not gq.empty():
            values.append(gq.get())
        self.assertEqual(values, output)

    def testRpcStandalone(self):
        class Helper:
            def bob(self, destinationNodeAddressObject, arg):
                return destinationNodeAddressObject, arg
        rcp = node.Rpc(rpcHeader=555, toplevelRpc=None, attributeNames=[], nodeKernel=None)
        rcp.toplevelRpc_ = rcp
        rcp.serverProxy_ = Helper()
        self.assertEqual(rcp.bob(666), (555, 666))

    def testNodeInfosInBucketAndSuccessors(self):
        n = newNodeKernel(nodeAddress="0000")
        x = [x for x in n._nodeInfosInBucketAndSuccessors(bucketIndex=0, serviceName="s")]
        self.assertEqual(x, [])
        class MockNodeInfo:
            def freshness(self):
                return 0
        m = MockNodeInfo()
        n._bucketsFor(serviceName="s")[0] = [m]
        x = [x for x in n._nodeInfosInBucketAndSuccessors(bucketIndex=0, serviceName="s")]
        self.assertEqual(x, [(0,0,m)])
        n._bucketsFor(serviceName="s")[1] = [m]
        x = [x for x in n._nodeInfosInBucketAndSuccessors(bucketIndex=0, serviceName="s")]
        self.assertEqual(x, [(0,0,m),(1,0,m)])
        x = [x for x in n._nodeInfosInBucketAndSuccessors(bucketIndex=1, serviceName="s")]
        self.assertEqual(x, [(1,0,m),(0,0,m)])

    def testBucketAdd(self):
        mockXmlrpcModule = MockXmlrpcModule()
        n = newNodeKernel(nodeAddress="0000", serverProxyFactory=mockXmlrpcModule.ServerProxy)
        ni = node.NodeInfo(nodeAddressObject=address.stringToAddress("0001"), netAddress="a:b")
        self._updateNodeRoutingTableWithNodeInfo(n, ni, "kenosis")
        self.assertEqual(n._bucketsFor(serviceName="kenosis")[0], [ni])
        ni2 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0010"), netAddress="a:b")
        self._updateNodeRoutingTableWithNodeInfo(n, ni2, "kenosis")
        dstime.advanceTestingTime()
        ni3 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0011"), netAddress="a:b")
        self._updateNodeRoutingTableWithNodeInfo(n, ni3, "kenosis")
        self.assertEqual(n._bucketsFor(serviceName="kenosis")[1], [ni3, ni2])
        dstime.advanceTestingTime()
        self._updateNodeRoutingTableWithNodeInfo(n, ni2, "kenosis")
        self.assertEqual(n._bucketsFor(serviceName="kenosis")[1], [ni2, ni3])

        bucket = n._bucketsFor(serviceName="kenosis")[20]
        for i in range(2**20, 2**20+n.constantsK_+1):
            ni = node.NodeInfo(nodeAddressObject=address.NodeAddressObject(numericAddress=i), netAddress="a:b")
            self._updateNodeRoutingTableWithNodeInfo(n, ni, "kenosis")
        self.assertEqual(len(bucket), n.constantsK_)
        self.assertEqual(
            n.needPingPairs_,
            [(ni,bucket,"kenosis")])
        dstime.advanceTestingTime()
        lastNodeInfo = bucket[-1]
        n.step()
        self.assertEqual(n.needPingPairs_, [])
        assert ni not in bucket
        self.assertEqual(lastNodeInfo, bucket[0])
        self._updateNodeRoutingTableWithNodeInfo(n, ni, "kenosis")
        self.assertEqual(
            n.needPingPairs_,
            [(ni,bucket,"kenosis")])
        def lf(*args, **kwargs): raise xmlrpclib.Fault(1, "bob")
        mockXmlrpcModule.kenosis.ping = lf
        dstime.advanceTestingTime()
        self._updateNodeRoutingTableWithNodeInfo(n, ni, "kenosis")
        n.step()
        self.assertEqual(n.needPingPairs_, [])
        self.assertEqual(bucket[0], ni)
        self.assertEqual(
            len(n.rpcFindNode(nodeAddressObject=address.NodeAddressObject(numericAddress=2**20), serviceName="kenosis")), 20)
        
    def testFindNodeReal(self):
        contacts = {}
        def ServerProxyMethod(netAddress, contacts=contacts):
            contacts.setdefault(netAddress, 0)
            contacts[netAddress] += 1
            if netAddress == "n":
                nodeKernel = n
            elif netAddress == "n2":
                nodeKernel = n2
            else:
                return MockServerProxy(parent=None)
            return node.RpcClientAdapter(serverProxy=node.NodeRpcFrontend(nodeKernel=nodeKernel),
                                         rpcHeaderAdditions={"sourceNetPort":1234,
                                                             "sourceNetHost":netAddress})
        n = newNodeKernel(nodeAddress="0000", serverProxyFactory=ServerProxyMethod)
        ni = node.NodeInfo(nodeAddressObject=address.stringToAddress("0000"), netAddress="n")
        n2 = newNodeKernel(nodeAddress="0001", serverProxyFactory=ServerProxyMethod)

        ni2 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0001"), netAddress="n2")
        n._updateRoutingTableWith(nodeAddressObject=ni2.nodeAddressObject(), netAddress=ni2.netAddress(), serviceName="kenosis")
        ni3 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0010"), netAddress="n3")
        n2._updateRoutingTableWith(nodeAddressObject=ni3.nodeAddressObject(), netAddress=ni3.netAddress(), serviceName="kenosis")

        assert not n._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        n._findNodeNetAddress(nodeAddressObject=ni3.nodeAddressObject(), serviceName="kenosis")
        assert n._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        self.assertEqual(contacts, {"n3":1, "n2":1})

        # show that caching is effective
        n._findNodeNetAddress(nodeAddressObject=ni3.nodeAddressObject(), serviceName="kenosis")
        self.assertEqual(contacts, {"n3":1, "n2":1})
        dstime.advanceTestingTime(500)
        n._findNodeNetAddress(nodeAddressObject=ni3.nodeAddressObject(), serviceName="kenosis")
        self.assertEqual(contacts, {"n3":2, "n2":2})
        
        self.assertRaises(
            node.NodeNotFound, n._findNodeNetAddress,
            nodeAddressObject=ni.nodeAddressObject(), serviceName="kenosis")

    def testBadWork(self):
        n = newNodeKernel(nodeAddress="0000")
        self.assertRaises("invalidcommandName", n._addWork, nodeAddressObject=None, netAddress=None, commandName="junk")

    def _updateNodeRoutingTableWithNodeInfo(self, n, ni, serviceName):
        n._updateRoutingTableWith(
            nodeAddressObject=ni.nodeAddressObject(), netAddress=ni.netAddress(),
            serviceName=serviceName)
        
    def testRpc1(self):
        mockXmlrpcModule = MockXmlrpcModule()
        n = newNodeKernel(nodeAddress="0000", serverProxyFactory=mockXmlrpcModule.ServerProxy)
        ni = node.NodeInfo(nodeAddressObject=address.stringToAddress("0001"), netAddress="a:b")

        self._updateNodeRoutingTableWithNodeInfo(n, ni, serviceName="messiah")
        self.assertEqual(n._bucketsFor(serviceName="messiah")[0], [ni])
        ni2 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0010"), netAddress="a:b")
        self._updateNodeRoutingTableWithNodeInfo(n, ni2, serviceName="messiah")
        dstime.advanceTestingTime()
        ni3 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0011"), netAddress="a:b")
        self._updateNodeRoutingTableWithNodeInfo(n, ni3, serviceName="messiah")

        self.assertRaises(
            node.NodeNotFound,
            n.rpc(nodeAddressObject=address.NodeAddressObject(numericAddress=4L)).messiah.test, 42)
        mockXmlrpcModule.kenosis.knownNodes.append((address.stringToAddress("0100"),"b:c"))
        dstime.advanceTestingTime(by=30)
        self.assertEqual(
            n.rpc(nodeAddressObject=address.NodeAddressObject(numericAddress=4L)).messiah.test(42),
            ({'sourceNodeAddress': address.NodeAddressObject(numericAddress=0L),
              'destNodeAddress': address.NodeAddressObject(numericAddress=4L),
              "version": node.protocolVersion}, 42))
        def errorLf(*args, **kwargs):
            raise xmlrpclib.Fault(11, "asdF")
        mockXmlrpcModule.kenosis.findNode = errorLf
        self.assertRaises(node.NodeNotFound,
                          n.rpc(nodeAddressObject=address.NodeAddressObject(numericAddress=5L)).messiah.test, 42)

    def testRealRpcOverTcp(self):
        n0configPath = tempfile.mktemp()
        n0 = node.Node(
            nodeAddress=str(address.NodeAddressObject(numericAddress=0L)), ports=[50050],
            serve=False, bootstrapNetAddress=None)
        self.assertRaises(socket.error, node.Node, nodeAddress=str(address.NodeAddressObject(numericAddress=0L)), ports=[50050])
        
        n1 = node.Node(ports=None, serve=False, bootstrapNetAddress=None)
        n1port = n1.port()
        self.assertNotEqual(n1port, None)

        rpcHeader = newRpcHeader(sourceNodeAddressObject=address.NodeAddressObject(numericAddress=51113),
                                 sourceNetHost="1.2.3.4", sourceNetPort=1234,
                                 destNodeAddressObject=address.NodeAddressObject(numericAddress=0L))
        n0.server_.frontend_.kenosis.ping(rpcHeader)
        netAddress = n0.nodeKernel_._nodeInfoForNodeAddressObject(
            nodeAddressObject=address.NodeAddressObject(numericAddress=51113),
            serviceName="kenosis").netAddress()
        self.assertEqual(netAddress, node.sourceNetAddressFrom(rpcHeader=rpcHeader))

        taskList = RealTaskList(maxThreads=2)
        taskList.addCallableTask(n0.serveOneRequest)
        taskList.start(wait=0)

        n1address = address.stringToAddress(n1.nodeAddress())
        assert not n0.nodeKernel_._nodeInfoForNodeAddressObject(nodeAddressObject=n1address, serviceName="kenosis")

        sink = message.QueueMessageSink()
        message.setThreadMessageSink(messageSink=sink)
                                        
        # simulate ping from n1 to n0
        sp = xmlrpclib.ServerProxy("http://127.0.0.1:50050")
        rpcHeader = newRpcHeader(sourceNodeAddressObject=str(n1address),
                                 sourceNetHost="127.0.0.1", sourceNetPort=n1port,
                                 destNodeAddressObject="address:0")
        sp.kenosis.ping(rpcHeader)

        self.assertEqual(sink.getAndClearQueue(), [])

        n0.save(configPath=n0configPath)
        n0.server_.xmlrpcServer_.socket.close()
        del n0
        gc.collect()
        n0 = node.Node(ports=[50050],
                       serve=False, configPath=n0configPath, bootstrapNetAddress=None)
        self.assertEqual(n0.nodeAddress(), "0x0")

        ni1 = n0.nodeKernel_._nodeInfoForNodeAddressObject(nodeAddressObject=n1address, serviceName="kenosis")
        self.assertEqual(ni1.nodeAddressObject(), n1address)
        self.assertEqual(ni1.netAddress(), "127.0.0.1:%s" % n1port )


        taskList.addCallableTask(n1.serveOneRequest)
        assert n0.nodeKernel_._pingNode(nodeAddressObject=ni1.nodeAddressObject(),
                                        netAddress=ni1.netAddress(),
                                        serviceName="kenosis")

        taskList.addCallableTask(n0.serveOneRequest)
        ni0 = n1.nodeKernel_._nodeInfoForNodeAddressObject(
            nodeAddressObject=address.NodeAddressObject(numericAddress=0L),
            serviceName="kenosis")
        self.assertEqual(ni0.netAddress(), "127.0.0.1:50050")
        assert n1.nodeKernel_._pingNode(nodeAddressObject=ni0.nodeAddressObject(),
                                        netAddress=ni0.netAddress(),
                                        serviceName="kenosis")

        msgs = sink.getAndClearQueue()
        self.assertNotEqual(msgs, [])
        for m in msgs:
            self.assertEqual(m.total(), m.progress())
            assert m.progress()
            assert m.total()

        while(taskList.numTasksActive()):
            time.sleep(0.2)
        event = threading.Event()
        def lf():
            n1.serveUntilEvent(event=event)
        taskList.addCallableTask(lf)
        while not taskList.numTasksActive() == 1: pass
        self.assertEqual(taskList.numTasksActive(), 1)
        self.assertEqual(
            n0.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="kenosis"),
            [(n1.nodeAddress(), ni1.netAddress())])
        event.set()

    def testRealRpcOverTcp2(self):
        nodeAddressObject0 = str(address.NodeAddressObject(numericAddress=0L))
        nodeAddressObject1 = str(address.NodeAddressObject(numericAddress=1L))
        n0 = node.Node(nodeAddress=nodeAddressObject0, ports=[50070], serve=False, bootstrapNetAddress=None)
        self.assertEqual(n0.nodeAddress(), "0x0")
        n1 = node.Node(
            nodeAddress=nodeAddressObject1, ports=[50080], serve=False, stopEvent=threading.Event(),
            bootstrapNetAddress=None)
        self.assertEqual(n1.nodeAddress(), "0x1")
        taskList = RealTaskList(maxThreads=2)
        taskList.start(wait=0)

        taskList.addCallableTask(n0.serveOneRequest)
        self.assertEqual(n0.bootstrap(netAddress="127.0.0.1:50070"), False)
        taskList.addCallableTask(n1.serveOneRequest)
        self.assertEqual(n0.bootstrap(netAddress="127.0.0.1:50080"), True)

        class Dummy1:
            def lf1(self,  arg):
                return arg * 2
        self.assertRaises(Exception,n0.registerNamedHandler, name="dummy_", handler=Dummy1())
        n0.registerNamedHandler(name="dummy", handler=Dummy1())
        self.assertEqual(n0.nodeKernel_.servicesToBootstrap_, ['dummy'])
        class Dummy2:
            def lf2(self,  arg):
                return arg * 5
        n1.registerNamedHandler(name="dummy", handler=Dummy2())
        self.assertEqual(n1.nodeKernel_.servicesToBootstrap_, ['dummy'])
       
        taskList.waitForAllTasks()
        taskList.addCallableTask(n1.serveOneRequest)
        n0.step()
        self.assertEqual(n0.nodeKernel_.servicesToBootstrap_, [])
        taskList.addCallableTask(n0.serveOneRequest)
        n1.step()
        self.assertEqual(n1.nodeKernel_.servicesToBootstrap_, [])

        taskList.addCallableTask(n1.serveOneRequest)
        taskList.addCallableTask(n0.serveOneRequest)
        n0rpc = n0.rpc(nodeAddress=n1.nodeAddress())
        assert not hasattr(n0rpc, "__cmp__")
        self.assertRaises(
            node.NetworkError, n0.rpc(nodeAddress=n1.nodeAddress()).dummy.node_)
        taskList.addCallableTask(n1.serveOneRequest)
        self.assertRaises(
            node.NetworkError,
            n0.rpc(nodeAddress=n1.nodeAddress()).dummy._privateMethod)

        taskList.addCallableTask(n1.serveOneRequest)
        r = n0.rpc(nodeAddress=nodeAddressObject1).dummy.ping()
        self.assertEqual(r["supportsService"], True)
        myVersion = node.protocolVersion
        try:
            node.protocolVersion = 91

            taskList.addCallableTask(n1.serveOneRequest)
            r = n0.rpc(nodeAddress=nodeAddressObject1).dummy.ping()
            self.assertEqual(str(r), nodeAddressObject1)

            taskList.addCallableTask(n1.serveOneRequest)
            r = n0.rpc(nodeAddress=nodeAddressObject1).kenosis.findNode("address:" + n0.nodeAddress())
            self.assertEqual(type(r), type([]))
        finally:
            node.protocolVersion = myVersion

        taskList.addCallableTask(n1.serveOneRequest)
        self.assertRaises(node.NetworkError, n0.rpc(nodeAddress=nodeAddressObject1).badServiceId, "asdf")
        taskList.addCallableTask(n1.serveOneRequest)
        self.assertRaises(node.NetworkError, n0.rpc(nodeAddress=nodeAddressObject1).badServiceId.bob, "asdf")

        taskList.addCallableTask(n1.serveOneRequest)
        r = n0.rpc(nodeAddress=nodeAddressObject1).nothingyousupport.ping()
        self.assertEqual(r["supportsService"], False)

        taskList.addCallableTask(n1.serveOneRequest)
        r = n0.rpc(nodeAddress=nodeAddressObject1).dummy.lf2(15)
        self.assertEqual(r, 75)

        r = n0.rpc(nodeAddress=nodeAddressObject0).dummy.lf1(15)
        self.assertEqual(r, 30)

        
        event = threading.Event()
        n0.threadedServeUntilEvent(event=event)
        self.assertEqual(
            n1.nodeKernel_._nodeInfoForNodeAddressObject(
            nodeAddressObject=address.NodeAddressObject(numericAddress=0L), serviceName="dummy").netAddress(),
            "127.0.0.1:50070")
        self.assertEqual(
            n1.nodeKernel_._nodeInfoForNodeAddressObject(nodeAddressObject=address.NodeAddressObject(numericAddress=0L),
                                                         serviceName="dummy").netAddress(),
            "127.0.0.1:50070")
        event.set()
        r = n1.rpc(nodeAddress=nodeAddressObject0).dummy.lf1(1)
        self.assertEqual(r, 2)

        n1.threadedServeUntilEvent(event=None)
        r = n0.rpc(nodeAddress=nodeAddressObject1).dummy.lf2(15)
        self.assertEqual(r, 75)
        n1.stopEvent_.set()

        # always serves one extra request after stopEvent - FIXME
        r = n0.rpc(nodeAddress=nodeAddressObject1).dummy.lf2(15)
        self.assertEqual(r, 75)
        self.assertRaises(node.NetworkError, n0.rpc(nodeAddress=nodeAddressObject1).dummy.lf2, 15)

    def testAutobootstrap(self):
        nodeAddressObject0 = str(address.NodeAddressObject(numericAddress=0L))
        nodeAddressObject1 = str(address.NodeAddressObject(numericAddress=1L))
        n0 = node.Node(
            nodeAddress=nodeAddressObject0, ports=[50090], serve=False, bootstrapNetAddress=None)

        taskList = RealTaskList(maxThreads=2)
        taskList.start(wait=0)

        taskList.addCallableTask(n0.serveOneRequest)
        n1 = node.Node(
            nodeAddress=nodeAddressObject1, ports=[50100],
            serve=False, bootstrapNetAddress="127.0.0.1:50090")
        self.assertEqual(
            n1.nodeKernel_.bootstrapTuples_,
            [(n0.nodeKernel_.nodeAddressObject_, '127.0.0.1:50090')])

        self.assertEqual(n0.nodeKernel_.serviceBuckets_["kenosis"][0][0].nodeAddressObject(),
                         n1.nodeKernel_.nodeAddressObject_)
        


        self.assertRaises(node.NodeNotFound, n0.rpc(nodeAddress=n1.nodeAddress()).someservice.foo)

        taskList.addCallableTask(n1.serveOneRequest)
        self.assertEqual(
            n0.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="kenosis"),
            [(n1.nodeAddress(), "127.0.0.1:50100")])

        taskList.addCallableTask(n0.serveOneRequest)
        class Handler:
            def foo(self):
                return 18
        self.assertEqual(n1.nodeKernel_.servicesToBootstrap_, [])

        n1.registerNamedHandler(name="someservice", handler=Handler())
        self.assertEqual(n1.nodeKernel_.servicesToBootstrap_, ['someservice'])
        n1.step()
        self.assertEqual(n1.nodeKernel_.servicesToBootstrap_, [])

        # show that n0 can route to n1 on service "someservice"
        taskList.addCallableTask(n1.serveOneRequest)
        self.assertEqual(n0.rpc(nodeAddress=n1.nodeAddress()).someservice.foo(), 18)
        

    def testAutobootstrapBad(self):
        class MockEvent:
            set_ = False
            def isSet(self):
                if self.set_:
                    return True
                else:
                    self.set_ = True
                    return False
        mockEvent = MockEvent()
        n0 = node.Node(serve=False, bootstrapNetAddress="127.0.0.1:1234", stopEvent=mockEvent)
        for serviceName in n0.nodeKernel_.serviceBuckets_.keys():
            for bucket in n0.nodeKernel_._bucketsFor(serviceName=serviceName):
                self.assertEqual(len(bucket), 0)
        assert mockEvent.set_

    def testXmlrpcFeatures(self):
        nodeAddressObject0 = str(address.NodeAddressObject(numericAddress=0L))
        n0 = node.Node(nodeAddress=nodeAddressObject0, ports=[50110], serve=False, bootstrapNetAddress=None)
        taskList = RealTaskList(maxThreads=2)
        taskList.start(wait=0)


        class Dummy1:
            def lf1(self,  arg):
                """helpstring for lf1"""
                return arg * 2
            private_ = None
            def _privateMethod(self): pass
            
        n0.registerNamedHandler(name="dummy", handler=Dummy1())
        sp = xmlrpclib.ServerProxy("http://127.0.0.1:50110")
        

        taskList.addCallableTask(n0.serveOneRequest)
        methods = sp.system.listMethods()
        self.assertEqual(methods, ['dummy.findNode', 'dummy.lf1', 'dummy.ping', 'kenosis.findNode', 'kenosis.ping', 'system.listMethods', 'system.methodHelp', 'system.methodSignature', 'system.multicall'])

        taskList.addCallableTask(n0.serveOneRequest)
        help = sp.system.methodHelp("dummy.lf1")
        assert "helpstring for lf1" in help

        taskList.addCallableTask(n0.serveOneRequest)
        sig = sp.system.methodSignature("dummy.lf1")
        self.assertEqual(sig, ["unknown", "struct", "unknown"])
        taskList.addCallableTask(n0.serveOneRequest)
        self.assertRaises(xmlrpclib.Fault, sp.system.methodSignature, "dummy.invalid")

        taskList.addCallableTask(n0.serveOneRequest)
        self.assertRaises(xmlrpclib.Fault, sp.system.methodHelp, "dummy.invalid")
        taskList.addCallableTask(n0.serveOneRequest)
        self.assertRaises(xmlrpclib.Fault, sp.system.methodHelp, "dummy.private_")
        taskList.addCallableTask(n0.serveOneRequest)
        self.assertRaises(xmlrpclib.Fault, sp.system.methodHelp, "dummy._privateMethod")
            
    def testFindNodeReal3(self):
        n0, n1, n2 = self.createNodeKernels(nodeAddresses=("0x0", "0x1", "0x2"))
        
        n0._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0001"), netAddress="net0x1", serviceName="kenosis")

        ni2 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0010"), netAddress="net0x2")
        self._updateNodeRoutingTableWithNodeInfo(n1, ni2, serviceName="kenosis")

        assert not n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        n0._findNodeNetAddress(nodeAddressObject=ni2.nodeAddressObject(), serviceName="kenosis")
        assert n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")

    def createNodeKernels(self, nodeAddresses, nodes=None):
        if nodes is None:
            nodes = {}
        def ServerProxyMethod(sourceNetHost, destNetAddress=None, nodes=nodes):
            try:
                destNetHost = destNetAddress.replace(":1234", "")
                nodeKernel = nodes[destNetHost]
            except KeyError:
                raise socket.error(61, 'Connection refused')
            return node.RpcClientAdapter(serverProxy=node.NodeRpcFrontend(nodeKernel=nodeKernel),
                                         rpcHeaderAdditions={"sourceNetPort":1234,
                                                             "sourceNetHost":sourceNetHost})
        
        for nodeAddress in nodeAddresses:
            n = newNodeKernel(
                nodeAddress=nodeAddress,
                serverProxyFactory=lambda netAddress, nodeAddress=nodeAddress: ServerProxyMethod(destNetAddress=netAddress,
                                                                        sourceNetHost="net%s" % nodeAddress))
            nodes["net%s" % nodeAddress] = n
        return [nodes["net%s" % x] for x in nodeAddresses]
        

    # 4 nodes: a,b,c,d
    # a wants to route to d, and can route to b and c
    # b has bad data for d's net address
    # c has good data
    # assert that a can route to d, even after getting bad data from b
    def testFindNodeReal2(self):
        n0, n15, n1, n3 = self.createNodeKernels(nodeAddresses=("0x0", "0xF", "0x1", "0x2"))

        # a can route to b
        n0._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("1111"), netAddress="net1111:1234", serviceName="kenosis")

        # b has bad data for d
        n15._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0010"), netAddress="badAddress!", serviceName="kenosis")

        # a knows nothing about d
        assert not n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")

        # a access to only bad data, cannot find d
        self.assertRaises(node.NodeNotFound, n0._findNodeNetAddress, nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")

        # a still knows nothing about d
        assert not n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")

        # c has good data for d
        n1._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0010"), netAddress="net0x2:1234", serviceName="kenosis")

        # a can route to c
        n0._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0001"), netAddress="net0x1:1234", serviceName="kenosis")

        # a finds d
        r = n0._findNodeNetAddress(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        self.assertEqual(r, "net0x2:1234")
        assert n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")

    def testFrontend(self):
        class Dummy:
            def test(self):
                return 42
        d = Dummy()
        mockXmlrpcModule = MockXmlrpcModule()
        n = newNodeKernel(nodeAddress="0000", serverProxyFactory=mockXmlrpcModule.ServerProxy)
        frontend = n._frontend()
        
        frontend.registerNamedHandler(name="dummy", handler=d)
        rpcHeader = n._rpcHeaderFor(nodeAddressObject=n.nodeAddressObject_)
        rpcHeader["sourceNetHost"] = "localhost"
        rpcHeader["sourceNetPort"] = 1234
        self.assertEqual(frontend.dummy.test(rpcHeader), 42)
        assert hasattr(frontend, "dummy")
        assert hasattr(frontend.dummy, "test")
        assert callable(frontend.dummy.test)
        self.assertEqual(
            frontend._listMethods(),
            ['dummy.test', 'dummy.ping', 'dummy.findNode', 'kenosis.ping', 'kenosis.findNode'])

    def testFindNodes(self):
        n0, n1, n2 = self.createNodeKernels(nodeAddresses=("0x0", "0x1", "0x2"))
        
        n0._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0001"), netAddress="net0x1", serviceName="kenosis")

        ni0 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0000"), netAddress="net0x0")
        ni1 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0001"), netAddress="net0x1")
        ni2 = node.NodeInfo(nodeAddressObject=address.stringToAddress("0010"), netAddress="net0x2")
        self._updateNodeRoutingTableWithNodeInfo(n1, ni2, serviceName="kenosis")

        assert not n0._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        self.assertRaises(
            node.NodeNotFound, n0._findNodeNetAddress, nodeAddressObject=address.stringToAddress("1000"), serviceName="kenosis")

        found = n0._findNearestNodeAddressObjectNetAddressTuples(
            nodeAddressObject=address.stringToAddress("1000"), serviceName="kenosis")
        self.assertEqual(len(found), 2)
        self.assertEqual(found, [ni1.asTuple(), ni2.asTuple()])

    def testFindNodes2(self):
        nodes = self.createNodeKernels(nodeAddresses=["0x%x" % x for x in range(40)])
        
        for n in nodes[1:]:
            dstime.advanceTestingTime()
            n._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0000"), netAddress="net0x0", serviceName="kenosis")
            n._findNodeNetAddress(nodeAddressObject=address.stringToAddress("0000"), serviceName="kenosis")
        #print(nodes[0]._bucketsFor(serviceName="kenosis"))
        self.assertEqual(nodes[0]._bucketsFor(serviceName="kenosis")[3][-1].nodeAddressObject(), address.stringToAddress("0x8"))
            
        assert not n._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        self.assertEqual(n._findNodeNetAddress(nodeAddressObject=address.stringToAddress("0x8"), serviceName="kenosis"), "net0x8:1234")

        found = n._findNearestNodeAddressObjectNetAddressTuples(
            nodeAddressObject=address.stringToAddress("1000"), serviceName="kenosis")
        self.assertEqual(len(found), n.constantsK_)

    def testFindNodes3(self):
        nodes = self.createNodeKernels(nodeAddresses=["0x%x" % x for x in range(40)])
        
        #prevN = None
        for n in nodes[1:]:
            dstime.advanceTestingTime()
            n._updateRoutingTableWith(nodeAddressObject=address.stringToAddress("0000"), netAddress="net0x0", serviceName="kenosis")
            n._findNodeNetAddress(nodeAddressObject=address.stringToAddress("0000"), serviceName="kenosis")
            #if prevN:
            #    n._findNodeNetAddress(nodeAddressObject=prevN.nodeAddressObject(), serviceName="kenosis")
            #prevN = n
        #print(nodes[0]._bucketsFor(serviceName="kenosis"))
        self.assertEqual(nodes[0]._bucketsFor(serviceName="kenosis")[3][-1].nodeAddressObject(), address.stringToAddress("0x8"))
            
        assert not n._nodeInfoForNodeAddressObject(nodeAddressObject=address.stringToAddress("0010"), serviceName="kenosis")
        self.assertEqual(n._findNodeNetAddress(nodeAddressObject=address.stringToAddress("0x8"), serviceName="kenosis"), "net0x8:1234")

#         def hopelessLambda(serverProxy):
#             return serverProxy.doesnt.exist()
        
#         found = n._findNearestNodeAddressObjectNetAddressTuples(nodeAddressObject=address.stringToAddress("1000"),
#                                                           serverProxyFilterAndMapFunc=hopelessLambda)
#         self.assertEqual(found, [])

        #def reasonableLambda(serverProxy):
        #    return serverProxy.kenosis.ping(n._rpcHeaderFor(nodeAddressObject=node.NodeAddressObjectUnknown))
        #
        #found = n._findNearestNodeAddressObjectNetAddressTuples(nodeAddressObject=address.stringToAddress("1000"),
        #                                                  serverProxyFilterAndMapFunc=reasonableLambda)
        #self.assertEqual(len(found), n.constantsK_)
        #for nodeAddressObject, netAddress, pingResult in found:
        #    self.assertEqual(nodeAddressObject, pingResult)

    def testNodePersistance(self):
        path = tempfile.mktemp()
        n0 = node.Node(configPath=path, bootstrapNetAddress=None)
        n0.save()
        data = dsfile.fileObject(path=path)
        self.assertEqual(
            data,
            {"version":node.protocolVersion, "nodeAddress":n0.nodeAddress(), "routingTuples":[], "bootstrapTuples":[]})
        n1 = node.Node(configPath=path, bootstrapNetAddress=None)
        self.assertEqual(n0.nodeAddress(), n1.nodeAddress())

    def testNodeAutopersistance(self):
        path = tempfile.mktemp()
        n0 = node.Node(configPath=path, bootstrapNetAddress=None)
        saveTime = n0.lastSaveTime_
        n0.nodeKernel_._updateRoutingTableWith(
            nodeAddressObject=address.stringToAddress(nodeAddress="0xf00"),
            netAddress="127.0.0.1:3434", serviceName="s")
        dstime.advanceTestingTime(by=60)
        n0.step()
        dsunittest.assertLt(saveTime, n0.lastSaveTime_)

        data = dsfile.fileObject(path=path)
        self.assertEqual(
            data,
            {"version":node.protocolVersion, "nodeAddress":n0.nodeAddress(),
             "routingTuples":[(address.stringToAddress(nodeAddress="0xf00"), "127.0.0.1:3434", "s")],
             "bootstrapTuples":[]})
        n1 = node.Node(configPath=path, bootstrapNetAddress=None)
        self.assertEqual(n0.nodeAddress(), n1.nodeAddress())

    def testSelfBoostrap(self):
        n0 = node.Node(ports=[50111], bootstrapNetAddress="127.0.0.1:50111")

    def testServices(self):
        n0 = node.Node(ports=[50121], serve=True, bootstrapNetAddress=None)
        n1 = node.Node(ports=[50122], serve=True, bootstrapNetAddress="127.0.0.1:50121")
        n2 = node.Node(ports=[50123], serve=True, bootstrapNetAddress="127.0.0.1:50121")

        class SssHandler:
            def bob(self):
                return 1
        n1.registerNamedHandler(name="sss", handler=SssHandler())
        n1.step()
        self.assertEqual(n2.rpc(nodeAddress=n1.nodeAddress()).sss.bob(), 1)

        r = n2.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="sss")
        self.assertEqual(r, [(n1.nodeAddress(), '127.0.0.1:50122')])

        r = n2.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="kenosis")
        r.sort()
        expected = [(n1.nodeAddress(), '127.0.0.1:50122'), (n0.nodeAddress(), '127.0.0.1:50121')]
        expected.sort()
        self.assertEqual(r, expected)

        r = n2.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="badservice")
        self.assertEqual(r, [])

        r = n1.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="sss")
        self.assertEqual(r, [])
        n2.registerNamedHandler(name="sss", handler=SssHandler())
        n2.step()
        dstime.advanceTestingTime(by=30)
        r = n1.findNearestNodes(nodeAddress=n1.nodeAddress(), serviceName="sss")
        self.assertEqual(r, [(n2.nodeAddress(), '127.0.0.1:50123')])
        
    def testMultithreading(self):
        n0 = node.Node(ports=[50124], serve=True, bootstrapNetAddress=None)
        n1 = node.Node(ports=[50125], serve=True, bootstrapNetAddress="127.0.0.1:50124")

        class Handler:
            def __init__(self):
                self.event_ = threading.Event()
                self.event_.set()
            def foo(self):
                dsunittest.trace("> Handling foo()")
                if self.event_.isSet():
                    self.event_.clear()
                    self.event_.wait()
                    dsunittest.trace("< Handling foo(), 1")
                    return 1
                else:
                    self.event_.set()
                    dsunittest.trace("< Handling foo(), 2")
                    return 2

        n0.registerService(name="threadtest", handler=Handler())

        taskList = RealTaskList(maxThreads=2)
        taskList.addCallableTask(callableObject=n1.rpc(nodeAddress=n0.nodeAddress()).threadtest.foo)
        taskList.addCallableTask(callableObject=n1.rpc(nodeAddress=n0.nodeAddress()).threadtest.foo)
        returnValues = taskList.start(wait=1)
        returnValues.sort()
        self.assertEqual(returnValues, [1, 2])

    # Test that we deal with pinging a node and finding a different
    # node at the other end than we expected.
    def testNodeIdentityChange(self):
        netsToNodeKernels = {}
        n0, n1, n2 = self.createNodeKernels(nodeAddresses=["0x%x" % x for x in range(3)], nodes=netsToNodeKernels)

        n0._updateRoutingTableWith(nodeAddressObject=n1.nodeAddressObject_, netAddress="net0x2", serviceName="kenosis")
        results = n0._findNearestNodeAddressObjectNetAddressTuples(
            nodeAddressObject=n2.nodeAddressObject_, serviceName="kenosis")
        self.assertEqual(results, [(n2.nodeAddressObject_, "net0x2")])

# End unit tests

class BehavioralUser:
    def __init__(self, nodeApi):
        self.nodeApi_ = nodeApi
        self.setBehaviors(behaviors=[])
        
    def setBehaviors(self, behaviors):
        self.behaviors_ = behaviors
        self.behaviorResult_ = []

    def step(self):
        if self.behaviors_:
            b = self.behaviors_[0]
            self.behaviors_ = self.behaviors_[1:]
            self.behaviorResult_.append(b(nodeApi=self.nodeApi_))

class GoodNetwork:
    def notifyOutboundRpc(self, destNetAddress):
        dstime.sleep(10)

    def notifyInboundRpc(self, sourceNetAddress):
        dstime.sleep(10)

class NullUser:
    def __init__(self, nodeApi):
        pass
    
    def step(self):
        pass

class SimulationTest(dsunittest.TestCase):

    def setUp(self):
        dstime.setTestingTime(0)
        self.simulationRunning_ = False
        random.seed(0)
        node.task = mocktask

    def tearDown(self):
        self.simulationRunning_ = False
        dstime.advanceTestingTime()
        reload(node)

    def simulationRunning(self):
        return self.simulationRunning_
    
    def setupSimulation(self, addressesAndPolicies):
        self.taskList_ = task.TaskList(maxThreads=len(addressesAndPolicies))
        nodes = {}
        def ServerProxyMethod(sourceNetHost, destNetAddress=None, nodes=nodes):
            sourceNetworkPolicy = nodes[sourceNetHost][0]
            sourceNetworkPolicy.notifyOutboundRpc(destNetAddress=destNetAddress)
            port = 1234
            destNetHost = destNetAddress.replace(":%s" % port, "")
            sourceNetAddress = "%s:%s" % (sourceNetHost, port)
            try:
                destNetworkPolicy, nodeKernel, destUser, frontend = nodes[destNetHost]
            except KeyError, e:
                raise socket.error(61, '(mock) Connection refused: %s' % e)

            destNetworkPolicy.notifyInboundRpc(sourceNetAddress=sourceNetAddress)
            return node.RpcClientAdapter(serverProxy=frontend,
                                              rpcHeaderAdditions={"sourceNetPort":port,
                                                                  "sourceNetHost":sourceNetHost})


        for nodeAddressObject, networkPolicyFactory, userPolicyFactory in addressesAndPolicies:
            networkPolicy = networkPolicyFactory()
            sourceNetHost = "net%s" % nodeAddressObject.numericRepr()
            
            serverProxyFactory=lambda netAddress, sourceNetHost=sourceNetHost: \
                ServerProxyMethod(destNetAddress=netAddress,
                                  sourceNetHost=sourceNetHost)
            n = node.NodeKernel(nodeAddressObject=nodeAddressObject,
                                serverProxyFactory=serverProxyFactory)
            n.staleInfoTime_ = 300000000L

            frontend = n._frontend()
            userPolicy = userPolicyFactory(nodeApi=n)

            class Dummy:
                def test(self):
                    dsunittest.trace("simulation.test called")
                    return 42
            d = Dummy()
            frontend.registerNamedHandler(name="simulation", handler=d)

            self.addUserPolicy(userPolicy=userPolicy)
            nodes[sourceNetHost] = (networkPolicy, n, userPolicy, frontend)
            
        return [nodes["net%s" % x.numericRepr()][2] for x,y,z in addressesAndPolicies]


    def testSimplestSimulation(self):
        addressesAndPolicies = ((address.NodeAddressObject(nodeAddress="0000"), GoodNetwork, NullUser),
                                (address.NodeAddressObject(nodeAddress="0001"), GoodNetwork, BehavioralUser))
        user1, user2 = self.setupSimulation(addressesAndPolicies=addressesAndPolicies)
        user2.setBehaviors(behaviors=[lambda nodeApi: nodeApi.bootstrap("net0x0:1234", serviceName="simulation")])

        self.stepSimulation(milliseconds=19)
        self.assertEqual(user2.behaviorResult_, [])
        self.stepSimulation(milliseconds=2)
        self.assertEqual(user2.behaviorResult_, [True])


    def addUserPolicy(self, userPolicy):
        def lf(self=self, userPolicy=userPolicy):
            while self.simulationRunning():
                currentTime = dstime.time()
                userPolicy.step()
                if dstime.time() == currentTime:
                    dstime.sleep(1)
        self.taskList_.addCallableTask(callableObject=lf)
        
    def stepSimulation(self, milliseconds):
        for i in range(milliseconds):
            if not self.simulationRunning_:
                dsunittest.trace("Running simulation step for time %s." % dstime.time())
                self.simulationRunning_ = True
                self.taskList_.start(wait=0)
            while dstime.numSleepingThreads() < self.taskList_.numTasksAdded():
                time.sleep(0.01)
            dsunittest.assertLte(dstime.numSleepingThreads(), self.taskList_.numTasksAdded())
            dsunittest.trace("Running simulation step for time %s." % (dstime.time() + 1))
            dstime.advanceTestingTime()
            while dstime.numSleepingThreads() < self.taskList_.numTasksAdded():
                time.sleep(0.01)

    def testBasicRpc(self):
        addressesAndPolicies = []
        nodeAddressObjectes = [address.NodeAddressObject(numericAddress=i) for i in range(10)]
        for nodeAddressObject in nodeAddressObjectes:
            ithTuple = (nodeAddressObject, GoodNetwork, BehavioralUser)
            addressesAndPolicies.append(ithTuple)

        def simulationLf(nodeApi):
            na = random.choice([x for x in nodeAddressObjectes if x not in [nodeApi.nodeAddressObject_, nodeAddressObjectes[0]]])
            dsunittest.trace("I am %s, calling rpc on %s" % (nodeApi, na))
            res = nodeApi.rpc(na).simulation.test()
            dsunittest.trace("I am %s, result of calling rpc on %s is %s" % (nodeApi, na, res))
            return res
        
        users = self.setupSimulation(addressesAndPolicies=addressesAndPolicies)
        for user in users[1:]:
            user.setBehaviors(behaviors=[
                lambda nodeApi: nodeApi.bootstrap("net0x0:1234", serviceName="simulation"),
                simulationLf
                ])

        self.stepSimulation(milliseconds=19)
        for user in users:
            self.assertEqual(user.behaviorResult_, [])
        self.stepSimulation(milliseconds=1)
        for user in users[1:]:
            self.assertEqual(user.behaviorResult_, [True])
        self.stepSimulation(milliseconds=20*(len(users)+1))
        for user in users[1:]:
            self.assertEqual([user.nodeApi_]+user.behaviorResult_, [user.nodeApi_,True,42])

    def testDaisyChain(self):
        addressesAndPolicies = []
        nodeAddressObjectes = [address.NodeAddressObject(numericAddress=i) for i in range(13)]
        for nodeAddressObject in nodeAddressObjectes:
            ithTuple = (nodeAddressObject, GoodNetwork, BehavioralUser)
            addressesAndPolicies.append(ithTuple)

        def simulationLf(nodeApi):
            na = random.choice([x for x in nodeAddressObjectes if x not in [nodeApi.nodeAddressObject_, nodeAddressObjectes[0]]])
            dsunittest.trace("I am %s, calling rpc on %s" % (nodeApi, na))
            return nodeApi.rpc(na).simulation.test()
        
        users = self.setupSimulation(addressesAndPolicies=addressesAndPolicies)
        for i in range(len(users)-1):
            user = users[i]
            nextAddress = nodeAddressObjectes[i+1].numericRepr()
            user.setBehaviors(behaviors=[
                lambda nodeApi: nodeApi.bootstrap("net%s:1234" % nextAddress, serviceName="simulation"),
                simulationLf
                ])

        self.stepSimulation(milliseconds=20*(len(users)+1))
        for user in users[:-1]:
            self.assertEqual([user.nodeApi_]+user.behaviorResult_, [user.nodeApi_,True,42])
        
if __name__ == "__main__":
    dsunittest.main()
