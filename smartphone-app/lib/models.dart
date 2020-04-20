enum Mode { test, walk, run, bike, motorcycle, car, bus, metro, train }
const List<Mode> enabledModes = Mode.values;

extension ModeValue on Mode {
  String get value => this.toString().split('.').last;

  static Mode fromValue(String value) {
    for (var m in Mode.values) {
      if (m.value == value)
        return m;
    }
    return null;
  }
}

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

enum Sensor { accelerometer, gps }

extension SensorValue on Sensor {
  String get value => this.toString().split('.').last;

  static Sensor fromValue(String value) {
    for (var m in Sensor.values) {
      if (m.value == value)
        return m;
    }
    return null;
  }
}