import copy
import random

def randomSubsetOfLength(list, length):
    new = copy.copy(list)
    new.sort()
    random.shuffle(new)
    return new[0:length]
