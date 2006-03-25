from ds import dsunittest

taskLists = []
def step():
    for t in taskLists:
        t.step()
    
class TaskList:
    def __init__(self, maxThreads, fractionOfCpu=1.0):
        self.tasks_ = []
        self.results_ = []
        self.numTasksCompleted_ = 0
        self.numTasksAdded_ = 0
        self.started_ = False
        taskLists.append(self)

    def addCallableTask(self, callableObject, id=None):
        self.tasks_.append(callableObject)
        self.numTasksAdded_ += 1
        if self.started_:
            for t in self.tasks_:
                self.runOneTask(t)


    def runOneTask(self, task):
        self.tasks_.remove(task)
        dsunittest.trace("running task: %s" % task)
        self.results_.append(task())
        self.numTasksCompleted_ += 1

    def step(self):
        for t in self.tasks_:
            self.results_.append(t())
            self.numTasksCompleted_ += 1

    def start(self, wait):
        self.started_ = True
        for t in self.tasks_:
            self.runOneTask(t)
        return 'you are using MockTask'
        
    def stop(self, wait=False):
        pass

    def waitForOneTask(self):
        self.runOneTask(self.tasks_[0])
        return [self.results_.pop()]
    def waitForAllTasks(self):
        for t in self.tasks_:
            self.runOneTask(t)
        res = self.results_
        self.results_ = []
        return res

    def numTasksCompleted(self):
        return self.numTasksCompleted_
    def numTasksAdded(self):
        return self.numTasksAdded_
    def numTasksActive(self):
        return len(self.activeTasks())
    def activeTasks(self):
        return [("asdf","asdf") for x in self.tasks_]

    
if __name__ == "__main__":
    t = TaskList(maxThreads=1)
    def lf():
        return 42
    t.addCallableTask(lf)
    t.addCallableTask(lf)
    t.addCallableTask(lf)

    t.start(wait=0)
    while t.numTasksCompleted() < t.numTasksAdded():
        r = t.waitForOneTask()
        assert r == [42]
    assert t.numTasksCompleted() == 3
    assert t.numTasksAdded() == 3
