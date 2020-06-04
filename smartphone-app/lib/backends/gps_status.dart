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
  Future<void> forceUpdate({bool requestAuth});
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
    _userPref.addListener(() => _update(null, requestAuth: false));
    forceUpdate();
  }

  Future<void> forceUpdate({bool requestAuth}) {
    return _update(null, requestAuth: requestAuth);
  }

  Future<void> _update(LocationSystemStatus systemValue, {bool requestAuth}) async {
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
        var sysValue = (requestAuth==true) ? await _systemPref.request(): await _systemPref.updateStatus();
        print('$logPrefix._update => sysValue = $sysValue, userPref = ${_userPref.value}');
        if (sysValue != null)
          await _update(sysValue, requestAuth: false);
      } else {
        super.value = GpsStatus.userDisabled;
      }
    }
  }
}