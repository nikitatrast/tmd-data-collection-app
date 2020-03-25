import 'package:flutter/cupertino.dart';

import '../boundaries/connectivity_provider.dart';
import '../models.dart' show SyncStatus, CellularNetworkAllowed, Connectivity;

class SyncManager {
  ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(null);
  ValueNotifier<Connectivity> connectivity = ConnectivityProvider().notifier;
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

  bool get _mobileAvailable => connectivity.value == Connectivity.mobile;

  bool get _wifiAvailable => connectivity.value == Connectivity.wifi;

  bool get _networkAvailable => _wifiAvailable || (_mobileAllowed && _mobileAvailable);

  void _updateSyncStatus() {
    if (_networkAvailable) {
      status.value = SyncStatus.done;
    } else {
      status.value = SyncStatus.awaitingNetwork;
    }
  }
}