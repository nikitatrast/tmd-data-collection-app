import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../boundaries/preferences_provider.dart' show GPSPrefNotifier, GPSPref;
import '../boundaries/battery.dart';

/// Whether GPS use is allowed, based on user's preferences.
class GPSAuth extends ValueNotifier<bool> {
  /// User preferences regarding GPS use.
  GPSPrefNotifier _pref;

  /// Notifier for when battery charging state changes.
  BatteryNotifier _battery;

  /// Timer to check the battery level periodically.
  Timer checkBatteryTimer;

  /// Battery level above which GPS usage is allowed.
  int batteryThreshold;

  GPSAuth(this._pref, this._battery) : super(null) {
    _battery.addListener(_update);
    _pref.addListener(_update);
  }

  /// Updates this value each time a preference changes.
  void _update() {
    switch (_pref.value) {
      case GPSPref.always:
        _cancelTimer();
        super.value = true;
        break;
      case GPSPref.never:
        _cancelTimer();
        super.value = false;
        break;
      case GPSPref.whenCharging:
        _cancelTimer();
        super.value = (_battery.value == BatteryState.charging);
        break;
      case GPSPref.batteryLevel20:
      case GPSPref.batteryLevel40:
      case GPSPref.batteryLevel60:
      case GPSPref.batteryLevel80:
        batteryThreshold = _parseBatteryLevel(_pref.value);
        _checkBatteryLevel();
        if (checkBatteryTimer == null) {
          checkBatteryTimer = Timer.periodic(
              Duration(minutes: 5),
              (timer) async => await _checkBatteryLevel(),
          );
        }
        break;
    }
  }

  /// Updates this value based on [batteryThreshold].
  Future<void> _checkBatteryLevel() async {
    print('[GpsAuth] checking battery level now.');
    var currentLevel = await BatteryNotifier.batteryLevel;
    super.value = (currentLevel > batteryThreshold);
  }

  void _cancelTimer() {
    checkBatteryTimer?.cancel();
    checkBatteryTimer = null;
  }

  int _parseBatteryLevel(GPSPref pref) {
    switch (pref) {
      case GPSPref.batteryLevel20: return 20;
      case GPSPref.batteryLevel40: return 40;
      case GPSPref.batteryLevel60: return 60;
      case GPSPref.batteryLevel80: return 80;
      default: throw Exception('Unknown option');
    }
  }
}