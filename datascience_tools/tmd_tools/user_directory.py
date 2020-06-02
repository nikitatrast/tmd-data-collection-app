from pathlib import Path
import datetime
import logging
from . import trip_data as td
from . import trip as T

def logger():
    return logging.getLogger('dataviz')

class UserDirectory:
    def __init__(self, parent_path, uid, data):
        self.uid = uid
        self.data = data
        self.path = Path(parent_path)/uid
        self.user_name = data['app_name']
        
    @property
    def exists(self):
        return self.path.is_dir()
    
    @property
    def trips(self):
        try:
            paths = list(self.path.iterdir())
            trips_data = [td.TripData.parse(path) for path in paths]
            trips_data = [t for t in trips_data if t is not None]
            key = lambda t: (t.start, t.end, t.mode)
            trips = {key(t): T.Trip(t.start, t.end, t.mode) for t in trips_data}
            for t in trips_data:
                trips[key(t)].data[t.sensor] = t
            return list(trips.values())
            
        finally:
            pass
    
    @property
    def sorted_trips(self):
        return list(sorted(self.trips))
    
    @property
    def data_trips(self):
        test_modes = set(('exploration', 'test'))
        return [t for t in self.trips if t.mode not in test_modes and t.data]

    @property
    def durations(self):
        d = {}
        for t in self.trips:
            d.setdefault(t.mode, datetime.timedelta(0))
            if t.duration.seconds < 0:
                logger().error('Found negative duration for `{self}`, trip `{t}` has duration `{t.duration}`')
            d[t.mode] += t.duration
        return d

    def __repr__(self):
        return f'UserDirectory({self.uid[:4]}:{self.data["app_name"]})'