import 'dart:async';
import 'package:async/async.dart';

import '../backends/gps_auth.dart';

import '../boundaries/acceleration_provider.dart';
import '../boundaries/location_provider_background.dart';
import '../boundaries/data_store.dart';
import '../boundaries/sensor_data_provider.dart';

import '../models.dart' show LocationData, Mode, Sensor, Serializable, Trip;

import '../pages/trip_recorder_page.dart' show TripRecorderBackend;

/// Implementation of [TripRecorderBackend] using a
/// [LocationProviderBackground] by default.
///
/// The [LocationProviderBackground] keeps this backend
/// alive when the app is in background. Hence, the GPS must not be disabled
/// to ensure proper data collection.
///
class TripRecorderBackendImpl implements TripRecorderBackend {
  Map<Sensor, SensorDataProvider> _providers;

  /// Where to store the newly recorded trip.
  DataStore _storage;

  /// Whether we can use the GPS.
  GPSAuth gpsAuth;

  /// The newly recorded trip.
  Trip _trip;

  /// Completes when recordings must stop.
  Completer<DateTime> _tripEnd;

  TripRecorderBackendImpl(this.gpsAuth, this._storage, {
    Map<Sensor, SensorDataProvider> providers
  }) {
    _providers = providers ?? {
      Sensor.gps: LocationProviderBackground(gpsAuth),
      Sensor.accelerometer: AccelerationProvider(),
    };
  }

  /// Initializes member variables and starts sensor recordings.
  @override
  Future<bool> start(Mode tripMode) async {
    _trip = Trip();
    _trip.mode = tripMode;
    _trip.start = DateTime.now();
    _tripEnd = Completer();

    for (var sensor in _providers.keys) {
      print('[TripRecorder] startRecording for $sensor');
      var provider = _providers[sensor];
      // [provider.stream] never closes, wrapping it with [_recorderStream()]
      // creates a stream that closes when [_tripEnd] completes.
      var dataStream = _recorderStream<Serializable>(provider.stream, sensor.toString());
      _storage.recordData(_trip, sensor, dataStream);
    }
    return true;
  }

  void stop() {
    if (!_tripEnd.isCompleted) {
      _tripEnd.complete(DateTime.now());
      // Note:
      // [_recorderStream()] will close once [_tripEnd.isCompleted],
      // thus stopping the sensor data recordings.
    }
  }

  @override
  Future<bool> save() async {
    print('[TripRecorder] save()');
    stop();
    await _storage.save(_trip, await _tripEnd.future);
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
    // [save()] or [cancel()] should be called before [dispose()]
    // and therefore, [_tripEnd] should be completed.
    // To make sure the [_recorderStream()] closes properly,
    // double check that [_tripEnd] is completed here.
    if (!_tripEnd.isCompleted) {
      stop();
      print('[TripRecorder] dispose(): not exited properly.');
    }
  }

  @override
  Stream<LocationData> locationStream() {
    return _providers[Sensor.gps].stream;
  }

  /// Wraps [input] into a [Stream] that closes as soon as
  /// [_tripEnd] is completed.
  Stream<T> _recorderStream<T>(Stream<T> input, String tag) {
    // Provider won't close stream
    // So, this function wraps the Provider's streams and closes when
    // recording is done.
    Stream<T> done = _tripEnd.future.asStream().map((e) => null);
    return StreamGroup.merge<T>([done, input]).takeWhile((e) => e != null);
  }
}