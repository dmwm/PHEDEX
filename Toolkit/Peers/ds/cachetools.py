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
import cPickle
import threading
import time

from ds import dsthread
from ds.dsunittest import logger

class CacheBase:
    def __init__(self, **kwargs):
        self.init(**kwargs)

    def init(self, timeout, factoryFunction):
        assert callable(factoryFunction)
        self.factoryFunction_ = None
        self.setTimeout(timeout=timeout)
        self.setFactoryFunction(factoryFunction=factoryFunction)

    def setTimeout(self, timeout):
        self.timeout_ = timeout

    def setFactoryFunction(self, factoryFunction):
        oldFunction = self.factoryFunction_
        self.factoryFunction_ = factoryFunction
        return oldFunction

class CacheContainer(CacheBase):
    def __init__(self, timeout, factoryFunction):
        CacheBase.__init__(self, timeout=timeout, factoryFunction=factoryFunction)
        self.timestamp_ = None
        self.value_ = None

    def isStale(self, now):
        return not self.timestamp_ or now - self.timestamp_ > self.timeout_

    def value(self, refreshIfStale=True):
        now = time.time()
        if self.isStale(now) and refreshIfStale:
            self.value_ = self.factoryFunction_()
            assert not callable(self.value_)
            #logger.debug("cache miss value %s timestamp %s, time %s" % (self.value_, self.timestamp_, now))
            self.timestamp_ = now
        return self.value_

    def invalidate(self):
        self.timestamp_ = None

# Untested.
class CacheDict(CacheBase):
    def __init__(self, timeout, factoryFunction):
        assert callable(factoryFunction)
        self.valueDict_ = {}
        CacheBase.__init__(self, timeout=timeout, factoryFunction=factoryFunction)

    def valueForId(self, id, refreshIfStale=True, timeoutOverride=None, extraParam=None):
        def lf(self=self, id=id, extraParam=extraParam):
            if extraParam is None:
                return self.factoryFunction_(id)
            else:
                return self.factoryFunction_(id, extraParam)
        if not self.valueDict_.has_key(id):
            self.valueDict_[id] = CacheContainer(timeout=self.timeout_, factoryFunction=lf)

        valueObject = self.valueDict_[id]
        oldTimeout = valueObject.timeout_
        try:
            valueObject.setFactoryFunction(lf)
            if timeoutOverride is not None:
                valueObject.timeout_ = timeoutOverride
            return valueObject.value(refreshIfStale=refreshIfStale)
        finally:
            valueObject.timeout_ = oldTimeout

    def setFactoryFunction(self, factoryFunction):
        CacheBase.setFactoryFunction(self, factoryFunction)
        for k,v in self.valueDict_.items():
            v.setFactoryFunction(factoryFunction)

    def setTimeout(self, timeout):
        CacheBase.setTimeout(self, timeout)
        for k,v in self.valueDict_.items():
            v.setTimeout(timeout)

    def invalidate(self):
        pass
    
class CacheDict2:
    """This one actally behaves like a dict, rather than CacheDict
    that computes its own values given the factory function"""
    def __init__(self):
        self.dict_ = {}
    def init(self): pass
    def setFactoryFunction(self, factoryFunction):
        return None

    def setValueForId(self, id, value):
        self.dict_[id] = value
    def valueForId(self, id):
        return self.dict_[id]
    def items(self):
        return self.dict_.items()

class DiskCacheWrapper:
    def __init__(self, classToWrap, path, saveTimeout, **kwargs):
        self.saveTimeout_ = saveTimeout
        self.path_ = path
        self.instance_ = None
        if os.path.exists(path):
            try:
                f = file(path, "r")
                self.instance_ = cPickle.loads(f.read())
                f.close()
                self.saveTime_ = time.time()
            except:
                logger.exception("Could not load cached data from %s" % path)
        if not self.instance_:
            self.instance_ = classToWrap(**kwargs)
            self.saveTime_ = 0
        else:
            self.instance_.init(**kwargs)
        self.lock_ = dsthread.ReadWriteLock(threading.RLock)

    def value(self, *args, **kwargs):
        self.lock_.acquire_read()
        try:
            ret = self.instance_.value(*args, **kwargs)
        finally:
            self.lock_.release_read()
        self.saveIfStale()
        return ret
        
    def valueForId(self, *args, **kwargs):
        self.lock_.acquire_read()
        try:
            ret = self.instance_.valueForId(*args, **kwargs)
        finally:
            self.lock_.release_read()
        assert not callable(ret)
        self.saveIfStale()
        return ret

    def setValueForId(self, *args, **kwargs):
        self.lock_.acquire_read()
        try:
            ret = self.instance_.setValueForId(*args, **kwargs)
        finally:
            self.lock_.release_read()
        assert not callable(ret)
        self.saveIfStale()
        return ret

    def items(self):
        return self.instance_.items()

    def save(self):
        self.lock_.acquire_write()
        try:
            logger.info("saving cached data to path %s" % self.path_)
            f = file(self.path_, "w")
            oldFunction = self.instance_.setFactoryFunction(factoryFunction=None)
            try:
                f.write(cPickle.dumps(self.instance_))
            finally:
                self.instance_.setFactoryFunction(factoryFunction=oldFunction)
                f.close()
        finally:
            self.lock_.release_write()
                
    def saveIfStale(self):
        now = time.time()
        if now - self.saveTime_ > self.saveTimeout_:
            try:
                self.save()
            except:
                logger.exception("non-fatal error: Could not save cahced data to %s" % self.path_)
                return
            self.saveTime_ = now

    def invalidate(self):
        self.lock_.acquire()
        try:
            return self.instance_.invalidate()
        finally:
            self.lock_.release()

