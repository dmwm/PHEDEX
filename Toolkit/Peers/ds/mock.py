# this release is Copyright 2004 IMVU, Inc
# written by Eric Ries (eric@imvu.com)
# released under the Python License: http://www.python.org/2.3.2/license.html

import time

class MockObject:
    def __init__(self, *args, **kwargs):
        self.args_ = args
        self.kwargs_ = kwargs
        self.settings_ = {}
        self.newObjects_ = []
        self.responses_ = {}
        self.defaultNewObjectClass_ = MockObject
        
    def old__getattr__(self,name):
        if name.endswith("__"):
            raise AttributeError
        if name.endswith("_"):
            return None
        def lf(self=self, name=name, *args, **kwargs):
            return None
        return lf
        raise AttributeError

    def newObjectOfClass(self, klass, args=(), kwargs={}):
        mo = klass(*args, **kwargs)
        mo.name_ = self.name_
        self.newObjects_.append(mo)
        return mo

    def __call__(self, *args, **kwargs):
       if self.name_.startswith("new"):
           return self.newObjectOfClass(self.defaultNewObjectClass_, args, kwargs)
       if self.name_.startswith("set"):
           self.settings_[self.name_] = (args, kwargs)
       return None

    def respond(self, funcName, funcValue):
       self.responses_[funcName] = funcValue
       
    def __getattr__(self,name):
        if name.endswith("__"):
            raise AttributeError
        if name.endswith("_"):
            return None
        try:
           response = self.responses_[name]
           def lf(self=self, response=response, *args, **kwargs):
              return response
           return lf
        except KeyError:
           pass
        mo = MockObject()
        mo.name_ = name
        mo.settings_ = self.settings_
        mo.newObjects_ = self.newObjects_
        mo.defaultNewObjectClass_ = self.defaultNewObjectClass_
        return mo

class MockFile(MockObject):
    def __init__(self, name, flags):
        MockObject.__init__(self)
        self.name_ = name
        self.flags_ = flags
        self.doneReading_ = False
        self.dataLeftReading_ = None
        
    def read(self, amt=None):
        assert "r" in self.flags_, "could not read MockFile %s with flags '%s'" % (self.name_, self.flags_)
        if self.doneReading_:
            return None
        if self.data_:
            if amt is not None:
                if self.dataLeftReading_ is None:
                    self.dataLeftReading_ = self.data_
                if len(self.dataLeftReading_) <= amt:
                    ret = self.dataLeftReading_
                    self.dataLeftReading_ = None
                    self.doneReading_ = True
                    return ret
                else:
                    ret = self.dataLeftReading_[0:amt]
                    self.dataLeftReading_ = self.dataLeftReading_[amt:]
                    assert ret is not None
                    return ret
            else:
                self.doneReading_ = True
                return self.data_
        else:
            raise IOError("[Errno 2] No such file or directory: '%s'" % self.name_)
    def write(self, data):
        assert "w" in self.flags_
        self.data_ = data
    def close(self):
        self.flags_ = ""
        self.doneReading_ = False

AllFiles = []
def MockOpenFunc(fname, flags):
    for f in AllFiles:
        if f.name_ == fname:
            assert not f.flags_
            f.flags_ = flags
            return f
    if not ('w' in flags or 'a' in flags):
        raise IOError("[Errno 2] No such file or directory: '%s'" % fname)

    f = MockFile(name=fname, flags=flags)
    AllFiles.append(f)
    return f

def MockFileExists(fname):
    for f in AllFiles:
        if f.name_ == fname:
            return True
    return False

def MockGetsize(fname):
    for f in AllFiles:
        if f.name_ == fname:
            return len(f.data_)
    raise IOError("[Errno 2] No such file or directory: '%s'" % fname)

def MockMakedirs(path):
    pass

def SetupMockFileFunctionsForModule(mod):
    mod.open = MockOpenFunc
    mod.file = MockOpenFunc
    mod.os.path.exists = MockFileExists
    mod.os.path.getsize = MockGetsize
    mod.os.makedirs = MockMakedirs
    
timeAdded = 0
def MockTimeFunc(realTime=time.time, *args, **kwargs):
    return realTime(*args, **kwargs) + timeAdded
    
