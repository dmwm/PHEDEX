#!/usr/bin/python
# eg:  twistd -ny kenosisdns.tac.py

from twisted.application import service
from twisted.application import internet

from twisted.names import authority, cache, client, server, common
from twisted.protocols import dns
from twisted.internet import reactor, defer, threads

from twisted.python import threadable
threadable.init(1)

import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], "../.."))
if os.getuid() == 0:
    sys.path.append(os.path.expanduser("~/Projects/messiah/"))
    port = 53
else:
    port = 5354

import kenosis.dns

import kenosis
from ds import task
from ds import dsunittest
import re

import socket
socket.setdefaulttimeout(2)

def threadedDeferred(callableObject, *args, **kwargs):
    d = defer.Deferred()
    def lf(d=d, callableObject=callableObject, args=args, kwargs=kwargs):
        result = callableObject(*args, **kwargs)
        # result is a Deferred, so can't do d.callback(result)
        result.chainDeferred(d)
    t = dsthread.newThread(function=lf)
    return d

import threading

class KenosisAuthority(authority.PySourceAuthority):
    def __init__(self):
        authority.PySourceAuthority.__init__(self, "example.zone.py")
        self.node_ = kenosis.Node(configPath="kenosisdns.conf", runThreadedFunc=reactor.callInThread, serve=False, useUpnp=False)
        print "Kenosis node address: %s, port: %s" % (self.node_.nodeAddress(), self.node_.port())
        self.deferredDict_ = {}
        
    def _taskListDeferred(self, callableObject, *args, **kwargs):
        d = defer.Deferred()
        def lf(d=d, callableObject=callableObject, args=args, kwargs=kwargs):
            result = callableObject(*args, **kwargs)
            # result is a Deferred, so can't do d.callback(result)
            result.chainDeferred(d)

        key = list(args) + kwargs.items()
        key.sort()
        self.taskList_.addCallableTask(callableObject=lf, id=None) # TOOO: tuple(key))
        # TODO: prevent multiple queries for the same name happening simultaneously
        return d

    def _lookup(self, name, cls, type, timeout = None):
        print "lookup name %s, cls %s type %s timeout %s" % (name, cls, type, timeout)
        key = (name,cls,type)
        try:
            d, returnedDeferreds = self.deferredDict_[key]
        except KeyError:
            pass
        else:
            # return a new deferred linked to d
            d2 = defer.Deferred()
            returnedDeferreds.append(d2)
            return d2

        d = defer.Deferred()
        retD = defer.Deferred()
        returnedDeferreds = [retD]
        def lf():
            try:
                d2 = self._deferredLookup(name=name, cls=cls, type=type, timeout=timeout)
                d2.chainDeferred(d)
            except:
                dsunittest.traceException("error during _deferredLookup for name %s" % name)
                d.errback()
                
        self.deferredDict_[key] = (d, returnedDeferreds)
        def callback(result):
            del self.deferredDict_[key]
            for d in returnedDeferreds:
                d.callback(result)
            return result
        def errback(failure):
            del self.deferredDict_[key]
            for d in returnedDeferreds:
                d.errback(failure)
            return failure
        d.addCallbacks(callback, errback)
        reactor.callInThread(lf)
        return retD
        
    def _deferredLookup(self, name, cls, type, timeout):
        # name is foo.bt.redheron.com
        dsunittest.trace(
            "_deferredLookup name %s, cls %s type %s timeout %s" % (name, cls, type, timeout))
        nodeAddress, serviceName = kenosis.dns.nodeAddressAndServiceNameFrom(domain=name)
        if nodeAddress:
            print "looking up nodeAddress %s for service %s" % (nodeAddress, serviceName)
            found = self.node_.findNearestNodes(nodeAddress=nodeAddress, serviceName=serviceName)
            if found:
                nodeAddress, netAddress = found[0]
                host, port = netAddress.split(":", 1)
                parts = host.split(".")
                if re.match("\d+\.\d+\.\d+\.\d+", host):
                    records = [dns.Record_A(address=host)]
                else:
                    records = [dns.Record_CNAME(host)]
            else:
                records = []
            print "found results %s, records is %s" % (found, records)
            self.records[name.lower()] = records
        return authority.PySourceAuthority._lookup(self, name, cls, type, timeout)

def makeService(config):
    ca, cl = [], []
    ca.append(cache.CacheResolver(verbose=config['verbose']))

    ka = KenosisAuthority()
    #ka = authority.PySourceAuthority("example.zone.py")
    f = server.DNSServerFactory([ ka ], ca, cl, config['verbose'])
    p = dns.DNSDatagramProtocol(f)
    f.noisy = 0
    ret = service.MultiService()
    #for (klass, arg) in [(internet.UDPServer, p)]:
    for (klass, arg) in [(internet.TCPServer, f), (internet.UDPServer, p)]:
        s = klass(config['port'], arg, interface=config['interface'])
        s.setServiceParent(ret)
    return ret

dsunittest.setTraceLevel(level=1)

options = {"port": port,
           "verbose": False,
           "interface": ""}
ser = makeService(options)
application = service.Application('dns', uid=1, gid=1)
ser.setServiceParent(service.IServiceCollection(application))
