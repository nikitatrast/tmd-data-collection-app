import 'dart:async';

import 'package:geolocator/geolocator.dart' as plugin;
import 'package:location/location.dart' as plugin2;

import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show LocationData;

/// Provides data ([LocationData]) from the GPS sensor.
class LocationProvider implements SensorDataProvider<LocationData> {
  /// Subscription to the stream of location provided by the plugin.
  StreamSubscription subscriptionToPlugin;

  /// Controller used to output [LocationData].
  StreamController<LocationData> controller;

  LocationProvider() {
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
    if (subscriptionToPlugin == null) {
      subscriptionToPlugin = _subscribeToPluginStream(controller);
      print('[LocationProvider] Streaming started');
    } else {
      print('[LocationProvider] Streaming already started');
    }
  }

  void stopStreaming() {
    var s = subscriptionToPlugin;
    subscriptionToPlugin = null;
    s?.cancel();
    print('[LocationProvider] Streaming stopped');
  }

  void resumeStreaming() async {
    if (subscriptionToPlugin == null) {
      subscriptionToPlugin = _subscribeToPluginStream(controller);
      print('[LocationProvider] Streaming resumed');
    }
  }

  void pauseStreaming() {
    var s = subscriptionToPlugin;
    subscriptionToPlugin = null;
    s?.cancel();
    print('[LocationProvider] Streaming paused');
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
    var location = new plugin2.Location();

    var _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return false;
      }
    }

    var _permissionGranted = await location.hasPermission();
    if (_permissionGranted == plugin2.PermissionStatus.DENIED) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != plugin2.PermissionStatus.GRANTED) {
        return false;
      }
    }

    var geolocator = plugin.Geolocator();
    var status = await geolocator.checkGeolocationPermissionStatus();
    switch (status) {
      case plugin.GeolocationStatus.denied:
      case plugin.GeolocationStatus.disabled:
        return false;
      case plugin.GeolocationStatus.unknown:
      case plugin.GeolocationStatus.granted:
      case plugin.GeolocationStatus.restricted:
        return true;
    }
    return true;
  }
}