import os, sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
from ds import dsunittest
dsunittest.setTestName("dsqueue.py")

from ds import dsqueue

class Test(dsunittest.TestCase):
    def testPriorityQueue(self):
        q = dsqueue.PriorityQueue(0)
        for x in (0, 2, 1, 5, 8, 6, 7, 4, 3):
            q.put(x)
        out = []
        while not q.empty():
            out.append(q.get())
        self.assertEqual(out, range(9))

if __name__ == "__main__":
    dsunittest.main()
