import '../models.dart' show Sensor;

abstract class SensorDataProvider<T> {
  Future<bool> start();
  Stream<T> get stream;
  Sensor get sensor;
}