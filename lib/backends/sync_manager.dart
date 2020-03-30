import 'package:flutter/cupertino.dart';

import '../boundaries/connectivity.dart';
import '../boundaries/preferences_provider.dart' show CellularNetworkAllowed;

enum SyncStatus { uploading, done, awaitingNetwork, serverDown }

class SyncManager {
  ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(null);
  ValueNotifier<ConnectivityStatus> connectivity = ConnectivityNotifier();
  CellularNetworkAllowed auth;

  SyncManager(this.auth) {
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
      status.value = SyncStatus.done;
    } else {
      status.value = SyncStatus.awaitingNetwork;
    }
  }
}