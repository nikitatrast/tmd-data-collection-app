import 'dart:async';

import 'package:accelerometertest/backends/gps_auth.dart';
import 'package:accelerometertest/backends/sensor_data_provider.dart';
import 'package:accelerometertest/models.dart' show Serializable;
import 'package:location/location.dart' as plugin;

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

  LocationData.create(plugin.LocationData e) {
    millisecondsSinceEpoch = e.time.toInt();
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
  GPSAuth auth;
  StreamSubscription subscription;
  StreamController<LocationData> controller;
  bool firstStreaming = true;

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
    auth.addListener(authChanged);

    if (auth.value == true && subscription == null) {
      if (await hasPermission() && subscription == null) {
        subscription = plugin.Location().onLocationChanged().listen((event) {
          controller.add(LocationData.create(event));
        });
        print('[LocationProvider] Streaming started');
        return;
      }
    }
    print('[LocationProvider] Streaming enabled but not started');
  }

  void stopStreaming() {
    auth.removeListener(authChanged);
    var s = subscription;
    subscription = null;
    s?.cancel();
    print('[LocationProvider] Streaming stopped');
  }

  void resumeStreaming() async {
    if (await requestPermission() && subscription == null) {
      subscription = plugin.Location().onLocationChanged().listen((event) {
        controller.add(LocationData.create(event));
      });
      print('[LocationProvider] Streaming resumed');
    }
  }

  void pauseStreaming() {
    var s = subscription;
    subscription = null;
    s?.cancel();
    print('[LocationProvider] Streaming paused');
  }

  void authChanged() async {
    print('authChanged ${auth.value}');
    if (controller.hasListener) {
      if (auth.value == true) {
        resumeStreaming();
      } else {
        pauseStreaming();
      }
    }
  }

  // ---------------------------------------------------------------------------

  Future<bool> hasPermission() async {
    var _source = plugin.Location();
    return (await _source.serviceEnabled()) &&
        (await _source.hasPermission() == plugin.PermissionStatus.GRANTED);
  }

  Future<bool> requestPermission() async {
    var _source = plugin.Location();
    var serviceEnabled = await _source.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _source.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    var permissionGranted = await _source.hasPermission();
    if (permissionGranted == plugin.PermissionStatus.DENIED) {
      permissionGranted = await _source.requestPermission();
      if (permissionGranted != plugin.PermissionStatus.GRANTED) {
        return false;
      }
    }
    _source.changeSettings(
      accuracy: plugin.LocationAccuracy.HIGH,
      interval: 50 /* ms */,
    );
    return true;
  }
}