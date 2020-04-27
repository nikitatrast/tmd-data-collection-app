import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether user allowed to use cellular network for synchronization with the
/// server.
class CellularNetworkAllowed extends ValueNotifier<bool> {
  CellularNetworkAllowed() : super(null);
}

/// Current user preference regarding GPS usage.
class GPSPrefNotifier extends ValueNotifier<GPSPref> {
  GPSPrefNotifier() : super(null);
}

/// User preference regarding GPS usage.
enum GPSPref {
  /// Always allow GPS usage.
  always,

  /// Only allow GPS usage when device is charging.
  whenCharging,

  /// Only allow GPS usage when device's battery level is above 20%.
  batteryLevel20,

  /// Only allow GPS usage when device's battery level is above 40%.
  batteryLevel40,

  /// Only allow GPS usage when device's battery level is above 60%.
  batteryLevel60,

  /// Only allow GPS usage when device's battery level is above 80%.
  batteryLevel80,

  /// Do not allow GPS usage.
  never
}

extension GPSPrefValue on GPSPref {
  /// A slug representing this [GPSPref].
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

/// Data store where this app's (local-UID) and UID can be persisted.
class UidStore {
  Future<String> getLocalUid() async {
    var s = await SharedPreferences.getInstance();
    return s.getString(_keyLocalUid);
  }

  /// Persists this app's local ID.
  ///
  /// When [localUid] is `null`, the previously persisted ID is removed.
  Future<void> setLocalUid(String localUid) async {
    print('[UidStore] setLocalUid($localUid)');

    var s = await SharedPreferences.getInstance();

    if (localUid == null)
      return s.remove(_keyLocalUid);

    if (localUid == '')
      localUid = 'not set';
    await s.setString(_keyLocalUid, localUid);
  }

  /// Gets this app's UID, may return `null`.
  Future<String> getUid() async {
    var s = await SharedPreferences.getInstance();
    return s.getString(_keyUid);
  }

  /// Persists [uid] as this app's UID.
  ///
  /// If [uid] is `null`, the previously persisted ID is removed.
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

/// Store where user's preferences can be persisted.
class PreferencesProvider {
  /// User's preferences regarding cellular network usage for synchronization.
  var cellularNetwork = CellularNetworkAllowed();

  /// User's preferences regarding GPS usage.
  var gpsAuthNotifier = GPSPrefNotifier();

  /// This app's (local-uid) and uid store.
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
