from __future__ import generators

import os
import sys
import time

sys.path.append(os.path.join(os.getcwd(), sys.path[0], "../.."))
import dsunittest
import dsthread
import task

def gen():
    for i in range(10):
        time.sleep(1)
        yield i

array = []

def gen2():
    yield 0
    yield array[0].next()

class Test(dsunittest.TestCase):
    def test(self):
        g = gen2()
        array.append(g)
        g.next()
        self.assertRaises(ValueError, g.next)

    def testTasks(self):
        output = []
        taskList = task.TaskList(maxThreads=10)
        g = gen()
        for id in range(10):
            def taskFunction(output=output, id=id, g=g):
                i = g.next()
                dsunittest.trace("taskFunction %s" % i)
                output.append(i)
                return i
            taskList.addTask(task=task.LambdaTask(lambdaFunction=taskFunction, id=id))
        self.assertEquals(output, [])
        self.assertRaises(task.WaitError, taskList.start, wait=1)

if __name__ == "__main__":
    dsunittest.main()
 
