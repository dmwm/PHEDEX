# dsasyncore is just like asyncore except that it provides a deferred
# callable service. You can register callables to be called the next
# time that loop is called.

from ds import dsunittest
from ds import dsqueue
from ds import dstime

import asyncore
import errno
import socket

__deferredCallablesQueue = dsqueue.PriorityQueue(maxsize=0)
__somethingHappened = False
__returnLiveSockets = False
__liveSockets = []

def callLater(callable, delay):
    __deferredCallablesQueue.put((dstime.time() + delay, callable))

# Similar to asyncore.loop except this calls deferred operations and
# returns True iff some work was performed rather than the timeout
# being reached.
def loop(timeout=0.1, returnLiveSockets=False):
    global __somethingHappened
    global __returnLiveSockets
    global __liveSockets

    __somethingHappened = False
    __returnLiveSockets = returnLiveSockets
    __liveSockets = []

    now = dstime.time()
    while not __deferredCallablesQueue.empty():
        origValue = __deferredCallablesQueue.get()
        wakeupTime, callable = origValue
        if now >= wakeupTime:
            callable()
        else:
            __deferredCallablesQueue.put(origValue)
            break

    asyncore.poll(timeout=timeout)
    if __returnLiveSockets:
        return __liveSockets
    else:
        return __somethingHappened

originalRead = asyncore.read
originalWrite = asyncore.write
originalReadwrite = asyncore.readwrite
def readWrapper(obj):
    global __somethingHappened
    __somethingHappened = True
    if __returnLiveSockets:
        __liveSockets.append(obj)
    #dsunittest.trace("%r is ready to read" % obj)
    try:
        originalRead(obj)
    except:
        dsunittest.traceException("exception while reading from socket")
def writeWrapper(obj):
    global __somethingHappened
    __somethingHappened = True
    if __returnLiveSockets:
        __liveSockets.append(obj)
    #dsunittest.trace("%r is ready to write" % obj)
    try:
        originalWrite(obj)
    except:
        dsunittest.traceException("exception while writing to socket")
def readwriteWrapper(obj, flags):
    global __somethingHappened
    __somethingHappened = True
    if __returnLiveSockets:
        __liveSockets.append(obj)
    #dsunittest.trace("%r is ready to readwrite" % obj)
    try:
        originalReadwrite(obj, flags)
    except:
        dsunittest.traceException("exception while reading or writing socket")
asyncore.read = readWrapper
asyncore.write = writeWrapper
asyncore.readwrite = readwriteWrapper

origHandleError = asyncore.dispatcher.handle_error
def handleErrorWrapper(self):
    dsunittest.traceException("exception while reading or writing socket")
    return origHandleError(self)
asyncore.dispatcher.handle_error = handleErrorWrapper

class dispatcher(asyncore.dispatcher):
    def handle_read(self):
        raise "unhandled read event"

    def handle_write(self):
        raise "unhandled write event"

    def handle_connect(self):
        raise "unhandled connect event"

    def handle_accept(self):
        raise "unhandled accept event"

    def handle_close(self):
        raise "unhandled close event"

class DebuggingDispatcher(asyncore.dispatcher_with_send):
    def log_info(self, message, type='info'):
        pass

    def recv(self, buffer_size):
        try:
            return asyncore.dispatcher.recv(self, buffer_size)
        except socket.error, why:
            if why[0] == errno.EWOULDBLOCK:
                return ""
            else:
                raise

