import 'dart:async';
import 'package:async/async.dart';

import 'package:accelerometertest/backends/gps_auth.dart';

import '../boundaries/data_store.dart';
import 'sensor_data_provider.dart';
import '../models.dart' show Modes, Sensor, Trip;
import '../widgets/trip_recorder_widget.dart' show TripRecorderBackend;
import '../boundaries/location_provider.dart' show LocationData;

class TripRecorderBackendImpl implements TripRecorderBackend {
  Map<Sensor, SensorDataProvider> _providers;
  DataStore _storage;
  GPSAuth gpsAuth;
  Trip _trip;
  DataStoreEntry _entry;
  Completer __recording;

  TripRecorderBackendImpl(this._providers, this.gpsAuth, this._storage);

  @override
  Future<bool> start(Modes tripMode) async {
    _trip = Trip();
    _trip.mode = tripMode;
    _trip.start = DateTime.now();
    _entry = await _storage.getEntry(_trip);
    __recording = Completer();

    for (var sensor in _providers.keys) {
      var provider = _providers[sensor];
      print('[TripRecorder] startRecording for $sensor');
      _entry.record(sensor, recorderStream(provider.stream, sensor.toString()));
    }
    return Future.value(true);
  }

  void stop() {
    if (!__recording.isCompleted) {
      _trip.end = DateTime.now();
      __recording.complete(true);
    }
  }

  @override
  Future<bool> save() async {
    print('[TripRecorder] save()');
    stop();
    return await _entry.save(DateTime.now());
  }

  @override
  Future<void> cancel() async {
    print('[TripRecorder] cancel()');
    stop();
    await _entry.delete();
  }

  @override
  void dispose() {
    if (!__recording.isCompleted) {
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
    Stream<T> done = __recording.future.asStream().map((e) => null);
    return StreamGroup.merge<T>([done, input]).takeWhile((e) => e != null);
  }

}