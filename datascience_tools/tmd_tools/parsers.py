from dataclasses import dataclass, field

@dataclass
class GyroscopeData:
    millisecondsSinceEpoch:int
    x:float
    y:float
    z:float
        
    @staticmethod
    def parse(serialized):
        parts = serialized.split(',')
        if len(parts) != 5:
            logging.error(f'GyroscopeData.parse: unable to parse "{serialized}"')
            return None
        return GyroscopeData(parts[0], parts[1], parts[2], parts[3])
    
    def __lt__(self, other):
        return self.millisecondsSinceEpoch < other.millisecondsSinceEpoch

@dataclass
class AccelerometerData:
    millisecondsSinceEpoch:int
    x:float
    y:float
    z:float
        
    @staticmethod
    def parse(serialized):
        parts = serialized.split(',')
        if len(parts) != 5:
            logging.error(f'AccelerometerData.parse: unable to parse "{serialized}"')
            return None
        return AccelerometerData(parts[0], parts[1], parts[2], parts[3])
    
    def __lt__(self, other):
        return self.millisecondsSinceEpoch < other.millisecondsSinceEpoch

@dataclass
class GpsData:
    millisecondsSinceEpoch:int
    latitude:float      # Latitude, in degrees
    longitude:float     # Longitude, in degrees
    altitude:float      # In meters above the WGS 84 reference ellipsoid
    accuracy:float      # Estimated horizontal accuracy of this location, radial, in meters
    speed:float         # In meters/second
    speedAccuracy:float # In meters/second, always 0 on iOS
    heading:float       # Heading is the horizontal direction of travel of this device, in degrees
      
    @staticmethod
    def parse(serialized):
        parts = serialized.split(',');
        if len(parts) != 9:
            raise ValueError(f'GpsData unable to parse from "{serialized}"')
        class A: pass
        self = A()
        self.millisecondsSinceEpoch = int(parts[0])
        self.latitude = float(parts[1])
        self.longitude = float(parts[2])
        self.altitude = float(parts[3])
        self.accuracy = float(parts[4])
        self.speed = float(parts[5])
        self.speedAccuracy = float(parts[6])
        self.heading = float(parts[7])
        return GpsData(
            millisecondsSinceEpoch = int(parts[0]),
            latitude = float(parts[1]),
            longitude = float(parts[2]),
            altitude = float(parts[3]),
            accuracy = float(parts[4]),
            speed = float(parts[5]),
            speedAccuracy = float(parts[6]),
            heading = float(parts[7])
        )

    def __lt__(self, other):
        return self.millisecondsSinceEpoch < other.millisecondsSinceEpoch