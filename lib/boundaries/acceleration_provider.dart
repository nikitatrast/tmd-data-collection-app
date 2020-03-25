import 'dart:async';
import 'package:accelerometertest/boundaries/sensor_data_provider.dart';
import 'package:sensors/sensors.dart' as plugin;
import '../models.dart' show Acceleration, Sensor;

class AccelerationProvider implements SensorDataProvider {
  Future<bool> start() => Future.value(true);

  Stream<Acceleration> get stream {
    return plugin.accelerometerEvents.map((event) => Acceleration(
      time: DateTime.now(),
      x: event.x,
      y: event.y,
      z: event.z,
    ));
  }

  Sensor get sensor => Sensor.accelerometer;
}
