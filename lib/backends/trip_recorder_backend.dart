import 'dart:async';

import '../boundaries/data_provider.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show Location, Modes, GPSLocationAllowed, Trip, Sensor;
import '../widgets/trip_recorder_widget.dart' show TripRecorderBackend;

class TripRecorderBackendImpl implements TripRecorderBackend {
  GPSLocationAllowed _gpsAllowed;
  Map<Sensor, SensorDataProvider> _providers;
  Map<Sensor,StreamSubscription> _subscriptions = {};
  DataProvider _storage;
  Trip _trip = Trip();

  TripRecorderBackendImpl(this._gpsAllowed, this._providers,  this._storage);

  @override
  void startRecording() {
    _trip.start = DateTime.now();
    for (var sensor in _providers.keys) {
      var allowed = sensor == Sensor.gps ? locationAvailable() : Future.value(true);
      allowed.then((allowed) async {
        if (allowed) {
          var provider = _providers[sensor];
          _trip.sensorsData[sensor] = [];
          var started = await provider.start();
          if (started) {
            _subscriptions[sensor] = provider.stream.listen((data) {
              _trip.sensorsData[sensor].add(data);
            });
          } else {
            print('Could not start data provider for $sensor');
          }
        }
      });
    }
  }

  @override
  void stopRecording() {
    _trip.end = DateTime.now();
    for (var subscription in _subscriptions.values) {
      subscription?.cancel();
    }
  }

  @override
  Future<bool> locationAvailable() async {
    while(_gpsAllowed.value == null) {
      await Future.delayed(Duration(microseconds: 1));
    }
    return _gpsAllowed.value && (await _providers[Sensor.gps].start());
  }

  @override
  Stream<Location> locationStream() {
    return _providers[Sensor.gps].stream;
  }

  @override
  Future<bool> persistData(Modes travelMode) async {
    _trip.mode = travelMode;
    await _storage.persist(_trip);
    return true;
  }
}