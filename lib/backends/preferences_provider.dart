import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preferences.dart';

class PreferencesProvider {
  var cellularNetwork = CellularNetworkAllowed();
  var gpsLocation = GPSLocationAllowed();

  PreferencesProvider() {
    _setup(_key3G, cellularNetwork);
    _setup(_keyGPS, gpsLocation);
  }

  // ---------------------------------------------------------------------------

  static const _key3G = '3g_enabled';
  static const _keyGPS = 'gps_enabled';

  static const _defaultValues = {
    _key3G: true,
    _keyGPS: true
  };

  Future<void> _setup(String key, ValueNotifier notifier) async {
    var value = await _get(key);
    notifier.value = value;
    notifier.addListener(() => _set(key, notifier.value));
  }

  Future<bool> _get(String key) async {
    final s = await SharedPreferences.getInstance();
    final v = s.getBool(key);
    return v ?? _set(key, _defaultValues[key]);
  }

  Future<bool> _set(String key, bool value) async {
    var s = await SharedPreferences.getInstance();
    await s.setBool(key, value);
    return s.getBool(key);
  }
}