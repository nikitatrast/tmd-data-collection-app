import 'dart:async';

import 'package:flutter/material.dart';
import '../backends/gps_pref_result.dart';
import '../boundaries/location_permission.dart';

enum GpsStatus {
  systemDisabled, systemForbidden, userDisabled, available
}

extension GpsStatusValue on GpsStatus {
  String get value => this.toString().split('.')[1];
  static fromValue(String value) => GpsStatus.values.firstWhere((v) => v.value == value);
}

abstract class GpsStatusNotifier extends ChangeNotifier {
  Future<void> forceUpdate();
  GpsStatus get value;
  void dispose();
}


class GpsStatusNotifierImpl extends ValueNotifier<GpsStatus> implements GpsStatusNotifier {
  static String logPrefix = 'GpsStatusNotifier';

  GPSPrefResult _userPref;
  LocationPermission _systemPref;

  GpsStatusNotifierImpl(this._userPref, this._systemPref)
  : super(GpsStatus.systemDisabled)
  {
    _systemPref.status.addListener(() => _update(_systemPref.status.value));
    _userPref.addListener(() => _update(null));
    forceUpdate();
  }

  Future<void> forceUpdate() {
    return _update(null);
  }

  Future<void> _update(LocationSystemStatus systemValue) async {
    if (systemValue != null) {
      switch (_systemPref.status.value) {
        case LocationSystemStatus.disabled:
          super.value = GpsStatus.systemDisabled;
          break;
        case LocationSystemStatus.denied:
          super.value = GpsStatus.systemForbidden;
          break;
        case LocationSystemStatus.allowed:
          if (_userPref.value == true) {
            super.value = GpsStatus.available;
          } else {
            super.value = GpsStatus.userDisabled;
          }
          break;
      }
    }
    else {
      if (_userPref.value == true) {
        var sysValue = await _systemPref.request();
        print('$logPrefix._update => sysValue = $sysValue, userPref = ${_userPref.value}');
        await _update(sysValue);
      } else {
        super.value = GpsStatus.userDisabled;
      }
    }
  }
}