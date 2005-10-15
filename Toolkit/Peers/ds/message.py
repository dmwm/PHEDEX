import dsunittest
import dsthread

import threading
import time
import weakref

class Message:
    # This will always return something.
    def messageString(self): return self.messageString_
    # May return None.
    def assetId(self): return self.assetId_
    # May return None
    def path(self): return self.path_

    def __init__(self, messageString, assetId=None, path=None, resourceId=None):
        self.messageString_ = messageString
        self.assetId_ = assetId
        self.path_ = path
        self.resourceId_ = resourceId
        self.timeStamp_ = time.time()
    def __str__(self):
        str = "%s: %s\n" % (time.ctime(self.timeStamp_), self.messageString_)
        if self.assetId_: str += "  assetId: '%s'" % self.assetId_
        if self.path_: str += "  path: '%s'" % self.path_
        if self.resourceId_: str += "  resourceId: '%s'" % repr(self.resourceId_)
        #str += "\n"
        return str

class DebugMessage(Message, Exception):
    def __str__(self):
        return "DebugMessage: " + Message.__str__(self)

class ErrorMessage(Message, Exception):
    def __init__(self, messageString, assetId=None, path=None, resourceId=None, isHard=False):
        Message.__init__(self, messageString=messageString, assetId=assetId, path=path, resourceId=resourceId)
        self.isHard_ = isHard
    def __str__(self):
        return "ErrorMessage: " + Message.__str__(self)
    def isHard(self):
        return self.isHard_

class ProgressMessage(Message):
    def __init__(self, messageString, total, progress, assetId=None, path=None, resourceId=None):
        Message.__init__(self, messageString=messageString, assetId=assetId, path=path, resourceId=resourceId)
        self.total_ = float(total)
        self.progress_ = progress
    def total(self):
        return self.total_
    def progress(self):
        return self.progress_
    def __str__(self):
        if self.total_:
            progress = 100 * float(self.progress_)/ self.total_
        else:
            progress = 0
        return "ProgressMessage: %u/%u (%0.1f%%) %s" % (self.progress_, self.total_,
                                                     progress,
                                                     Message.__str__(self) )

class MessageSink:
    def handleMessage(self, message): assert None, "You need to implement this"

class NullMessageSink(MessageSink):
    def handleMessage(self, message): pass
nullMessageSink = NullMessageSink()

class LogMessageSink(MessageSink):
    def __init__(self, path):
        dsunittest.trace("Logging messages to %s" % path)
        self.file_ = open(path, "a+")
    
    def handleMessage(self, message):
        dsunittest.trace(message)
        self.file_.write(str(message) + "\n")
        self.file_.flush()

class PrintMessageSink(MessageSink):
    def handleMessage(self, message):
        print(str(message))

class RoutingMessageSink(MessageSink):
    def __init__(self, uplinkSink):
        self.sinks_ = {}
        self.uplinkSinks_ = [uplinkSink]

    def addSink(self, key, sink):
        if not self.sinks_.has_key(key):
            self.sinks_[key] = weakref.WeakKeyDictionary()
        self.sinks_[key][sink] = 1

    def addUplinkSink(self, uplinkSink):
        self.uplinkSinks_.append(uplinkSink)

    def handleMessage(self, message):
        self.handleMessageForKey(message=message, key=message.assetId())
        self.handleMessageForKey(message=message, key=message.path())
        for uplinkSink in self.uplinkSinks_:
            uplinkSink.handleMessage(message=message)

    def handleMessageForKey(self, message, key):
        if self.sinks_.has_key(key):
            for sink in self.sinks_[key].keys():
                sink.handleMessage(message=message)

class QueueMessageSink(MessageSink):
    def __init__(self):
        self.queue_ = []
        self.lock_ = threading.Lock()

    def clear(self):
        self.queue_ = []

    def getAndClearQueue(self):
        self.lock_.acquire()
        try:
            q = self.queue_
            self.clear()
            return q
        finally:
            self.lock_.release()

    def handleMessage(self, message):
        self.lock_.acquire()
        try:
            self.queue_.append(message)
        finally:
            self.lock_.release()

def setThreadMessageSink(messageSink):
    dsthread.setPropagatingThreadValue("messageSink", messageSink)

def threadMessageSink():
    try:
        return dsthread.propagatingThreadValue("messageSink")
    except KeyError:
        return None
