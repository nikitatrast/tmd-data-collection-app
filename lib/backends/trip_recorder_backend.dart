import 'dart:async';

import 'package:accelerometertest/backends/gps_auth.dart';

import '../boundaries/data_provider.dart';
import 'sensor_data_provider.dart';
import '../models.dart' show Location, Modes, Trip, Sensor;
import '../widgets/trip_recorder_widget.dart' show TripRecorderBackend;

class TripRecorderBackendImpl implements TripRecorderBackend {
  Map<Sensor, SensorDataProvider> _providers;
  Map<Sensor, StreamSubscription> _subscriptions = {};
  DataProvider _storage;
  GPSAuth gpsAuth;
  Trip _trip;

  TripRecorderBackendImpl(this._providers, this.gpsAuth, this._storage);

  @override
  void startRecording() {
    _trip = Trip();
    _trip.start = DateTime.now();
    for (var sensor in _providers.keys) {
      if (_subscriptions[sensor] != null) {
        print('[TripRecorder] startRecording called but $sensor already on!');
        continue; // already started successfully
      }
      _trip.sensorsData.putIfAbsent(sensor, () => []);
      var provider = _providers[sensor];
      print('[TripRecorder] startRecording for $sensor');
      var dataReceived = false;
      _subscriptions[sensor] = provider.stream.listen((data) {
        _trip.sensorsData[sensor].add(data);
        if (!dataReceived) {
          dataReceived = true;
          print('[TripRecorder] Received data from $sensor');
        }
      });
    }
  }

  @override
  void stopRecording() {
    _trip.end = DateTime.now();
    for (var sensor in _subscriptions.keys) {
      _subscriptions[sensor]?.cancel();
      _subscriptions[sensor] = null;
    }
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