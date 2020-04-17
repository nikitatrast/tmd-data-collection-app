import 'dart:async';

import 'package:accelerometertest/boundaries/sensor_data_provider.dart';
import 'package:accelerometertest/models.dart' show Serializable;
import 'package:geolocator/geolocator.dart' as plugin;
import 'package:location/location.dart' as plugin2;

class LocationData extends Serializable {
  int millisecondsSinceEpoch;
  double latitude; // Latitude, in degrees
  double longitude; // Longitude, in degrees
  double altitude; // In meters above the WGS 84 reference ellipsoid
  double _accuracy; // Estimated horizontal accuracy of this location, radial, in meters
  double _speed; // In meters/second
  double _speedAccuracy; // In meters/second, always 0 on iOS
  double _heading; //Heading is the horizontal direction of travel of this device, in degrees

  LocationData.parse(String str) {
    final parts = str.split(',');
    millisecondsSinceEpoch = int.parse(parts[0]);
    latitude = double.parse(parts[1]);
    longitude = double.parse(parts[2]);
    altitude = double.parse(parts[3]);
    _accuracy = double.parse(parts[4]);
    _speed = double.parse(parts[5]);
    _speedAccuracy = double.parse(parts[6]);
    _heading = double.parse(parts[7]);
  }

  String serialize() {
    return '$millisecondsSinceEpoch,'
        '$latitude,$longitude,$altitude,$_accuracy,'
        '$_speed,$_speedAccuracy,$_heading,\n';
  }

  LocationData.create(plugin.Position e) {
    millisecondsSinceEpoch = e.timestamp.millisecondsSinceEpoch;
    latitude = e.latitude;
    longitude = e.longitude;
    altitude = e.altitude;
    _accuracy = e.accuracy;
    _speed = e.speed;
    _speedAccuracy = e.speedAccuracy;
    _heading = e.heading;
  }
}

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
      controller.add(LocationData.create(event));
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