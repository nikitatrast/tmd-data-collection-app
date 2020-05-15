import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:location_permissions/location_permissions.dart';

enum LocationSystemStatus {
  disabled, denied, allowed
}

class LocationPermission {
  var loc = Location();
  var geo = Geolocator();
  var per = LocationPermissions();

  var c = StreamController<LocationSystemStatus>.broadcast();

  Stream<LocationSystemStatus> get status => c.stream;

  Future<LocationSystemStatus> updateStatus() async {
    GeolocationStatus s = await geo.checkGeolocationPermissionStatus();
    LocationSystemStatus res;
    switch(s) {
      case GeolocationStatus.restricted:
      case GeolocationStatus.granted:
        res = LocationSystemStatus.allowed;
        break;
      case GeolocationStatus.denied:
        res = LocationSystemStatus.denied;
        break;
      case GeolocationStatus.disabled:
        res = LocationSystemStatus.disabled;
        break;
      default:
        print('[LocationPermission] unknown response, disabling GPS');
        res = LocationSystemStatus.disabled;
    }
    c.add(res);
    return res;
  }

  Future<LocationSystemStatus> request() async {
    await loc.requestPermission();
    return updateStatus();
  }

  Future<bool> openSettings() {
    return per.openAppSettings();
  }
}