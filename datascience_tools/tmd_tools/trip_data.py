from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime
import logging
import pandas as pd
from . import utils


def logger():
    return logging.getLogger('dataviz')


@dataclass
class TripData:
    start: datetime
    end: datetime
    mode: str
    sensor: str
    filepath: Path

    @staticmethod
    def parse(filename):
        filename = str(filename)
        filepath = Path(filename)
        if not filepath.exists():
            logger().warning(f'Parsing filename, but correspondig file does not exist: {filename}')
        if '/' in filename:
            filename = filename.split('/')[-1]
        if '.' in filename:
            filename = filename.split('.')[0]
        parts = filename.split('_')
        if len(parts) != 4:
            logger().warning(f'TripData.parse: unable to parse filename: "{filename}"')
            return None
        mode = parts[0]
        start = pd.to_datetime(int(parts[1]), unit='ms').to_pydatetime()
        sensor = parts[2]
        end = pd.to_datetime(int(parts[3]), unit='ms').to_pydatetime()
        return TripData(start, end, mode, sensor, filepath)

    @property
    def duration(self):
        return self.end - self.start
    
    @property 
    def df(self):
        names = {
            'gps': [
                'ms',
                'latitude', # Latitude, in degrees
                'longitude', # Longitude, in degrees
                'altitude', # In meters above the WGS 84 reference ellipsoid
                'accuracy', # Estimated horizontal accuracy of this location, radial, in meters
                'speed', # In meters/second
                'speedAccuracy', # In meters/second, always 0 on iOS
                'heading',
            ],
            'accelerometer': [
                'ms',
                'x',
                'y',
                'z',
            ],
            'gyroscope': [
                'ms',
                'x', 
                'y',
                'z',
            ],
        }
        col_names = names.get(self.sensor)
        usecols = range(len(col_names)) if col_names else None
        return pd.read_csv(self.filepath, names=col_names, usecols=usecols, index_col=0)

    def __lt__(self, other):
        return self.start < other.start or (self.start == other.start and self.sensor < other.sensor)
    
    def __repr__(self):
        date_str = self.start.strftime('%m/%d/%y at %H:%M:%S')
        duration = self.end - self.start
        format = "%{H}h%{M}mn%{S}s" if duration.seconds > 3600 else "%{M}mn%{S}s"
        duration_str = utils.strfdelta(duration, format)
        return f'TripData({self.mode} {self.sensor} {date_str} {duration_str})'
  