enum Mode { walk, bike, motorcycle, car, bus, metro, train }
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
  //DateTime end;
  Mode mode;

  String toString() => 'Trip($mode à ${start.toIso8601String()})';
}

abstract class Serializable {
  String serialize();
}

enum Sensor { accelerometer, gps }