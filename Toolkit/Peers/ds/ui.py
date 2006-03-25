from ds import dsbase

import inspect

def availableUiMethods(object):
    members = inspect.getmembers(object)
    return dict([(memberName, member) for (memberName, member) in members if inspect.ismethod(member)])

class GenericUi(dsbase.Base):
    def availableMethods(self):
        myMethods = availableUiMethods(object=self)
        self.addChildMethodsToDict(methods=myMethods)
        return myMethods
    def addChildMethodsToDict(self, methods):
        nameToMethodList = {}
        for child in self.children():
            childMethods = child.availableMethods()
            for name, method in childMethods.items():
                if not methods.has_key(name):
                    if not nameToMethodList.has_key(name): nameToMethodList[name] = []
                    nameToMethodList[name].append(method)
        for name, list in nameToMethodList.items():
            def lf(list=list):
                for m in list:
                    m()
            methods[name] = lf

    def label(self):
        return str(self)
    def children(self):
        return []
    def canHaveChildren(self):
        return 1

