import 'dart:async';

import 'package:accelerometertest/boundaries/sensor_data_provider.dart';
import 'package:accelerometertest/models.dart' show LocationData;
import 'package:geolocator/geolocator.dart' as plugin;
import 'package:location/location.dart' as plugin2;

class LocationProvider implements SensorDataProvider<LocationData> {
  StreamSubscription subscription;
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
    if (subscription == null) {
      subscription = _subscribeToPluginStream(controller);
      print('[LocationProvider] Streaming started');
    } else {
      print('[LocationProvider] Streaming already started');
    }
  }

  void stopStreaming() {
    var s = subscription;
    subscription = null;
    s?.cancel();
    print('[LocationProvider] Streaming stopped');
  }

  void resumeStreaming() async {
    if (subscription == null) {
      subscription = _subscribeToPluginStream(controller);
      print('[LocationProvider] Streaming resumed');
    }
  }

  void pauseStreaming() {
    var s = subscription;
    subscription = null;
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