import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))

import cPickle
import kenosis
import socket
import urllib2
import xmlrpclib


try:
    import ezPyCrypto
except ImportError:
    ezPyCrypto = None


from ds import dsunittest

class WebCache:
    def __init__(self, useCrypto=True):
        self.cache_ = {}
        self.keys_ = {}
        self.useCrypto_ = ezPyCrypto and useCrypto

    def __key(self, url):
        import sha
        key = sha.sha(url).hexdigest()
        return key
    
    def get(self, url):
        key = self.__key(url)
        return self.__decrypt(url, self.cache_.get(key, None))

    def __cryptKey(self, url):
        if not self.useCrypto_:
            return None

        key = self.__key(url)
        try:
            cryptKey = self.keys_[key]
        except KeyError:
            cryptKey = ezPyCrypto.key(passphrase=url)
            self.keys_[key] = cryptKey
        return cryptKey
        
    def __crypt(self, url, data):
        key = self.__key(url)
        cryptKey = self.__cryptKey(url)
        if cryptKey:
            return cryptKey.encString(str(data))
        else:
            return str(data)

    def __decrypt(self, url, data):
        if data is None:
            return None
        
        key = self.__key(url)
        cryptKey = self.__cryptKey(url)
        if cryptKey:
            return cryptKey.decString(str(data))
        else:
            return str(data)
            
    def put(self, url, data):
        key = self.__key(url)
        value = self.__crypt(url, data)
        self.cache_[key] = value
        


class KenosisWebServiceHandler:
    def __init__(self, node, useCache=True, useCrypto=True):
        self.node_ = node
        if useCache:
            self.cache_ = WebCache(useCrypto=useCrypto)
        else:
            self.fetchUrl = self._fetchUrl
        
    def fetchUrl(self, url, headers, htl):
        # TODO: incorporate some headers into the cache key
        cachedResult = self.cache_.get(url)
        if cachedResult:
            sys.stderr.write("cache hit for url %s\n" % url)
            return cPickle.loads(cachedResult)
        result = self._fetchUrl(url=url, headers=headers, htl=htl)
        cachedResult = cPickle.dumps(result)
        self.cache_.put(url=url, data=cachedResult)
        return result

    def _fetchUrl(self, url, headers, htl):
        doHttp = False
        if htl <= 0:
            doHttp = True
        # if random, doHttp = True
        if not doHttp:
            addr = kenosis.randomNodeAddress()
            nodes = self.node_.findNearestNodes(nodeAddress=addr, serviceName="kweb")
            for nodeAddr, netAddr in nodes:
                if nodeAddr == self.node_.nodeAddress():
                    continue
                sys.stderr.write("forwarding request to nodeAddress %s, netAddr %s\n" % (nodeAddr, netAddr))
                return self.node_.rpc(nodeAddress=nodeAddr).kweb.fetchUrl(url, headers, htl-1)
            doHttp = True

        if doHttp:
            sys.stderr.write("making HTTP request for %s\n" % url)
            
            request = urllib2.Request(url)
            for k,v in headers.items():
                k = k.capitalize()
                request.add_header(k,v)
            opener = urllib2.build_opener()
            try:
                urlHandle = opener.open(request)
            except urllib2.HTTPError, e:
                response = e.code
                urlHandle = e
            else:
                response = 200

            urlHandle.headers["connection"] = "close"
            headersReturn = dict(urlHandle.headers.items())
            return response, headersReturn, xmlrpclib.Binary(urlHandle.read())


import SimpleHTTPServer
import BaseHTTPServer
import SocketServer

kwebSuffix = ".kweb.kenosisp2p.org:8091"
hostOverride = None

class KenosisWebRequestHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):

    def do_GET(self):
        host = self.headers["Host"]
        realHost = host.replace(kwebSuffix, "")

        # fixme: remove once we're running as *.kweb.kenosisp2p.org
        if hostOverride:
            realHost = hostOverride

        self.headers["Host"] = realHost
        self.headers["Connection"] = "close"
        
        realUrl = "http://%s" % (realHost + self.path)
        addr = kenosis.randomNodeAddress()

        nodes = self.node_.findNearestNodes(nodeAddress=addr, serviceName="kweb")
        if not nodes:
            nodes = [(self.node_.nodeAddress(), "")]
        headersToSend = dict(self.headers.items())
        for nodeAddr, netAddr in nodes:
            try:
                response_code, headers, data = self.node_.rpc(nodeAddress=nodeAddr).kweb.fetchUrl(realUrl, headersToSend, 0)
            except kenosis.KenosisError, e:
                dsunittest.traceException("error with nodeAddress %s, netAddress %s" % (nodeAddr, netAddr))
                lastError = e
            else:
                break
        else:
            from cgi import escape
            self.send_error(500, "No kenosis node found: <pre>%s</pre>" % escape(str(lastError)))
            return
        

        self.send_response(response_code)
        for k,v in headers.items():
            sys.stderr.write("sending back header %s: %s\n" % (k,v))
            self.send_header(k,v)
        self.end_headers()
        self.wfile.write(str(data))
        
        
class KenosisWebServer(SocketServer.ThreadingMixIn,
                       BaseHTTPServer.HTTPServer):
    def __init__(self):
        BaseHTTPServer.HTTPServer.__init__(self, ('', 8091), KenosisWebRequestHandler)
        self.node_ = kenosis.Node(configPath=".kwebd")
        KenosisWebRequestHandler.node_ = self.node_
        self.handler_ = KenosisWebServiceHandler(node=self.node_)
        self.node_.registerNamedHandler(name="kweb", handler=self.handler_)
        


def test():
    #global hostOverride
    #hostOverride = "kenosis.sourceforge.net"
    if "--trace" in sys.argv:
        dsunittest.setTraceLevel(1)
    #n = kenosis.Node(configPath=".kwebd2")
    #n.registerService(name="kweb", handler=KenosisWebServiceHandler(node=n))
        
    httpd = KenosisWebServer()

    sa = httpd.socket.getsockname()
    print "Serving HTTP on", sa[0], "port", sa[1], "..."
    httpd.serve_forever()

if __name__ == '__main__':
    test()
