"""
HTTPTransport provides an urllib2 based communications channel for use 
in xmlrpclib.

Created by Bill Bumgarner <bbum@mac.com>.

Using HTTPTransport allows the XML-RPC library to take full advantage 
of the features perpetuated by urllib2, including HTTP proxy support 
and a number of different authentication schemes.  If urllib2 does not 
provide a handler capable of meeting the developer's need, the 
developer can create a custom Handler without requiring any changes to 
the XML-RPC code.

Example usage:

def serverProxyForUrl(uri, transport=None, encoding=None, verbose=0):
     if not transport:
          transport = HTTPTransport.HTTPTransport(uri, proxyUrl, 
proxyUser, proxyPass)
     return  xmlrpclib.ServerProxy(uri, transport, encoding, verbose)
"""
import xmlrpclib
from xmlrpclib import ProtocolError
from urllib import splittype, splithost
import urllib2
import httplib
import socket
import sys
import time

from ds import message
from ds import dsunittest

class _TransportConnection:
     pass

class FileToMessageWrapper:
     def __init__(self, sink, size, realfile):
         self.sink_ = sink
         self.size_ = float(size)
         self.readSoFar_ = 0
         self.realfile_ = realfile
         self.oldPct_ = 0
         self.startTime_ = time.time()

     def read(self, bytes=0):
         ret = self.realfile_.read(bytes)
         if ret:
             self.readSoFar_ += len(ret)
             newPct = self.readSoFar_/self.size_
             if newPct - self.oldPct_ > 0.0085:
                  elapsed = float(time.time() - self.startTime_)
                  if elapsed:
                       kbps = (float(self.readSoFar_)/1024) / elapsed
                  else:
                       kbps = 0
                  self.oldPct_ = newPct
                  progressMessage = message.ProgressMessage(
                       messageString="%u bytes (%0.1f kbps) read from %s" % (self.readSoFar_, kbps, self.realfile_.url),
                       progress=self.readSoFar_,
                       total=self.size_)
                  self.sink_.handleMessage(message=progressMessage)
         return ret

     def close(self, *args, **kwargs):
         return self.realfile_.close(*args, **kwargs)


def _fixHandlerArrayOrder(handlers):
     insertionPoint = 0
     for handlerIndex in range(0, len(handlers)):
          aHandler = handlers[handlerIndex]
          if isinstance(aHandler, urllib2.ProxyHandler):
               del handlers[handlerIndex]
               handlers.insert(insertionPoint, aHandler)
               insertionPoint = insertionPoint + 1
          if isinstance(aHandler, urllib2.HTTPHandler):
               assert isinstance(aHandler, SocketTimeoutHTTPHandler)


def _fixUpHandlers(anOpener):
     ### Moves proxy handlers to the front of the handlers in anOpener
     #
     # This function preserves the order of multiple proxyhandlers, if present.
     # This appears to be wasted effort in that build_opener() chokes if there
     # is more than one instance of any given handler class in the arglist.
     _fixHandlerArrayOrder(anOpener.handlers)
     map(lambda x: _fixHandlerArrayOrder(x), 
anOpener.handle_open.values())

class SocketTimeoutHTTPClass(httplib.HTTP):
     def __init__(self, host='', port=None, strict=None, socketTimeout=None):
          self._connection_class = SocketTimeoutHTTPConnection
          httplib.HTTP.__init__(self, host=host, port=port, strict=strict)
          self._conn.socketTimeout_ = socketTimeout
          #dsunittest.trace("SocketTimeoutHTTPClass __init__")

class SocketTimeoutHTTPConnection(httplib.HTTPConnection):
     def connect(self):
        """Connect to the host and port specified in __init__."""
        #dsunittest.trace("SocketTimeoutHTTPClass::conect called")
        msg = "getaddrinfo returns an empty list"
        for res in socket.getaddrinfo(self.host, self.port, 0,
                                      socket.SOCK_STREAM):
            af, socktype, proto, canonname, sa = res
            try:
                self.sock = socket.socket(af, socktype, proto)
                if self.socketTimeout_:
                     oldTimeout = self.sock.gettimeout()
                     if oldTimeout and oldTimeout < self.socketTimeout_:
                          timeout = oldTimeout
                     else:
                          timeout = self.socketTimeout_
                     #dsunittest.trace("changing socket %s to timeout value %s" % (self.sock, timeout))
                     self.sock.settimeout(timeout)
                if self.debuglevel > 0:
                    print "connect: (%s, %s)" % (self.host, self.port)
                self.sock.connect(sa)
                # If we wanted to change the timeout once we have
                # connected we would do that by calling
                # self.sock.settimeout() here.
            except socket.error, msg:
                if self.debuglevel > 0:
                    print 'connect fail:', (self.host, self.port)
                if self.sock:
                    self.sock.close()
                self.sock = None
                continue
            break
        if not self.sock:
            raise socket.error, msg

