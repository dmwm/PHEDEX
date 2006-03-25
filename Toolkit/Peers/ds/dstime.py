import time as builtinTime
from ds import dsqueue
from ds import dsunittest

import threading

testingTime = None
eventQueue = None

def setTestingTime(time):
    global testingTime
    testingTime = time
    global eventQueue
    eventQueue = dsqueue.PriorityQueue(0)


def advanceTestingTime(by=1):
    global testingTime
    # You must call setTestingTime before calling this.
    assert not testingTime is None
    testingTime += by

    while not eventQueue.empty():
        origValue = eventQueue.get()
        wakeupTime, event = origValue
        if testingTime >= wakeupTime:
            event.set()
        else:
            eventQueue.put(origValue)
            break

# This will return the real time unless a testing time has been
# set. This is useful for unittesting.
def time():
    global testingTime
    if not testingTime is None:
        return testingTime
    else:
        return builtinTime.time()
    
def timeCallable(callableObject, *args, **kwargs):
    """Return a tuple of time taken and return values of
    callable. Exceptions are propogated unchanged."""

    startTime = builtinTime.time()
    returnValues = callableObject(*args, **kwargs)
    return (builtinTime.time() - startTime, returnValues)


def sleep(time):
    assert testingTime is not None
    event = threading.Event()
    eventQueue.put((testingTime+time, event))
    if time > 1:
        dsunittest.trace("dstime.sleep: going to sleep for %s" % time)
    event.wait()

def numSleepingThreads():
    return eventQueue.qsize()

