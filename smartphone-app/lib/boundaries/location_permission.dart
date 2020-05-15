import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as G;
import 'package:location/location.dart' as L;
import 'package:location_permissions/location_permissions.dart' as P;

enum LocationSystemStatus {
  disabled, denied, allowed
}

class LocationPermission {
  var loc = L.Location();
  var geo = G.Geolocator();
  var per = P.LocationPermissions();
  var status = ValueNotifier<LocationSystemStatus>(LocationSystemStatus.denied);

  Future<LocationSystemStatus> updateStatus() async {
    var res;
    P.ServiceStatus s = await per.checkServiceStatus();
    if (s != P.ServiceStatus.enabled) {
      res = LocationSystemStatus.disabled;
    } else {
      P.PermissionStatus s = await per.checkPermissionStatus();
      switch (s) {
        case P.PermissionStatus.denied:
          res = LocationSystemStatus.denied;
          break;
        case P.PermissionStatus.granted:
          res = LocationSystemStatus.allowed;
          break;
      }
    }

    status.value = res;
    return res;
  }

  Future<LocationSystemStatus> request() async {
    var e = await loc.requestService();
    var p = await loc.requestPermission();
    print('[LocationPermission] request() --> $e / $p');
    return updateStatus();
  }

  Future<bool> openSettings() {
    return per.openAppSettings();
  }
}