import bisect
import Queue

class PriorityQueue(Queue.Queue):
    # Constructor takes maxsize, with <= 0 meaning unbounded.

    def _put(self, item):
        bisect.insort(self.queue, item)
