#  Copyright (C) 2004  IMVU, inc http://www.imvu.com
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
import os
import sys
sys.path.append(os.path.join(os.getcwd(), sys.path[0], ".."))
 
import gc
import tempfile
import threading
import time
import weakref

import unittest

from threading import Event

import mock
import cachetools

class Test(unittest.TestCase):
    
    def setUp(self):
        reload(cachetools)
        cachetools.time.time = mock.MockTimeFunc
        mock.SetupMockFileFunctionsForModule(cachetools)
        
    def tearDown(self):
        reload(cachetools)
        
    def return42(self):
        return 42
    def returnAsdf(self):
        return "asdf"
    
    def testSimple(self):
        container = cachetools.CacheContainer(timeout=60, factoryFunction=self.return42)
        self.assertEqual(container.value(), 42)
        container.setFactoryFunction(self.returnAsdf)
        self.assertEqual(container.value(), 42)
        mock.timeAdded += 65
        self.assertEqual(container.value(), "asdf")
        container.setFactoryFunction(self.return42)
        container.setTimeout(600)
        mock.timeAdded += 65
        self.assertEqual(container.value(), "asdf")
        mock.timeAdded += 605
        self.assertEqual(container.value(), 42)

    def returnId(self, id):
        return id
    def returnIdPlus(self, id):
        return id + 100
    
    def testDict(self):
        container = cachetools.CacheDict(timeout=60, factoryFunction=self.returnId)
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=False), None)
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=True), i)
        for i in range(20):
            if i in range(10):
                self.assertEqual(container.valueForId(i, refreshIfStale=False), i)
            else:
                self.assertEqual(container.valueForId(i, refreshIfStale=False), None)
        container.setFactoryFunction(self.returnIdPlus)
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=True), i)
        mock.timeAdded += 65
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=True), i+100)

    def dont_testDisk(self):
        path = "test.pickle"
        self.assertEqual(mock.AllFiles, [])
        container = cachetools.DiskCacheWrapper(
            timeout=60, factoryFunction=self.returnId, classToWrap=cachetools.CacheDict, path=path,
            saveTimeout=60)
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=True), i)
        assert mock.MockFileExists(path)
        mock.AllFiles = []
        container.save()
        assert mock.MockFileExists(path)
        
        container = cachetools.DiskCacheWrapper(
            timeout=600, factoryFunction=self.returnIdPlus,
            classToWrap=cachetools.CacheDict, path=path,
            saveTimeout=60)
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=False), i)

        mock.timeAdded += 605
        for i in range(10):
            self.assertEqual(container.valueForId(i, refreshIfStale=True), i+100)


    def testDisk2(self):
        path = "test.pickle"
        self.assertEqual(mock.AllFiles, [])
        container = cachetools.DiskCacheWrapper(classToWrap=cachetools.CacheDict2, path=path, saveTimeout=60)
        for i in range(10):
            container.setValueForId(id=i, value=i)
        for i in range(10):
            self.assertEqual(container.valueForId(id=i), i)
        assert mock.MockFileExists(path)
        mock.AllFiles = []
        container.save()
        assert mock.MockFileExists(path)
        
        container = cachetools.DiskCacheWrapper(classToWrap=cachetools.CacheDict2, path=path, saveTimeout=60)
        for i in range(10):
            self.assertEqual(container.valueForId(i), i)

if __name__ == "__main__":
    unittest.main(argv=sys.argv)

