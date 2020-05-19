from dataclasses import dataclass, field
from typing import Dict
from datetime import datetime
import logging
from . import utils
from . import trip_data as td

def logger():
    return logging.getLogger('dataviz')


@dataclass
class Trip:
    start: datetime
    end: datetime
    mode: str
    data: Dict[str, td.TripData] = field(default_factory=dict)
        
    @property
    def duration(self):
        return self.end - self.start
    
    def __repr__(self):
        try:
            date_str = self.start.strftime('%m/%d/%y at %H:%M:%S')
        except Exception as e:
            logger().error(f'{e}')
            date_str = '???'
        try:
            format = "%{H}h%{M}mn%{S}s" if self.duration.seconds > 3600 else "%{M}mn%{S}s"
            duration_str = utils.strfdelta(self.duration, format)
        except Exception as e:
            logger().error(f'{e}')
            duration_str = '???'
        return f"Trip({date_str}, {self.mode}, {duration_str}, {len(self.data)} files)"
    
    def __lt__(self, other):
        return (self.start, self.mode, self.end) < (other.start, other.mode, other.end)