import copy
import inspect
from ds import Queue
import thread
import threading
import traceback

namedSections = {}
namedSectionsLock = threading.Lock()
ownerStackFrames = {}

def stopThread(t):
    t.stopping_ = 1

def setPropagatingThreadValue(name, value):
    __propagatingValues()[name] = value

def propagatingThreadValue(name):
   return __propagatingValues()[name]

class ThreadStoppingError(Exception): pass

mainThread = threading.currentThread()

def isMainThread():
    return threading.currentThread() == mainThread

def __propagatingValues():
    currentThread = threading.currentThread()
    if hasattr(currentThread, "stopping_"): raise ThreadStoppingError()
    if not hasattr(currentThread, "propagatingValues"):
        currentThread.propagatingValues = {}
    return currentThread.propagatingValues

__namedThreadCounters = {}

def newThread(function, params=(), name=None, start=True):
    blockEnterNamedSection(name="dsthread.newThread")
    try:
        # This inner method is here to ensure that all references to
        # the function and params are gone by the time that we return
        # to python's thread code. Python has a habit of keeping
        # references around for a long time, preventing objects from
        # being collected.
        functionAndParams = [function, params]
        def lf(functionAndParams=functionAndParams):
            functionAndParams[0](*functionAndParams[1])
            functionAndParams[:] = []
        if not name:
            name = str(function)
        if __namedThreadCounters.has_key(name):
            __namedThreadCounters[name] += 1
        else:
            __namedThreadCounters[name] = 0
        name = "%s-%u" % (name, __namedThreadCounters[name])
        newlyCreatedThread = threading.Thread(name=name, target=lf, args=())
        newlyCreatedThread.propagatingValues = copy.copy(__propagatingValues())
        newlyCreatedThread.setDaemon(True)
        if start:
            newlyCreatedThread.start()
        return newlyCreatedThread
    finally:
        leaveNamedSection(name="dsthread.newThread")

def assertEnterNamedSection(name):
    lock = __lockForName(name=name)
    if lock.acquire(0):
        assert not ownerStackFrames.has_key(name)
        ownerStackFrames[name] = traceback.extract_stack()[:-1]
        return
    else:
        ownerStackFrame = ownerStackFrames[name]
        errorString = "Two people are trying to use the section named '%s'. The first person has this stack:\n%s" % \
              (name, "".join(traceback.format_list(ownerStackFrame)))
        assert 0, errorString

def blockEnterNamedSection(name):
    global ownerStackFrames
    lock = __lockForName(name=name)
    lock.acquire()
    #===assert not ownerStackFrames.has_key(name)
    ownerStackFrames[name] = traceback.extract_stack()[:-1]

def leaveNamedSection(name):
    global namedSections
    global ownerStackFrames
    assert namedSections.has_key(name)
    lock = __lockForName(name=name)
    try:
        lockAcquired = lock.acquire(0)
        assert not lockAcquired
    finally:
        lock.release()
    try:
        del ownerStackFrames[name]
    except KeyError:
        pass

class SynchronizeAccessAdapter:
    def __init__(self, inner):
        self.inner_ = inner
        self.lock_ = threading.Lock()

    def __getattr__(self,name):
        members = inspect.getmembers(self.inner_)
        for (memberName,member) in members:
            if inspect.ismethod(member) and name == memberName:
                def lf(self=self, member=member, *args, **kwargs):
                    self.lock_.acquire()
                    try:
                        return member(*args, **kwargs)
                    finally:
                        self.lock_.release()
                return lf

        raise AttributeError



def __lockForName(name):
    global namedSectionsLock
    global namedSections
    namedSectionsLock.acquire()
    try:
        if not namedSections.has_key(name):
            l = threading.Lock()
            namedSections[name] = l
        return namedSections[name]
    finally:
        namedSectionsLock.release()

class ReadWriteLock:
    """A lock object that allows many simultaneous "read-locks", but
    only one "write-lock"."""
    
    def __init__(self, lockClass = threading.Lock()):
        self._read_ready = threading.Condition(lockClass())
        self._readers = 0

    def acquire_read(self):
        """Acquire a read-lock. Blocks only if some thread has
        acquired write-lock."""
        self._read_ready.acquire()
        try:
            self._readers += 1
        finally:
            self._read_ready.release()

    def release_read(self):
        """Release a read-lock."""
        self._read_ready.acquire()
        try:
            self._readers -= 1
            if not self._readers:
                self._read_ready.notifyAll()
        finally:
            self._read_ready.release()

    def acquire_write(self):
        """Acquire a write lock. Blocks until there are no
        acquired read- or write-locks."""
        self._read_ready.acquire()
        while self._readers > 0:
            self._read_ready.wait()

    def release_write(self):
        """Release a write-lock."""
        self._read_ready.release()


class ThreadPool:
    def __init__(self, maxThreads):
        self.maxThreads_ = maxThreads
        self.threadQ_ = Queue.Queue(self.maxThreads_)
        self.running_ = True
        for i in range(self.maxThreads_):
            self.threadQ_.put(self.__newThread())

    def __newThread(self):
        t = newThread(function=self.__worker, start=False)
        t.result_ = None
        t.callableObject_ = None
        t.doneEvent_ = threading.Event()
        t.startEvent_ = threading.Event()
        t.start()
        return t

    def run(self, callableObject):
        t = self.threadQ_.get()
        assert t.callableObject_ is None
        assert t.result_ is None
        t.callableObject_ = callableObject
        t.startEvent_.set()
        t.doneEvent_.wait()
        result, error = t.result_
        t.result_ = None
        self.threadQ_.put(t)
        if error:
            raise error
        else:
            return result

    def __worker(self):
        t = threading.currentThread()
        while self.running_:
            t.startEvent_.wait()
            t.doneEvent_.clear()
            assert t.result_ is None

            callableObject = t.callableObject_
            t.callableObject_ = None
            result = None
            error = None
            try:
                result = callableObject()
            except:
                error = sys.exc_info()[1]
            t.result_ = (result, error)
            t.startEvent_.clear()
            t.doneEvent_.set()
            
class MultithreadEvent:

    """==="""

    def __init__(self):
        self.threadEvents_ = {}

    def set(self):
        for event in self.threadEvents_.values():
            event.set()

    def clear(self):
        self.__eventForThread().clear()

    def wait(self):
        self.__eventForThread().wait()

    def __eventForThread(self):
        ct = threading.currentThread()
        if not ct in self.threadEvents_:
            self.threadEvents_[ct] = threading.Event()
        return self.threadEvents_[ct]
