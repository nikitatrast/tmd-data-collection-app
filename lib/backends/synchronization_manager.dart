import 'package:flutter/cupertino.dart';

import '../models/preferences.dart';
import '../models/synchronization_status.dart';

class SyncManager {
  ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(null);
  CellularNetworkAllowed cellularAuthNotifier;

  SyncManager(this.cellularAuthNotifier) {
    cellularAuthNotifier.addListener(this._cellularAuthChanged);
    update();
  }

  void update() async {
    await Future.delayed(Duration(seconds: 10));
    if (status.value == null) // change only if not already updated
      status.value = SyncStatus.done;
  }

  void _cellularAuthChanged() {
    if (cellularAuthNotifier.value) {
      status.value = SyncStatus.uploading;
    } else {
      status.value = SyncStatus.waiting;
    }
  }
}