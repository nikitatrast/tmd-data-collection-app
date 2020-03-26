import 'dart:async';

import 'package:accelerometertest/backends/gps_auth.dart';
import 'package:accelerometertest/backends/sensor_data_provider.dart';
import 'package:location/location.dart' as plugin;
import '../models.dart' show Location;

class LocationProvider implements SensorDataProvider {
  GPSAuth auth;
  StreamSubscription subscription;
  StreamController<Location> controller;
  bool firstStreaming = true;

  LocationProvider(this.auth) {
    controller = StreamController<Location>.broadcast(
      onListen: startStreaming,
      onCancel: stopStreaming,
    );
  }

  @override
  Stream<Location> get stream {
    return controller.stream;
  }

  void startStreaming() async {
    auth.addListener(authChanged);

    if (auth.value == true && subscription == null) {
      if (await hasPermission() && subscription == null) {
        subscription = plugin.Location().onLocationChanged().listen((event) {
          controller.add(_fromEvent(event));
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
        controller.add(_fromEvent(event));
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

  Location _fromEvent(plugin.LocationData event) {
    return Location(
        time: DateTime.fromMicrosecondsSinceEpoch(event.time.toInt()),
        latitude: event.latitude,
        longitude: event.longitude,
        altitude: event.altitude);
  }
}
