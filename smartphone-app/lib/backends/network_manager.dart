import 'package:flutter/cupertino.dart';

import '../boundaries/connectivity.dart';
import '../boundaries/preferences_provider.dart' show CellularNetworkAllowed;

/// Indicates whether network use is allowed.
enum NetworkStatus { online, offline }

/// Decides whether we can use the network, based on user's preferences.
class NetworkManager {
  /// Whether network use is allowed.
  ValueNotifier<NetworkStatus> status = ValueNotifier(NetworkStatus.offline);

  /// Current connectivity status of the smartphone.
  ValueNotifier<ConnectivityStatus> _connectivity = ConnectivityNotifier();

  /// User preferences regarding network usage.
  CellularNetworkAllowed _auth;

  NetworkManager(this._auth) {
    _auth.addListener(this._updateSyncStatus);
    _connectivity.addListener(this._updateSyncStatus);
  }

  void dispose() {
    _connectivity.dispose();
    status.dispose();
  }

  bool get _mobileAllowed => _auth.value;

  bool get _mobileAvailable => _connectivity.value == ConnectivityStatus.mobile;

  bool get _wifiAvailable => _connectivity.value == ConnectivityStatus.wifi;

  bool get _networkAvailable => _wifiAvailable || (_mobileAllowed && _mobileAvailable);

  void _updateSyncStatus() {
    if (_networkAvailable) {
      status.value = NetworkStatus.online;
    } else {
      status.value = NetworkStatus.offline;
    }
  }
}