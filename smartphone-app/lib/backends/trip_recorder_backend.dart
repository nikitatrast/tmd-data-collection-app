import 'dart:async';
import 'package:async/async.dart';

import 'package:accelerometertest/backends/gps_auth.dart';

import '../boundaries/data_store.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show Mode, Sensor, Trip;
import '../pages/trip_recorder_page.dart' show TripRecorderBackend;
import '../boundaries/location_provider.dart' show LocationData;

class TripRecorderBackendImpl implements TripRecorderBackend {
  Map<Sensor, SensorDataProvider> _providers;
  DataStore _storage;
  GPSAuth gpsAuth;
  Trip _trip;
  Completer<DateTime> _tripEnd;

  TripRecorderBackendImpl(this._providers, this.gpsAuth, this._storage);

  @override
  Future<bool> start(Mode tripMode) async {
    _trip = Trip();
    _trip.mode = tripMode;
    _trip.start = DateTime.now();
    _tripEnd = Completer();

    for (var sensor in _providers.keys) {
      var provider = _providers[sensor];
      print('[TripRecorder] startRecording for $sensor');
      _storage.recordData(_trip, sensor, recorderStream(provider.stream, sensor.toString()));
    }
    return Future.value(true);
  }

  void stop() {
    if (!_tripEnd.isCompleted) {
      _tripEnd.complete(DateTime.now());
    }
  }

  @override
  Future<bool> save() async {
    print('[TripRecorder] save()');
    stop();
    var tripEnd = await _tripEnd.future;
    await _storage.save(_trip, tripEnd);
    return true;
  }

  @override
  Future<void> cancel() async {
    print('[TripRecorder] cancel()');
    stop();
    await _storage.delete(_trip);
  }

  @override
  void dispose() {
    if (!_tripEnd.isCompleted) {
      stop();
      print('[TripRecorder] dispose(): not exited properly.');
    }
  }

  @override
  Stream<LocationData> locationStream() {
    return _providers[Sensor.gps].stream;
  }

  Stream<T> recorderStream<T>(Stream<T> input, String tag) {
    // Provider won't close stream
    // So, this function wraps the Provider's streams and closes when
    // recording is done.
    Stream<T> done = _tripEnd.future.asStream().map((e) => null);
    return StreamGroup.merge<T>([done, input]).takeWhile((e) => e != null);
  }

}