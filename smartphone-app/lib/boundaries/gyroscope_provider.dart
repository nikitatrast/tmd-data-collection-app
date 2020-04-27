import 'dart:async';
import 'sensor_data_provider.dart';
import 'package:sensors/sensors.dart' as plugin;
import '../models.dart' show Serializable;

/// Data object to hold an event received from the gyroscope sensor.
class GyroscopeData extends Serializable {
  int _millisecondsSinceEpoch;
  double _x, _y, _z;

  String serialize() {
    return '$_millisecondsSinceEpoch,$_x,$_y,$_z,\n';
  }

  GyroscopeData.parse(String str) {
    final parts = str.split(',');
    _millisecondsSinceEpoch = int.parse(parts[0]);
    _x = double.parse(parts[1]);
    _y = double.parse(parts[2]);
    _z = double.parse(parts[3]);
  }

  GyroscopeData.create(plugin.GyroscopeEvent event) {
    _millisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
    _x = event.x;
    _y = event.y;
    _z = event.z;
  }
}

/// Provides data ([GyroscopeData]) from the gyroscope sensor.
class GyroscopeProvider implements SensorDataProvider<GyroscopeData> {
  Stream<GyroscopeData> get stream {
    return plugin.gyroscopeEvents.map((e) => GyroscopeData.create(e));
  }
}
