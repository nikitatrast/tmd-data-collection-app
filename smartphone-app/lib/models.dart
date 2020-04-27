/// Travel mode for a trip.
enum Mode {
  /// Test-mode to notify the server that this trip should be ignored.
  test,
  walk,
  run,
  bike,
  motorcycle,
  car,
  bus,
  metro,
  train
}

/// Modes that the user can use to record a new trip.
const List<Mode> enabledModes = Mode.values;


extension ModeValue on Mode {

  /// Slug for this [Mode].
  String get value => this.toString().split('.').last;

  /// Parses a slug into the corresponding [Mode].
  static Mode fromValue(String value) {
    for (var m in Mode.values) {
      if (m.value == value)
        return m;
    }
    return null;
  }
}

/// Data object to identify a trip.
class Trip {
  DateTime start;
  Mode mode;

  String toString() => 'Trip($mode à ${start.toIso8601String()})';

  @override
  bool operator==(dynamic that) {
    return (that is Trip) && (start == that.start) && (mode == that.mode);
  }

  @override
  int get hashCode {
    return start.millisecondsSinceEpoch.hashCode ^ mode.hashCode;
  }
}

abstract class Serializable {
  String serialize();
}

/// Sensors from which data can be collected.
enum Sensor { accelerometer, gps }

extension SensorValue on Sensor {
  /// Slug for this [Sensor].
  String get value => this.toString().split('.').last;

  /// Parses a slug into the corresponding [Sensor].
  static Sensor fromValue(String value) {
    for (var m in Sensor.values) {
      if (m.value == value)
        return m;
    }
    return null;
  }
}

/// Data object to hold an event received from the GPS sensor.
class LocationData extends Serializable {
  final int millisecondsSinceEpoch;
  final double latitude; // Latitude, in degrees
  final double longitude; // Longitude, in degrees
  final double altitude; // In meters above the WGS 84 reference ellipsoid
  final double _accuracy; // Estimated horizontal accuracy of this location, radial, in meters
  final double _speed; // In meters/second
  final double _speedAccuracy; // In meters/second, always 0 on iOS
  final double _heading; //Heading is the horizontal direction of travel of this device, in degrees

  LocationData({
    this.millisecondsSinceEpoch,
    this.latitude,
    this.longitude,
    this.altitude,
    accuracy,
    speed,
    speedAccuracy,
    heading
  })
      : _accuracy = accuracy
      , _speed = speed
      , _speedAccuracy = speedAccuracy
      , _heading = heading
  ;

  /// Parses a Serialized instance.
  static LocationData parse(String str) {
    final parts = str.split(',');
    return LocationData(
      millisecondsSinceEpoch: int.parse(parts[0]),
      latitude: double.parse(parts[1]),
      longitude: double.parse(parts[2]),
      altitude: double.parse(parts[3]),
      accuracy: double.parse(parts[4]),
      speed: double.parse(parts[5]),
      speedAccuracy: double.parse(parts[6]),
      heading: double.parse(parts[7]),
    );
  }

  /// Serializes this instance.
  String serialize() {
    return '$millisecondsSinceEpoch,'
        '$latitude,$longitude,$altitude,$_accuracy,'
        '$_speed,$_speedAccuracy,$_heading,\n';
  }
}

/// Data object to represent a geo fence.
class GeoFence implements Serializable {
  double latitude;
  double longitude;
  double radiusInMeters;
  String description;

  GeoFence(this.latitude, this.longitude, this.radiusInMeters, String description)
  : description = description.trim().replaceAll(';', ',');

  /// Serializes this instance.
  String serialize() {
    return '$latitude; $longitude; $radiusInMeters; $description';
  }

  /// Parses a serialized instance.
  GeoFence.parse(String str) {
    var parts = str.split(';');
    assert(parts.length == 4);
    latitude = double.parse(parts[0]);
    longitude = double.parse(parts[1]);
    radiusInMeters = double.parse(parts[2]);
    description = parts[3].trim();
  }
}