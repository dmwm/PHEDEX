from ds import dsreload

class Base:
    def __init__(self):
        dsreload.addReloadableObject(object=self)
