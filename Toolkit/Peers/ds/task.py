import copy
import gc
import sys
import thread
import threading
import traceback
import time
import weakref

from ds import dsthread
from ds import dstraceback
from ds import dsunittest
from ds import dsbase

class WaitError(Exception):
    def __init__(self, exceptionThreadPairs):
        self.exceptionThreadPairs_ = exceptionThreadPairs
    def __str__(self):
        subExceptionStrings = \
               ["Sub exception from thread %s\n%s\n" % (e[1], "".join(traceback.format_exception(e[0][0], e[0][1], e[0][2]))) for e in self.exceptionThreadPairs_]
        return ("<WaitError<" + "".join(subExceptionStrings) + ">WaitError>")

def maybeSleep():
    # Everything that we do here makes our cpu usage worse so we are
    # going to do nothing. We would like, though, to sleep for a
    # little while regularly to make our cpu usage more nearly
    # uniform.
    return
    currentThread = threading.currentThread()
    if hasattr(currentThread, "task_taskList"):
        taskList = currentThread.task_taskList()
        sleepTime = taskList._sleepTime(startTime=currentThread.task_startTime)
        taskList._sleep(sleepTime=sleepTime)
        currentThread.task_startTime = time.time()

class WeakInstance:
    def __init__(self, instance):
        self.wr_ = weakref.ref(instance)
    def __getattr__(self, name):
        return getattr(self.wr_(), name)
    def __setattr__(self, name, value):
        return setattr(self.wr_(), name, value)

class Task:
    def __init__(self, id=None):
        self.id_ = id

    # You should implement this but you do not strictly have to.
    def run(self):
        pass
    def id(self):
        if self.id_ is None:
            return hash(self)
        else:
            return self.id_

class LambdaTask(Task):
    def __init__(self, lambdaFunction, id=None):
        Task.__init__(self, id=id)
        self.lambdaFunction_ = lambdaFunction

    def run(self):
        return self.lambdaFunction_()
        
