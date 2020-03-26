import 'package:accelerometertest/models.dart';
import 'package:flutter/cupertino.dart';
import '../models.dart' show GPSPrefNotifier, GPSPref;
import '../boundaries/location_provider.dart' show LocationProvider;
import '../boundaries/battery.dart';

class GPSAuth extends ValueNotifier<bool> {
  GPSPrefNotifier _pref;
  BatteryNotifier _battery;

  GPSAuth(this._pref, this._battery) : super(null) {
    _battery.addListener(_update);
    _pref.addListener(_update);
  }

  void _checkLevel(int level) async {
    var currentLevel = await BatteryNotifier.batteryLevel;
    super.value = (currentLevel > level);
  }

  void _update() {
    switch (_pref.value) {
      case GPSPref.always:
        super.value = true;
        break;
      case GPSPref.never:
        super.value = false;
        break;
      case GPSPref.whenCharging:
        super.value = _battery.value == BatteryState.charging;
        break;
      case GPSPref.batteryLevel20:
        _checkLevel(20);
        break;
      case GPSPref.batteryLevel40:
        _checkLevel(40);
        break;
      case GPSPref.batteryLevel60:
        _checkLevel(60);
        break;
      case GPSPref.batteryLevel80:
        _checkLevel(80);
        break;
    }
  }
}