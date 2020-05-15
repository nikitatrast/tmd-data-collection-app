import 'dart:async';

/// Use geolocator plugin because it's the only one that works in
/// a background Isolate... (as of 05.2020)
import 'package:geolocator/geolocator.dart' as plugin;

/// Use location plugin because we can request to enable the GPS with it.
import 'package:location/location.dart' as Location;

import '../backends/gps_auth.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show LocationData;

/// Provides data ([LocationData]) from the GPS sensor.
class LocationProvider implements SensorDataProvider<LocationData> {
  /// Whether GPS use is allowed.
  GPSAuth auth;

  /// Subscription to the GPS sensor's stream.
  StreamSubscription subscription;

  /// Controller for the output stream of LocationData.
  StreamController<LocationData> controller;

  LocationProvider(this.auth) {
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
    auth.addListener(_authChanged);
    if (!await resumeStreaming())
      print('[LocationProvider] Streaming enabled but not started');
  }

  Future<bool> resumeStreaming() async {
    if (auth.value == true && subscription == null) {
      if (await requestPermission() && subscription == null) {
        subscription = _subscribeToPluginStream(controller);
        print('[LocationProvider] Streaming started');
        return true;
      }
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
    auth.removeListener(_authChanged);
    pauseStreaming();
    print('[LocationProvider] Streaming stopped');
  }


  void _authChanged() async {
    print('authChanged ${auth.value}');
    if (controller.hasListener) {
      if (auth.value == true) {
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

  // ---------------------------------------------------------------------------

  /// Requests permission to use GPS. Must be called in main Isolate.
  Future<bool> requestPermission() async {
    var l = Location.Location();

    bool enabled = await l.serviceEnabled();
    if (!enabled) {
      enabled = await l.requestService();
      if (!enabled) {
        return false;
      }
    }

    var permission = await l.hasPermission();
    if (permission == Location.PermissionStatus.denied) {
      permission = await l.requestPermission();
    }
    return permission == Location.PermissionStatus.granted;
  }
}