class TaskList(dsbase.Base):
    def __init__(self, maxThreads, fractionOfCpu=1.0):
        dsbase.Base.__init__(self)
        self.waitingTasks_ = []
        self.tasksSemaphore_ = threading.Semaphore(0)
        self.tasksLock_ = threading.Lock()
        self.taskInfosById_ = {}
        self.allComplete_ = threading.Event()
        self.allComplete_.set()
        self.anyComplete_ = threading.Event()
        self.activeTasks_ = 0
        self.maxThreads_ = maxThreads
        self.fractionOfCpu_ = fractionOfCpu
        self.threads_ = None
        self.returnValues_ = []
        self.exceptionThreadPairs_ = []
        self.waiting_ = 0
        self.stopping_ = 0
        self.numTasksAdded_ = 0
        self.numTasksCompleted_ = 0

    def addCallableTask(self, callableObject, id=None):
        assert callable(callableObject)
        self.addTask(task=LambdaTask(lambdaFunction=callableObject, id=id))

    def addCallableTaskWithArgs(self, callableObject, *args, **kwargs):
        def lf():
            return callableObject(*args, **kwargs)
        self.addCallableTask(callableObject=lf)

    # This should only be called from the main thread.
    def addTask(self, task):
        assert not self.stopping_
        self.tasksLock_.acquire()
        try:
            if not self.taskInfosById_.has_key(task.id()):
                self.taskInfosById_[task.id()] = {"task":task, "active":0}
                self.waitingTasks_.append(task)
                self.tasksSemaphore_.release()
                self.allComplete_.clear()
                self._print(status="added", task=task)
                self.numTasksAdded_ += 1
        finally:
            self.tasksLock_.release()

    def __start(self):
        # You may not start me once you have stopped me.
        assert not self.stopping_

        # After this point the threads will be running.
        assert not self.threads_
        self.threads_ = [weakref.ref(dsthread.newThread(
            function=self._worker, name="task-idle-worker"))
                         for x in range(self.maxThreads_)]
        currentThread = threading.currentThread()

    # This should only be called from the main thread. It is ok to
    # call it more than once, but you must not call it after you have
    # called it with wait=1.
    def start(self, wait):
        self._print(status="started task list, wait is %s" % wait, task=None)

        if wait:
            self.waiting_ = 1

        self.__start()

        if wait:
            self.allComplete_.wait()
            if len(self.exceptionThreadPairs_):
                raise WaitError(exceptionThreadPairs=self.exceptionThreadPairs_)
            return self.returnValues_

    def waitForAllTasks(self):
        while not self.allComplete_.isSet():
            self.waitForOneTask()
            
    # Instead of starting me you can call this until I return a false
    # value. If more than one task has completed you will get more
    # than one return value.
    def waitForOneTask(self):
        if self.numTasksAdded_ == self.numTasksCompleted_ and len(self.returnValues_) == 0:
            return None
        if not self.threads_:
            self.waiting_ = 1
            self.__start()

        self.anyComplete_.wait()
        self.tasksLock_.acquire()
        try:
            self.anyComplete_.clear()
            if len(self.exceptionThreadPairs_):
                exceptionThreadPairs = self.exceptionThreadPairs_
                self.exceptionThreadPairs_ = []
                raise WaitError(exceptionThreadPairs=exceptionThreadPairs)
            assert self.returnValues_
            returnValues = self.returnValues_
            self.returnValues_ = []
            return returnValues
        finally:
            self.tasksLock_.release()

    def numTasksCompleted(self):
        return self.numTasksCompleted_
    def numTasksAdded(self):
        return self.numTasksAdded_
    def numTasksActive(self):
        return self.activeTasks_

    def numChildTasksTotal(self):
        count = 0
        foundAny = 0
        for id, taskInfo in self.taskInfosById_.items():
            if taskInfo["active"]:
                t = taskInfo["task"].taskThread_
                #print(repr(t))
                if hasattr(t, "numChildTasksTotal_"):
                    count = count + t.numChildTasksTotal_
                    foundAny = 1

        #print("foundAny %u, count %u" % (foundAny, count))
        if foundAny:
            return count
        else:
            return -1
    
    def numChildTasksCompleted(self):
        count = 0
        for id, taskInfo in self.taskInfosById_.items():
            if taskInfo["active"]:
                t = taskInfo["task"].taskThread_
                if hasattr(t, "numChildTasksCompleted_"):
                    count = count + t.numChildTasksCompleted_
        return count
            
    def taskStatus(self):

        self.tasksLock_.acquire()
        try:
            statuses = []
            for id, taskInfo in self.taskInfosById_.items():
                if taskInfo["active"]:
                    theThread = taskInfo["task"].taskThread_
                    if hasattr(theThread, "lastTraceTime_"):
                        lastLogTime = theThread.lastTraceTime_
                        lastLogAge = time.time() - lastLogTime
                        timeString = "%u (%u seconds ago)" % (lastLogTime, lastLogAge)
                    else:
                        timeString = "<never logged>"
                    if theThread:
                        threadName = theThread.getName()
                    else:
                        threadName = "<finished>"
                    statuses.append((id, taskInfo["active"], "%s, %s" % (threadName, timeString)))
            for t in self.waitingTasks_:
                id = t.id()
                taskInfo = self.taskInfosById_[id]
                assert not taskInfo["active"]
                statuses.append((id, taskInfo["active"], "not active"))
            return statuses
        finally:
            self.tasksLock_.release()
        
        return [(id,y["active"]) for (id,y) in self.taskInfosById_.items()]

    def activeTasks(self):
        taskStatuses = self.taskStatus()
        return [(x[0],x[2]) for x in taskStatuses if x[1]]

    def _sleepTime(self, startTime):
        if self.fractionOfCpu_ != 1.0:
            return (time.time() - startTime) / (1.0 - self.fractionOfCpu_) * self.activeTasks_
        else:
            return 0

    def _sleep(self, sleepTime):
        MaxSleepTime = 5
        if sleepTime > MaxSleepTime:
            self._print(task=None, status="wanted to sleep for %ss, reducing to %ss" % (sleepTime, MaxSleepTime))
            sleepTime = MaxSleepTime
        sleepUntil = time.time() + sleepTime
        while((time.time() < sleepUntil) and not self.stopping_):
            time.sleep(min(1, sleepTime))

    def _stop(self):
        # I am not allowed to stop if no one is waiting for me.
        assert self.waiting_
        self.stop()

    def stop(self, wait=False):
        self.stopping_ = 1
        # This is to wake up all of the threads that are or will be
        # blocked on this, waiting for a new task.
        if self.threads_:
            for t in self.threads_:
                dsthread.stopThread(t=t())
            del t
        for i in range(self.maxThreads_):
            self.tasksSemaphore_.release()
        self.allComplete_.set()
        if wait:
            for t in self.threads_:
                t2 = t()
                if t2:
                    t2.join()

    def __traceFunc(self, frame, event, arg):
        t = threading.currentThread()
        t.lastTraceBack_ = traceback.extract_stack()

    def _print(self, status, task):
        if task:
            taskString = str(task.id())
        else:
            taskString = ""
        dsunittest.trace("TaskList(id=%u): %s %s (active %u, waiting %u)" %
                         (id(self), status, taskString, self.activeTasks_, len(self.waitingTasks_)))

    def isTaskActive(self, id):
        if self.taskInfosById_.has_key(id):
            return self.taskInfosById_[id]["active"]
        return 0
    
    def _worker(self):
        try:
            #Enable this for super tracing
            #sys.settrace(self.__traceFunc)

            threading.currentThread().task_taskList = weakref.ref(self)

            while 1:
                self.tasksSemaphore_.acquire()

                if self is None:
                    return

                self.tasksLock_.acquire()
                try:
                    if self.waiting_ and len(self.waitingTasks_) == 0:
                        return
                    if self.stopping_:
                        return
                    assert not len(self.waitingTasks_) == 0

                    (t,) = self.waitingTasks_[:1]
                    del self.waitingTasks_[:1]
                    assert self.taskInfosById_[t.id()]["active"] == 0
                    self.taskInfosById_[t.id()]["active"] = 1
                    self.activeTasks_ += 1
                    numReallyActive = 0
                    for (id, info) in self.taskInfosById_.items():
                        if info["active"]:
                            numReallyActive += 1
                    assert numReallyActive == self.activeTasks_
                    self._print(status="started", task=t)
                finally:
                    self.tasksLock_.release()

                t.taskThread_ = threading.currentThread()
                t.taskThread_.setName(str(t.id()))

                returnValueShouldBeSet = 0
                sleepTime = 0
                if not self.stopping_:
                    try:
                        t.taskThread_.task_startTime = time.time()
                        returnValue = t.run()
                        sleepTime = self._sleepTime(startTime=t.taskThread_.task_startTime)
                        returnValueShouldBeSet = 1
                    except dsthread.ThreadStoppingError:
                        pass
                    except:
                        type, value, traceback = sys.exc_info()
                        self.exceptionThreadPairs_.append(((type, value, traceback), t.taskThread_))
                        if self.waiting_:
                            self._stop()
                        else:
                            # If someone is waiting then I know that they will get the execptions
                            # so I don't need to log them here.
                            dsunittest.traceException(text="Execption while handling task %s" % repr(t))

                t.taskThread_ = None

                self.tasksLock_.acquire()
                try:
                    if returnValueShouldBeSet:
                        self.returnValues_.append(returnValue)
                    self.activeTasks_ -= 1
                    self.numTasksCompleted_ += 1
                    del self.taskInfosById_[t.id()]
                    self._print(status="finished", task=t)
                    self.anyComplete_.set()
                    if self.activeTasks_ == 0 and len(self.waitingTasks_) == 0:
                        if self.waiting_:
                            self._stop()
                            return

                        # This is an attempt to make the task list
                        # stop automatically when there are no
                        # outstanding references to it but it is
                        # flawed: we cannot call stop when
                        # self.waiting_ is false.
                        #elif len(gc.get_referrers(self)) == len(self.threads_):
                        #    self._stop()
                        #    return
                        else:
                            #print("num refs on inactive is: %s" % len(gc.get_referrers(self)))
                            pass
                finally:
                    if self.activeTasks_ == 0 and len(self.waitingTasks_) == 0:
                        self.allComplete_.set()
                    self.tasksLock_.release()
                self._sleep(sleepTime=sleepTime)
        except:
            dsunittest.traceException(text="Exception from task._worker")

# This manages a set of tasks lists, each with a name.
class NamedTaskList:
    def __init__(self):
        self.pools_ = {}

    def setMaxThreadsForTaskList(self, taskListName, maxThreads, fractionOfCpu=1.0):
        # You must not set the max threads for a list twice.
        assert not self.pools_.has_key(taskListName)
        self.pools_[taskListName] = TaskList(maxThreads=maxThreads, fractionOfCpu=fractionOfCpu)

    def taskLists(self):
        return self.pools_.items()

    def namedTaskList(self, taskListName):
        return self.pools_[taskListName]

    def addTask(self, taskListName, task):
        self.pools_[taskListName].addTask(task=task)

    def start(self, wait):
        for pool in self.pools_.values():
            pool.start(wait=wait)
