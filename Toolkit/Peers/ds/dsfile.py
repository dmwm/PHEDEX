import __builtin__
import cPickle
import os
import re
import shutil
import socket
import tempfile
import time

import dsunittest
import dsthread

def retryWrapper(func, args, kwargs, retryCount):
    while retryCount == None or retryCount > 0:
        try:
            return func(*args, **kwargs)
        except OSError:
            if retryCount > 1:
                retryCount = retryCount - 1
            else:
                raise

def tempPathForPath(path):
    return "%s.temp" % path

# Only pass path OR file. filename is deprecated.
def _fileContents(filename=None, path=None, file=None, length=None):
    assert not (filename and path)
    if filename: path = filename
    assert not (path and file)
    if length:
        params = (length,)
    else:
        params = ()
    if path:
        path = os.path.normpath(path)
        #dsunittest.trace(">dsfile.fileContents file '%s'" % (path))
        dsthread.blockEnterNamedSection(name="dsfileLock")
        data = ""
        try:
            if not os.path.exists(path):
                realPath = tempPathForPath(path=path)
            else:
                realPath = path
            f = __builtin__.file(realPath, "rb")
            data = f.read(*params)
            f.close()
        finally:
            dsthread.leaveNamedSection(name="dsfileLock")
            #dsunittest.trace("<dsfile.fileContents file '%s', length %u" % (path, len(data)))
        return data
    elif file:
        file.seek(0)
        return file.read(*params)
    else:
        assert 0, "Pass path or file"

def fileContents(*args, **kwargs):
    return retryWrapper(func=_fileContents, args=args, kwargs=kwargs, retryCount=3)

def fileObject(*args, **kwargs):
    return cPickle.loads(fileContents(*args, **kwargs))

# Only pass filename OR file.
def setFileContents(data, path=None, filename=None, file=None):
    assert not (filename and path)
    if filename: path = filename
    assert not (path and file)
    if path:
        path = os.path.normpath(path)
        dsthread.blockEnterNamedSection(name="dsfileLock")
        try:
            # first check if the file is actually changed before writing it out again
            if os.path.exists(path):
                f = __builtin__.file(path, "rb")
                readData = f.read()
                f.close()
                if readData == data:
                    return

            #dsunittest.trace(">dsfile.setFileContents file '%s', length %u" % (path, len(data)))
            #dsunittest.trace("Writing %u bytes to file %s" % (len(data), path))
            tempFile = tempPathForPath(path=path)
            f = __builtin__.file(tempFile, "wb")
            f.write(data)
            f.close()
            if os.path.exists(path):
                deleteFileOrDirectory(path=path)
            os.rename(tempFile, path)
            if os.path.exists(tempFile):
                deleteFileOrDirectory(path=tempFile)
            # === Check that the file can be read back correctly.
            f = __builtin__.file(path, "rb")
            readData = f.read()
            f.close()
            if readData != data:
                raise "dsfile.setFileContents: error, datas do not match for file '%s'.\ndata = '%s'\nreadData = '%s'" % (path, data, readData)
        finally:
            #dsunittest.trace("<dsfile.setFileContents file '%s', length %u" % (path, len(data)))
            dsthread.leaveNamedSection(name="dsfileLock")
    elif file:
        file.seek(0)
        file.write(data)
        file.truncate()
    else:
        assert 0, "Pass path or file"

def setFileObject(object, path=None, filename=None, file=None):
    setFileContents(path=path, file=file, data=cPickle.dumps(object))

def exists(path=None, file=None):
    if file:
        return True
    return os.path.exists(path) or os.path.exists(tempPathForPath(path=path))
        
def objectMatchesFileObject(object, path=None, file=None):
    if not exists(path=path, file=file):
        return False
    dumpedFileData = fileContents(path=path, file=file)
    dumpedNewData = cPickle.dumps(object)
    return dumpedFileData == dumpedNewData

