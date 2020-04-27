import 'dart:async';
import 'sensor_data_provider.dart';
import 'package:sensors/sensors.dart' as plugin;
import '../models.dart' show Serializable;

/// Data object to hold an event received from the accelerometer sensor.
class AccelerometerData extends Serializable {
  int _millisecondsSinceEpoch;
  double _x, _y, _z;

  String serialize() {
    return '$_millisecondsSinceEpoch,$_x,$_y,$_z,\n';
  }

  AccelerometerData.parse(String str) {
    final parts = str.split(',');
    _millisecondsSinceEpoch = int.parse(parts[0]);
    _x = double.parse(parts[1]);
    _y = double.parse(parts[2]);
    _z = double.parse(parts[3]);
  }

  AccelerometerData.create(plugin.AccelerometerEvent event) {
    _millisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
    _x = event.x;
    _y = event.y;
    _z = event.z;
  }
}

/// Provides data ([AccelerometerData]) from the accelerometer sensor.
class AccelerationProvider implements SensorDataProvider<AccelerometerData> {
  Stream<AccelerometerData> get stream {
    return plugin.accelerometerEvents.map((e) => AccelerometerData.create(e));
  }
}
