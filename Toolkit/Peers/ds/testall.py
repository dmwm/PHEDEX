import os
import re
import unittest

class Test(unittest.TestSuite):
    def __init__(self):
        unittest.TestSuite.__init__(self)
        testNames = [re.sub("\.py", "", f) for f in os.listdir(".") if f.endswith("test.py")]
        self.addTest(unittest.defaultTestLoader.loadTestsFromNames(testNames))

if __name__ == "__main__":
    unittest.main()
