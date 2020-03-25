import 'package:accelerometertest/boundaries/sensor_data_provider.dart';
import 'package:location/location.dart' as plugin;
import '../models.dart' show Location, Sensor;

class LocationProvider implements SensorDataProvider {
  bool _started;
  var _source = plugin.Location();

  Future<bool> start() async {
    if (_started == null) {
      _started = await _requestPermission();
    }
    return _started;
  }

  Stream<Location> get stream async* {
    while(_started == null) {
      await Future.delayed(Duration(microseconds: 1));
    }
    if (_started) {
      await for (var event in _source.onLocationChanged()) {
        yield Location(
            time: DateTime.fromMicrosecondsSinceEpoch(event.time.toInt()),
            latitude: event.latitude,
            longitude: event.longitude,
            altitude: event.altitude
        );
      }
    }
  }

  Sensor get sensor => Sensor.gps;

  // ---------------------------------------------------------------------------

  Future<bool> _requestPermission() async {
    var serviceEnabled = await _source.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _source.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    var permissionGranted = await _source.hasPermission();
    if (permissionGranted == plugin.PermissionStatus.DENIED) {
      permissionGranted = await _source.requestPermission();
      if (permissionGranted != plugin.PermissionStatus.GRANTED) {
        return false;
      }
    }
    _source.changeSettings(
      accuracy: plugin.LocationAccuracy.HIGH,
      interval: 50 /* ms */,
    );
    return true;
  }
}