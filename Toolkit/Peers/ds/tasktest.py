import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName("task.py")

import dsthread
import task
import dstime

import gc
import threading
import time
import weakref


def runningThreads():
    #threads = [t for t in threading.enumerate() if t.isAlive()]
    #print("Running threads are %s" % threads)
    threads = []
    for t in threading.enumerate():
        if t.isAlive():
            threads.append([t])
    return threads

class Test(dsunittest.TestCase):

    def setUp(self):
        self.assertEquals(threading.enumerate(), [threading.currentThread()])

    def tearDown(self):
        while threading.enumerate() != [threading.currentThread()]:
            print("Threads are: %s" % threading.enumerate())
            time.sleep(1)

    def testNormal(self):
        origThreads = runningThreads()

        output = []
        taskList = task.TaskList(maxThreads=1)
        for id in range(10):
            def taskFunction(output=output, id=id):
                output.append(id)
                return id
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        returnValues = taskList.start(wait=1)
        self.assertEquals(output, range(10))
        self.assertEquals(returnValues, range(10))

        time.sleep(1)
        self.assertEquals(runningThreads(), origThreads)

        # The list should go away when the tasks are complete.
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()

        tl = wr()
        if tl:
            refs = gc.get_referrers(tl)
            print("refs are %s" % self._objectAsString(object=refs))
            for ref in refs:
                refrefs = gc.get_referrers(ref)
                print("%s: %s" % (self._objectAsString(ref), self._objectAsString(object=refrefs)))

        assert tl is None, repr(gc.get_referrers(wr()))

    def _objectAsString(self, object):
        if type(object) == type(()):
            return "(" + ",".join([self._objectAsString(object=x) for x in object]) + ")"
        elif type(object) == type([]):
            return "[" + ",".join([self._objectAsString(object=x) for x in object]) + "]"
        elif hasattr(object, "f_code"):
            return "frame of method: %s" % object.f_code
        else:
            return str(object)

    def testThreadUtilization(self):
        origThreads = runningThreads()

        output = {}
        taskList = task.TaskList(maxThreads=10)
        taskWrs = []
        for id in range(20):
            def taskFunction(output=output, id=id):
                time.sleep(1.0)
                output[threading.currentThread()] = id
                return id
            ta = task.LambdaTask(lambdaFunction=taskFunction, id=id)
            taskWrs.append(weakref.ref(ta))
            taskList.addTask(task=ta)
            del ta
        returnValues = taskList.start(wait=1)
        tWrs = []
        for t in taskList.threads_:
            t().join()
        #    tWrs.append(weakref.ref(t))
        
                       

        #for tWr in tWrs:
        #    assert not tWr(), repr(gc.get_referrers(tWr()))
        #for taWr in taskWrs:
        #    assert not taWr(), repr([str(x.f_code) for x in gc.get_referrers(taWr()) if hasattr(x, "f_code")])
        #taskList.threads_ = []
        self.assertEquals(taskList.taskInfosById_, {})
        self.assertEquals(10, len(output.keys()))
        returnValues.sort()
        self.assertEquals(returnValues, range(20))

        # The list should go away when the tasks are complete.
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()
        import pprint
        assert wr() is None, pprint.pprint([(x,gc.get_referrers(x)) for x in gc.get_referrers(wr())])

        self.assertEquals(runningThreads(), origThreads)

    def not_testGarbageCollection(self):
        origActiveCount = threading.activeCount()

        taskList = task.TaskList(maxThreads=2)
        for id in range(10):
            def taskFunction(id=id):
                return id
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        taskList.start(wait=0)
        taskList.waitForAllTasks()

        # The list should go away when the tasks are complete.
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()
        # We would like the task list to get garbage collected when
        # there are no tasks running and there are no outside
        # references to the task list.
        assert wr() is None, self._objectAsString(gc.get_referrers(wr()))

        self.assertEquals(threading.activeCount(), origActiveCount)

    def testThreads(self):

        output = []
        taskList = task.TaskList(maxThreads=10)
        for id in range(10):
            def taskFunction(output=output, id=id):
                output.append(id)
                time.sleep(1)
                return id
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        returnValues = taskList.start(wait=0)
        taskList.waitForAllTasks()
        self.assertEquals(output, range(10))
        self.assertEquals(returnValues, None)

        taskList.stop()
        # The list should go away when the tasks are complete.
        for t in taskList.threads_:
            t().join()
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()
        assert wr() is None

    def testException(self):
        output = []
        taskList = task.TaskList(maxThreads=1)
        for id in range(10):
            def taskFunction(output=output, id=id):
                if id == 4:
                    raise "Blah"
                output.append(id)
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertRaises(task.WaitError, taskList.start, wait=1)
        self.assertEquals(output, range(4))

    def testExceptionMultipleThreads(self):
        output = []
        taskList = task.TaskList(maxThreads=2)
        for id in range(10):
            def taskFunction(output=output, id=id):
                if id == 4:
                    raise "Blah"
                output.append(id)
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertRaises(task.WaitError, taskList.start, wait=1)
        output.sort()
        self.assertEquals(output, range(4))

    def testExceptionWithoutWait(self):
        output = []
        taskList = task.TaskList(maxThreads=1)
        def errorTask(): raise "Blah"
        taskList.addTask(task=task.LambdaTask(lambdaFunction=errorTask, id=1))
        taskList.start(wait=0)
        while not len(taskList.taskInfosById_.items()) == 0: pass
        # The task has finished now. Because the task list has not
        # been told to wait it should not be stopping_, since I must
        # still be allowed to add tasks to it.
        dsunittest.trace("adding second task")
        taskList.addTask(task=task.LambdaTask(lambdaFunction=errorTask, id=1))
        dsunittest.trace("starting")
        taskList.stop()

    def testWaitForOneTask(self):
        output = []
        taskList = task.TaskList(maxThreads=1)
        for id in range(10):
            def taskFunction(output=output, id=id):
                output.append(id)
                return id
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        returnValues = taskList.waitForOneTask()
        while returnValues:
            self.assertEquals(len(output), taskList.numTasksCompleted())
            returnValues = taskList.waitForOneTask()
        self.assertEquals(len(output), taskList.numTasksCompleted())
        self.assertEquals(output, range(10))

    def testWaitForOneTask2(self):
        output = []
        taskList = task.TaskList(maxThreads=1)
        for id in range(10):
            def taskFunction(output=output, id=id):
                output.append(id)
                return id
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        taskList.start(wait=0)
        while not taskList.numTasksCompleted() == taskList.numTasksAdded():
            time.sleep(0.2)
        # By now all tasks should have completed.
        returnValues = taskList.waitForOneTask()
        self.assertEquals(len(returnValues), taskList.numTasksCompleted())
        returnValues = taskList.waitForOneTask()
        self.assertEquals(returnValues, None)
        self.assertEquals(len(output), taskList.numTasksCompleted())
        self.assertEquals(output, range(10))
        taskList.stop()

    def testStop(self):
        output = []
        taskList = task.TaskList(maxThreads=1)
        for id in range(2):
            def taskFunction(output=output, id=id):
                dsthread.blockEnterNamedSection(name="testStop2")
                dsthread.leaveNamedSection(name="testStop3")
                dsthread.blockEnterNamedSection(name="testStop")
                output.append(id)
                dsthread.leaveNamedSection(name="testStop")
                dsthread.leaveNamedSection(name="testStop2")
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        dsthread.blockEnterNamedSection(name="testStop3")
        dsthread.blockEnterNamedSection(name="testStop")
        returnValues = taskList.start(wait=0)
        self.assertEquals(returnValues, None)
        dsthread.blockEnterNamedSection(name="testStop3")
        dsthread.leaveNamedSection(name="testStop3")
        taskList.stop()
        dsthread.leaveNamedSection(name="testStop")
        dsthread.blockEnterNamedSection(name="testStop2")
        dsthread.leaveNamedSection(name="testStop2")
        self.assertEquals(output, [0])

        # The list should go away when the tasks are complete.
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()
        assert wr() is None

    def testStop2(self):
        output = []
        taskList = task.TaskList(maxThreads=2)
        for id in range(1):
            def taskFunction(output=output, id=id):
                dsthread.leaveNamedSection(name="testStop3")
                dsthread.blockEnterNamedSection(name="testStop2")
                dsthread.blockEnterNamedSection(name="testStop")
                output.append(id)
                dsthread.leaveNamedSection(name="testStop")
                dsthread.leaveNamedSection(name="testStop2")
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        dsthread.blockEnterNamedSection(name="testStop3")
        dsthread.blockEnterNamedSection(name="testStop")
        returnValues = taskList.start(wait=0)
        self.assertEquals(returnValues, None)
        dsthread.blockEnterNamedSection(name="testStop3")
        dsthread.leaveNamedSection(name="testStop3")
        taskList.stop()
        dsthread.leaveNamedSection(name="testStop")
        dsthread.blockEnterNamedSection(name="testStop2")
        dsthread.leaveNamedSection(name="testStop2")
        self.assertEquals(output, [0])

        # The list should go away when the tasks are complete.
        wr = weakref.ref(taskList)
        assert wr() is taskList
        taskList = None
        gc.collect()
        assert wr() is None

    def testCpuFraction(self):
        taskList0 = task.TaskList(maxThreads=2, fractionOfCpu=0.1)
        for x in range(5): taskList0.addCallableTask(callableObject=lambda: time.sleep(0.1))
        duration0, junk = dstime.timeCallable(callableObject=taskList0.start, wait=1)

        taskList1 = task.TaskList(maxThreads=2, fractionOfCpu=1.0)
        for x in range(5): taskList1.addCallableTask(callableObject=lambda: time.sleep(0.1))
        duration1, junk = dstime.timeCallable(callableObject=taskList1.start, wait=1)

        # We expect the list that gets less of the cpu to take longer to run its tasks.
        assert duration0 > duration1

if __name__ == "__main__":
    dsunittest.main()