def ensureDirectoryPresent(path):
    try:
        os.makedirs(path)
    except:
        if not os.access(path, os.F_OK):
            raise

# Deprecated
def makeDirectoryPathIfNecessary(path):
    return ensureDirectoryPresent(path=path)

def ensureAbsent(path):
    if os.path.exists(path):
        deleteFileOrDirectory(path=path)
    assert not os.path.exists(path)

def _deleteFileOrDirectory(path):
    #dsunittest.trace("Deleting %s" % path)
    if os.path.isdir(path):
        for item in os.listdir(path):
            deleteFileOrDirectory(os.path.join(path, item))
        os.rmdir(path)
    else:
        os.remove(path)

def deleteFileOrDirectory(*args, **kwargs):
    return retryWrapper(func=_deleteFileOrDirectory, args=args, kwargs=kwargs, retryCount=3)

# I will return a string based on the input string that is usable as a
# filename (no illegal characters). This version is probably a little
# harsh.
def filenameFromText(text):
    return re.sub("\W", "_", text)

class Timeout(Exception): pass

# This provides file semantics on top a socket but will is
# non-blocking.
class AsyncSocketFile:
    def __init__(self, sock, timeout):
        self.socket_ = sock
        self.readBuffer_ = ""
        self.timeout_ = timeout

    def write(self, data):
        dsunittest.trace3("AsyncSocketFile writing %d bytes" % len(data))
        try:
            while data:
                written = self.socket_.send(data)
                dsunittest.trace3("  AsyncSocketFile wrote a block of %d bytes" % written)
                data = data[written:]
        finally:
            dsunittest.trace3("  AsyncSocketFile write returning")

    def read(self, numBytes):
        dsunittest.trace3("AsyncSocketFile reading data, size=%d" % numBytes)
        try:
            self.socket_.setblocking(0)
            while numBytes > len(self.readBuffer_):
                try:
                    ret = self.socket_.recv(numBytes)
                    assert len(ret) <= numBytes
                    if len(ret) == 0:
                        break
                    else:
                        self.readBuffer_ += ret
                except socket.error:
                    pass
            ret = self.readBuffer_[:numBytes]
            self.readBuffer_ = self.readBuffer_[numBytes:]
            return ret
        finally:
            self.socket_.setblocking(1)
            dsunittest.trace3("  AsyncSocketFile read returning")

    def _readline(self):
            startTime = time.time()
            while self.readBuffer_.find("\n") == -1:
                try:
                    dsunittest.trace3("_readline calling recv with timeout %f" % self.timeout_)
                    ret = self.socket_.recv(512)
                    dsunittest.trace3("_readline recv returned with timeout %f" % self.timeout_)
                    if not ret:
                        #raise "No more data. Read buffer is: %s" % self.readBuffer_
                        ret = self.readBuffer_
                        self.readBuffer_ = ""
                        return ret
                    self.readBuffer_ += ret
                except socket.error:
                    elapsed = time.time() - startTime
                    dsunittest.trace3("Elapsed is %f, timeout is %f" % (elapsed, self.timeout_))
                    if self.timeout_ and elapsed > self.timeout_:
                        dsunittest.trace3("Raising timeout at %f, timeout is %f" % (elapsed, self.timeout_))
                        raise Timeout()
                    else:
                        time.sleep(1)
            pos = self.readBuffer_.index("\n") + 1
            line = self.readBuffer_[:pos]
            self.readBuffer_ = self.readBuffer_[pos:]
            return line
    def readline(self):
        data = ""
        try:
            dsunittest.trace3("AsyncSocketFile readlining data timeout is %f" % self.timeout_)
            self.socket_.setblocking(0)
            data = self._readline()
        finally:
            dsunittest.trace3("  AsyncSocketFile readline returning %u bytes" % len(data))
            self.socket_.setblocking(1)
        return data
        
    def close(self, *args): pass
    def flush(self, *args): pass
