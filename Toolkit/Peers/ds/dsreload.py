import gc
import inspect
import sys
import weakref

# TODO: memory leak
reloadableObjects = []

def addReloadableObject(object):
    global reloadableObjects
    reloadableObjects.append(weakref.ref(object))

def reloadAllObjects():
    global reloadableObjects
    for x in reloadableObjects:
        x2 = x()
        if x2:
            reloadObject(object=x2)
    reloadableObjects = [x for x in reloadableObjects if x()]

def reloadModule(mod, exclude):
    exclude[mod.__name__] = 1
    for n,v in inspect.getmembers(mod):
        if inspect.ismodule(v) and not exclude.has_key(mod.__name__):
            reloadModule(v, exclude)

    reload(mod)
    
def reloadObject(object):
    exclude = {}

    if not hasattr(object, "__module__"):
        return
    if not sys.modules.has_key(object.__module__):
        return
    mod = sys.modules[object.__module__]
    reloadModule(mod, exclude)
    if hasattr(object, "__class__"):
        cname = object.__class__.__name__
        if hasattr(mod, cname):
            newClass = getattr(mod, cname)
            object.__class__ = newClass
