import 'dart:async';

/// Use geolocator plugin because it's the only one that works in
/// a background Isolate... (as of 05.2020)
import 'package:geolocator/geolocator.dart' as plugin;
import 'package:tmd/backends/gps_status.dart';

import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show LocationData;

/// Provides data ([LocationData]) from the GPS sensor.
class LocationProvider implements SensorDataProvider<LocationData> {
  /// Whether GPS use is allowed.
  GpsStatusProvider statusProvider;

  /// Subscription to the GPS sensor's stream.
  StreamSubscription subscription;

  /// Controller for the output stream of LocationData.
  StreamController<LocationData> controller;

  LocationProvider(this.statusProvider) {
    controller = StreamController<LocationData>.broadcast(
      onListen: startStreaming,
      onCancel: stopStreaming,
    );
  }

  @override
  Stream<LocationData> get stream {
    return controller.stream;
  }

  void startStreaming() async {
    statusProvider.status.addListener(_authChanged);
    if (!await resumeStreaming())
      print('[LocationProvider] Streaming enabled but not started');
  }

  Future<bool> resumeStreaming() async {
    if (statusProvider.status.value == GpsStatus.available && subscription == null) {
      subscription = _subscribeToPluginStream(controller);
      print('[LocationProvider] Streaming started');
      return true;
    }
    return false;
  }

  void pauseStreaming() {
    var s = subscription;
    subscription = null;
    s?.cancel();
    print('[LocationProvider] Streaming paused');
  }

  void stopStreaming() {
    statusProvider.status.removeListener(_authChanged);
    pauseStreaming();
    print('[LocationProvider] Streaming stopped');
  }


  void _authChanged() async {
    print('authChanged ${statusProvider.status.value}');
    if (controller.hasListener) {
      if (statusProvider.status.value == GpsStatus.available) {
        resumeStreaming();
      } else {
        pauseStreaming();
      }
    }
  }

  static StreamSubscription _subscribeToPluginStream(controller) {
    var bestForNavigation = plugin.LocationAccuracy.bestForNavigation;
    var stream = plugin.Geolocator().getPositionStream(
        plugin.LocationOptions(accuracy: bestForNavigation),
        plugin.GeolocationPermission.locationAlways);
    var _subscription = stream.listen((event) {
      controller.add(LocationData(
        millisecondsSinceEpoch: event.timestamp.millisecondsSinceEpoch,
        latitude: event.latitude,
        longitude: event.longitude,
        altitude: event.altitude,
        accuracy: event.accuracy,
        speed: event.speed,
        speedAccuracy: event.speedAccuracy,
        heading: event.heading,
      ));
    });
    return _subscription;
  }
}