from collections import deque
from pytz import timezone
from datetime import datetime
from itertools import islice
import pandas as pd


class TSBuffer(object):
    def __init__(self, maxlen=None, tz='UTC'):
        self.deque = deque(maxlen=maxlen)
        self.tz = tz

    def __len__(self):
        return len(self.deque)

    def append(self, value, d_time=None):
        d_time = d_time if d_time else timezone(self.tz).localize(datetime.utcnow())
        data = (d_time, value)
        self.deque.append(data)

    def maxlen(self, new_length):
        if new_length > self.deque.maxlen:
            self.deque = deque(self.deque, maxlen=new_length)

    def extend(self, values):
        self.deque.extend(values)

    def get(self, horizon=None, times=True):
        try:
            contents = self.deque
            if horizon and horizon < len(contents):
                contents = list(islice(contents, len(contents) - horizon, None))
            if times:
                contents = zip(*contents)
            else:
                contents = zip(*contents)[1]
        except Exception as e:
            print("In Buffer.get(), exception is: {}".format(str(e)))
            return [(), ()]
        else:
            return contents

    def get_series(self, horizon=0):
        horizon = horizon if horizon < len(self.deque) else 0
        contents = self.deque if not horizon else list(islice(self.deque, len(self.deque) - horizon, None))
        contents = zip(*contents) if contents else [[],[]]
        return pd.Series(contents[1], contents[0])
