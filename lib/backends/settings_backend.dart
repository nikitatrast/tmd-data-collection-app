import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/settings.dart';

class SharedPrefsSettingsBackend implements SettingsBackend {
  static const key3G = '3g_enabled';
  static const keyGPS = 'gps_enabled';

  static const defaultValues = {
    key3G: true,
    keyGPS: true
  };

  SharedPrefsSettingsBackend();

  @override Future<bool> get3GValue() async => get(key3G);
  @override Future<bool> getGPSValue() async => get(keyGPS);
  @override Future<bool> set3GValue(bool value) async => set(key3G, value);
  @override Future<bool> setGPSValue(bool value) async => set(keyGPS, value);

  Future<SharedPreferences> get store async {
    return SharedPreferences.getInstance();
  }

  Future<bool> get(String key) async {
    final s = await store;
    final v = s.getBool(key);
    return v ?? set(key, defaultValues[key]);
  }

  Future<bool> set(String key, bool value) async {
    var s = await store;
    await s.setBool(key, value);
    return s.getBool(key);
  }
}