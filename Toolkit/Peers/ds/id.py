import random
import string
import types

counter = None

def reset():
    global counter
    counter = 0
    
def randomIdOfLength(length):
    return "".join([random.choice(string.letters) for elem in range(length)])

# This is probably not thread-safe, but we only use it for testing.
def newId(name="id"):
    global counter
    assert counter != None and "You must call reset() before newId() [from a fixture anyone?]"
    counter += 1
    return "%s%d" % (name, counter)

def isId(id):
    return type(id) == types.StringType