def SocketTimeoutHTTPClassFactory(socketTimeout):
     #dsunittest.trace("SocketTimeoutHTTPClassFactory called")
     def lf(host):
          #dsunittest.trace("SocketTimeoutHTTPClass made")
          return SocketTimeoutHTTPClass(host, socketTimeout=socketTimeout)
     return lf

class SocketTimeoutHTTPHandler(urllib2.HTTPHandler):
     def __init__(self, socketTimeout):
          #dsunittest.trace("SocketTimeoutHTTPHandler created")
          self.socketTimeout_ = socketTimeout
     def http_open(self, req):
          #dsunittest.trace("SocketTimeoutHTTPHandler::http_open called")
          return self.do_open(SocketTimeoutHTTPClassFactory(self.socketTimeout_), req)

class HTTPTransport(xmlrpclib.Transport):
     """Handles an HTTP transaction to an XML-RPC server using urllib2 [eventually]."""
     def __init__(self, uri, proxyUrl=None, proxyUser=None, proxyPass=None, socketTimeout=None):
          ### this is kind of nasty.  We need the full URI for the host/handler we are connecting to
          # to properly use urllib2 to make the request.  This does not mesh completely cleanly
          # with xmlrpclib's initialization of ServerProxy.
          self.uri = uri
          self.proxyUrl = proxyUrl
          self.proxyUser = proxyUser
          self.proxyPass = proxyPass
          self.socketTimeout_ = socketTimeout

     def request(self, host, handler, request_body, verbose=0):
          # issue XML-RPC request

          h = self.make_connection(host)
          self.set_verbosity(h, verbose)

          self.send_request(h, handler, request_body)
          self.send_host(h, host)
          self.send_user_agent(h)
          self.send_content(h, request_body)

          errcode, errmsg, headers = self.get_reply(h)

          if errcode != 200:
               raise ProtocolError(
                   host + handler,
                   errcode, errmsg,
                   headers
                   )

          self.verbose = verbose

          return self.parse_response(self.get_file(h))

     def make_connection(self, host, verbose=0):
          return  _TransportConnection()

     def set_verbosity(self, connection, verbose):
          connection.verbose = verbose

     def send_request(self, connection, handler, request_body):
          connection.request = urllib2.Request(self.uri, request_body)

     def send_host(self, connection, host):
          connection.request.add_header("Host", host)

     def send_user_agent(self, connection):
          # There is no way to override the 'user-agent' sent by the UrlOpener.
          # This will cause a second User-agent header to be sent.
          # This is both different from the urllib2 documentation of add_header()
          # and would seem to be a bug.
          #
          # connection.request.add_header("User-agent", self.user_agent)
          pass

     def send_content(self, connection, request_body):
          connection.request.add_header("Content-Type", "text/xml")

     def get_reply(self, connection):
          proxyHandler = None
          if self.proxyUrl:
               if self.proxyUser:
                    type, rest = splittype(self.proxyUrl)
                    host, rest = splithost(rest)

                    if self.proxyPass:
                         user = "%s:%s" % (self.proxyUser, self.proxyPass)
                    else:
                         user = self.proxyUser

                    uri = "%s://%s@%s%s" % (type, user, host, rest)
               else:
                    uri = self.proxyUrl
               proxies = {'http':uri, 'https':uri}
               proxyHandler = urllib2.ProxyHandler(proxies)

          handler = urllib2.HTTPBasicAuthHandler()
          opener = urllib2.build_opener(SocketTimeoutHTTPHandler(socketTimeout=self.socketTimeout_), handler, proxyHandler)
          _fixUpHandlers(opener)
          try:
               connection.response = opener.open(connection.request)
          except urllib2.HTTPError, c:
               if hasattr(c, "headers"):
                    h = c.headers
               else:
                    h = ""
               return c.code, c.msg, h

          return 200, "OK", connection.response.headers

     def get_file(self, connection):
         m = message.threadMessageSink()
         if m:
             size=int(connection.response.info().getheader("Content-Length"))
             return FileToMessageWrapper(sink=m,
                                         size=size,
                                         realfile=connection.response)
         return connection.response
