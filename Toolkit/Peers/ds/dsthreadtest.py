import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName("dsthread.py")

import task
import dsthread

import time

class Test(dsunittest.TestCase):
    def testSections(self):
        dsthread.assertEnterNamedSection(name="hello")
        dsthread.leaveNamedSection(name="hello")

        dsthread.blockEnterNamedSection(name="hello")
        dsthread.leaveNamedSection(name="hello")

        dsthread.assertEnterNamedSection(name="hello")
        self.assertRaises(AssertionError, dsthread.assertEnterNamedSection, name="hello")
        dsthread.leaveNamedSection(name="hello")

        self.assertRaises(AssertionError, dsthread.leaveNamedSection, name="hello")
        
    def testSectionsWithThreads(self):
        tl = task.TaskList(maxThreads=2)
        def func():
            for i in range(100):
                dsunittest.trace("entering")
                dsthread.blockEnterNamedSection(name="hello2")
                dsunittest.trace("leaving")
                dsthread.leaveNamedSection(name="hello2")
        tl.addTask(task=task.LambdaTask(lambdaFunction=func, id="thread0"))
        tl.addTask(task=task.LambdaTask(lambdaFunction=func, id="thread1"))
        tl.start(wait=1)

    def testPropagatingValues(self):
        dsthread.setPropagatingThreadValue("myKey", "myValue")
        self.assertEquals(dsthread.propagatingThreadValue("myKey"), "myValue")
        def lf():
            self.assertEquals(dsthread.propagatingThreadValue("myKey"), "myValue")
            dsthread.leaveNamedSection(name="mySection")
        dsthread.blockEnterNamedSection(name="mySection")
        dsthread.newThread(lf, ())
        dsthread.blockEnterNamedSection(name="mySection")

    def testPool(self):
        pool = dsthread.ThreadPool(maxThreads=5)
        def lf1():
            return 5
        def lf2():
            return 6
        self.assertEquals(pool.run(lf1), 5)
        self.assertEquals(pool.run(lf2), 6)

        for i in range(10):
            def lf(i=i):
                return i
            self.assertEquals(pool.run(lf), i)

    def testMultithreadEvent(self):
        me = dsthread.MultithreadEvent()
        finishedThreads = []
        def lf():
            me.wait()
            finishedThreads.append(1)
        numThreads = 2
        for x in range(numThreads):
            dsthread.newThread(function=lf)

        self.assertEquals(len(finishedThreads), 0)
        me.set()

        time.sleep(1)

        self.assertEquals(len(finishedThreads), numThreads)
            
if __name__ == "__main__":
    dsunittest.main()
