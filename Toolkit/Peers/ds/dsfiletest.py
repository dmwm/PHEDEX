import os
import sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], "../.."))

import dsfile
import dsunittest

import random
import socket
import tempfile
import time

class Test(dsunittest.TestCase):
    def test(self):
        name = tempfile.mktemp()
        data = "hello"
        data2 = "I won't do what you tell me"
        dsfile.ensureAbsent(path=name)
        assert not os.path.exists(name)
        dsfile.setFileContents(filename=name, data=data)
        assert os.path.exists(name)
        self.assertEqual(data, dsfile.fileContents(filename=name))
        f = open(name, "r+")
        self.assertEqual(data, dsfile.fileContents(file=f))
        dsfile.setFileContents(file=f, data=data2)
        self.assertEqual(data2, dsfile.fileContents(file=f))
        self.assertEqual(data2, dsfile.fileContents(filename=name))

        # the following assert only works on win32
        if sys.platform == "win32":
            self.assertRaises(OSError, dsfile.ensureAbsent, name )
        
        f.close() # important on win32, or next line will fail (read lock)
        dsfile.ensureAbsent(path=name)
        assert not os.path.exists(name)

    def test2(self):
        name = tempfile.mktemp()
        data = "asdfsad"
        dsfile.setFileContents(filename=name, data=data)
        assert os.path.exists(name)
        dsfile.ensureAbsent(path=name)
        assert not os.path.exists(name)

    def testFileObject(self):
        name = tempfile.mktemp()
        object = {"key":5}
        dsfile.setFileObject(path=name, object=object)
        object2 = dsfile.fileObject(path=name)
        self.assertEqual(object, object2)

    def test3(self):
        name = tempfile.mktemp()
        dsfile.ensureAbsent(path=name)
        assert not os.path.exists(name)

    def testMockSocket(self):
        class MockSocket:
            def __init__(self):
                self.data_ = "a\nb\nhello"
            def recv(self, max):
                if len(self.data_):
                    d = self.data_
                    self.data_ = ""
                    return d
                else:
                    return ""
            def setblocking(self, blocking):
                pass
            def makefile(self, *args):
                return None

        sock = MockSocket()
        wrap = dsfile.AsyncSocketFile(sock=sock, timeout=0)
        self.assertEqual(wrap.readline(), "a\n")
        self.assertEqual(wrap.readBuffer_, "b\nhello")
        self.assertEqual(wrap.readline(), "b\n")
        self.assertEqual(wrap.readBuffer_, "hello")
        self.assertEqual(wrap.read(1), "h")

    def testPlainRealSocket(self):
        HOST = 'localhost'                 # Symbolic name meaning the local host
        PORT = 50000 + random.randrange(1000)
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        writer = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind((HOST, PORT))
        listener.listen(1)
        writer.connect((HOST, PORT))
        reader, addr = listener.accept()

        try:
            writer.send("hello")
            self.assertEqual(reader.recv(10), "hello")

            reader.setblocking(0)
            self.assertRaises(socket.error, reader.recv, 10)

            writer.close()
            self.assertEqual("", reader.recv(10))

        finally:
            reader.close()
            listener.close()

    def testRealSocket(self):
        HOST = 'localhost'                 # Symbolic name meaning the local host
        PORT = 50000 + random.randrange(1000)
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        writer = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind((HOST, PORT))
        listener.listen(1)
        writer.connect((HOST, PORT))
        reader, addr = listener.accept()

        try:
            writer.send("hello")
            self.assertEqual(reader.recv(10), "hello")

            reader.setblocking(0)
            self.assertRaises(socket.error, reader.recv, 10)

            wrap = dsfile.AsyncSocketFile(sock=reader, timeout=1)
            writer.send("a\nb\nhello")
    
            self.assertEqual(wrap.readline(), "a\n")
            self.assertEqual(wrap.readBuffer_, "b\nhello")
            self.assertEqual(wrap.readline(), "b\n")
            self.assertEqual(wrap.readBuffer_, "hello")
            self.assertEqual(wrap.read(1), "h")

            self.assertRaises(dsfile.Timeout, wrap.readline)
        finally:
            reader.close()
            writer.close()
            listener.close()

if __name__ == "__main__":
    dsunittest.main()
 
