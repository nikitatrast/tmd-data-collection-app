import 'package:flutter/cupertino.dart';

import '../boundaries/connectivity.dart';
import '../boundaries/preferences_provider.dart' show CellularNetworkAllowed;

enum NetworkStatus { online, offline }

class NetworkManager {
  ValueNotifier<NetworkStatus> status = ValueNotifier(NetworkStatus.offline);
  ValueNotifier<ConnectivityStatus> connectivity = ConnectivityNotifier();
  CellularNetworkAllowed auth;

  NetworkManager(this.auth) {
    auth.addListener(this._updateSyncStatus);
    connectivity.addListener(this._updateSyncStatus);
  }

  void dispose() {
    connectivity.dispose();
    status.dispose();
  }

  bool get _mobileAllowed => auth.value;

  bool get _mobileAvailable => connectivity.value == ConnectivityStatus.mobile;

  bool get _wifiAvailable => connectivity.value == ConnectivityStatus.wifi;

  bool get _networkAvailable => _wifiAvailable || (_mobileAllowed && _mobileAvailable);

  void _updateSyncStatus() {
    if (_networkAvailable) {
      status.value = NetworkStatus.online;
    } else {
      status.value = NetworkStatus.offline;
    }
  }
}