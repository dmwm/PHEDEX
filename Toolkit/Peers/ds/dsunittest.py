import re
import sys
import threading
import tempfile
import time
import traceback
import unittest
import logging
from logging import handlers

from ds import coverage

import dsfile

traceLevel = 0
annotations = []
globalTime = time.time()
baseTraceDepth = 0
standardArgv = None
measureCoverage = 0
dsTestName = None

logger = logging.getLogger("dsunittest")
stdoutLogHandler = logging.StreamHandler(sys.stdout)
logFormatter = logging.Formatter("%(message)s")
stdoutLogHandler.setFormatter(logFormatter)
logger.addHandler(stdoutLogHandler)
logger.setLevel(logging.INFO)

def setTraceLevel(level):
    assert level != 0
    global traceLevel
    traceLevel = level

def setTracePath(path):
    # We want one 10 meg log and one backup.
    handler = handlers.RotatingFileHandler(path, "a", 10 * 1024 * 1024, 1)
    handler.setFormatter(logFormatter)
    logger.addHandler(handler)
    # We want stdout logging in unit tests but not in the console app.
    logger.removeHandler(stdoutLogHandler)
    logger.info("\nStarting tracing to file")
    # We always want to see the trace if the user has asked for it.
    setTraceLevel(level=1)

def addTraceAnnotation(text, annotation):
    global annotations
    annotations.append((text, annotation))

def resetTraceDepth():
    global baseTraceDepth
    baseTraceDepth = len(traceback.extract_stack())

def trace1(text): trace(text=text, prio=1)
def trace2(text): trace(text=text, prio=2)
def trace3(text): trace(text=text, prio=3)
def trace(text, prio=1):
    global traceLevel
    global annotations
    global globalTime
    global traceFile
    global baseTraceDepth

    localTime = time.strftime("%Y-%m-%d:%H:%M:%S")
    for a in annotations:
        text = re.sub( a[0], "[%s=%s]" % a, text )

    #padding = (len(traceback.extract_stack())-baseTraceDepth) * "  "
    padding = ""
    text = "[%s %s %s]%s%s" % (localTime, prio, threading.currentThread().getName(), padding, text)
    if prio <= traceLevel:
        logger.info(text)

    t = threading.currentThread()
    t.lastTraceBack_ = traceback.extract_stack()[:-1]
    t.lastTraceTime_ = time.time()
    t.lastTraceBody_ = text

def traceException(text, prio=1):
    #traceback.print_exc()
    if prio <= traceLevel:
        logger.exception(text)

def newTempDir():
    path = tempfile.mktemp()
    dsfile.ensureDirectoryPresent(path=path)
    return path

def _parseArgs():
    global standardArgv
    global measureCoverage
    standardArgv = []
    for arg in sys.argv:
        if arg == "--trace":
            setTraceLevel(level=1)
        elif arg == "--coverage":
            measureCoverage = 1
        else:
            standardArgv.append(arg)

def setTestName(testName):
    global dsTestName
    if dsTestName:
        return
    dsTestName = testName
    _parseArgs()
    if measureCoverage:
        coverage.erase()
        coverage.start()

class IsTestProgram:
    def __init__(self):
        if standardArgv is None:
            _parseArgs()
        for arg in standardArgv:
            print(arg)
        if traceLevel:
            print("Tracing execution")
        if measureCoverage:
            print("Measuring coverage")
        try:
            realTestProgram = unittest.main(argv=standardArgv)
        except SystemExit, e:
            #print("done. Exception is %s" % repr(e.code))
            
            if not e.code and measureCoverage:
                coverage.stop()
                # Item 2 contains the list of missing statements.
                if coverage.analysis(dsTestName)[2]:
                    print("Coverage summary")
                    coverage.report([dsTestName])
                coverage.erase()
            raise
        except Exception, e:
            raise

class TestCase(unittest.TestCase):
    def assertNumbersNear(self, a, b, threshold=0.000001):
        if abs(a-b) > threshold:
            raise AssertionError("%f and %f are not within threshold %f" % (a, b, threshold))
 
def main():
    resetTraceDepth()
    IsTestProgram()


def assertEqual(a, b):
    assert a == b, "%(a)s != %(b)s" % locals() 

def assertNotEqual(a, b):
    assert a != b, "%(a)s == %(b)s" % locals() 

def assertLt(a, b):
    assert a < b, "%(a)s not < %(b)s" % locals() 

def assertLte(a, b):
    assert a <= b, "%(a)s not <= %(b)s" % locals() 
