import 'dart:async';
import '../backends/sensor_data_provider.dart';
import 'package:sensors/sensors.dart' as plugin;
import '../models.dart' show Acceleration;

class AccelerationProvider implements SensorDataProvider {
  Stream<Acceleration> get stream {
    return plugin.accelerometerEvents.map((event) => Acceleration(
      time: DateTime.now(),
      x: event.x,
      y: event.y,
      z: event.z,
    ));
  }
}
