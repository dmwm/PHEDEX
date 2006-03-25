import bisect
import Queue

# Use methods like empty, put and get
class PriorityQueue(Queue.Queue):
    # Constructor takes maxsize, with <= 0 meaning unbounded.

    def _put(self, item):
        bisect.insort(self.queue, item)
