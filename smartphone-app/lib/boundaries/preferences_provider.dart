import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CellularNetworkAllowed extends ValueNotifier<bool> {
  CellularNetworkAllowed() : super(null);
}

class GPSPrefNotifier extends ValueNotifier<GPSPref> {
  GPSPrefNotifier() : super(null);
}

enum GPSPref {
  always,
  whenCharging,
  batteryLevel20,
  batteryLevel40,
  batteryLevel60,
  batteryLevel80,
  never
}
extension GPSPrefValue on GPSPref {
  String get value => (const {
    GPSPref.always: 'always',
    GPSPref.batteryLevel20: 'batteryLevel20',
    GPSPref.batteryLevel40: 'batteryLevel40',
    GPSPref.batteryLevel60: 'batteryLevel60',
    GPSPref.batteryLevel80: 'batteryLevel80',
    GPSPref.whenCharging: 'whenCharging',
    GPSPref.never: 'never',
  })[this];
}

class UidStore {
  Future<String> getLocalUid() async {
    var s = await SharedPreferences.getInstance();
    return s.getString(_keyLocalUid);
  }

  Future<void> setLocalUid(String localUid) async {
    print('[UidStore] setLocalUid($localUid)');

    var s = await SharedPreferences.getInstance();

    if (localUid == null)
      return s.remove(_keyLocalUid);

    if (localUid == '')
      localUid = 'not set';
    await s.setString(_keyLocalUid, localUid);
  }

  Future<String> getUid() async {
    var s = await SharedPreferences.getInstance();
    return s.getString(_keyUid);
  }

  Future<void> setUid(String uid) async {
    var s = await SharedPreferences.getInstance();

    if (uid == null)
      return s.remove(_keyUid);

    if (uid == '')
      throw Exception('UID cannot be empty');

    await s.setString(_keyUid, uid);
  }

  static const _keyLocalUid = 'local_uid';
  static const _keyUid = 'uid';
}

class PreferencesProvider {
  var cellularNetwork = CellularNetworkAllowed();
  var gpsAuthNotifier = GPSPrefNotifier();
  var uidStore = UidStore();

  PreferencesProvider() {
    _setup(_key3G, cellularNetwork);
    _setupAuthNotifier();
  }


  // ---------------------------------------------------------------------------

  static const _key3G = '3g_enabled';
  static const _keyGPSAuth = 'gps_allowed';

  static const _defaultValues = {
    _key3G: true,
    _keyGPSAuth: GPSPref.always,
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

  Future<void> _setupAuthNotifier() async {
    var s = await SharedPreferences.getInstance();
    var str = s.getString(_keyGPSAuth);
    var strings = GPSPref.values.map((a) => a.value).toList();
    try {
      gpsAuthNotifier.value = GPSPref.values[strings.indexOf(str)];
    } on RangeError {
      gpsAuthNotifier.value = GPSPref.always;
      s.setString(_keyGPSAuth, GPSPref.always.value);
    }
    gpsAuthNotifier.addListener(() async {
        var authValue = gpsAuthNotifier.value;
        if (authValue != null) {
          var updated = await s.setString(_keyGPSAuth, gpsAuthNotifier.value.value);
          print('[PrefsProvider] Updated $_keyGPSAuth');
        }
  });
  }
}
