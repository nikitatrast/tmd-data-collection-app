import 'dart:async';
import 'package:accelerometertest/boundaries/uploader.dart';
import 'package:flutter/cupertino.dart';
import 'package:quiver/collection.dart';

import '../backends/network_manager.dart' show NetworkStatus;
import '../boundaries/data_store.dart';
import '../models.dart' show Sensor, SensorValue, Trip;

enum UploadStatus {
  local, pending, uploading, uploaded, unknown, error
}

enum SyncStatus {
  uploading, done, awaitingNetwork, serverDown
}

class UploadManager {
  DataStore _store;
  Future<Map<Trip, _SourceNotifier>> _notifiers;
  Map<Trip, _OutNotifier> _outNotifiers;
  PendingList _pendingUploads;
  Uploader _uploader;
  ValueNotifier<NetworkStatus> _networkStatus;
  ValueNotifier<SyncStatus> syncStatus = ValueNotifier<SyncStatus>(SyncStatus.done);

  UploadManager(this._store, this._networkStatus, this._uploader) {
    _pendingUploads = PendingList(onChanged: () {
      _onUpdate('pending.changed');
    });
    _uploader.status.addListener(() {
      _onUpdate('uploader.changed');
    });
    _networkStatus.addListener(() {
      _onUpdate('network.changed');
    });
  }

  void start() async {
    print('[UploadManager] Start');
    _outNotifiers = {};
    _notifiers = _loadFromStore().then((notifiers) {
      for (var entry in notifiers.entries) {
        if (entry.value.value == UploadStatus.pending)
          _pendingUploads.add(entry.key);
      }
      return notifiers;
    });
  }

  void scheduleUpload(Trip t) async {
    var notifiers = await _notifiers;
    notifiers.putIfAbsent(t, () => _SourceNotifier(this, t));
    if (notifiers[t].value == UploadStatus.local) {
      notifiers[t].value = UploadStatus.pending;
    }
  }

  void cancelUpload(Trip t) async {
    var notifiers = await _notifiers;
    print('[UploadManager] Cancelling upload for $t');
    notifiers[t].value = UploadStatus.local;
  }
  
  ValueNotifier<UploadStatus> status(Trip t) {
    if (_outNotifiers.containsKey(t)) {
      return _outNotifiers[t];
    }
    _outNotifiers[t] = _OutNotifier();
    _notifiers.then((notifiers) {
      notifiers.putIfAbsent(t, () => _SourceNotifier(this, t));
      var source = notifiers[t];
      _outNotifiers[t].value = source.value;
      source.addListener(() => _outNotifiers[t].value = source.value);
    });
    return _outNotifiers[t];
  }

  Future<Map<Trip, _SourceNotifier>> _loadFromStore() async {
    var trips = await _store.trips();
    var entries = trips.map((trip) async {
      var str = await _store.readMeta(trip, 'upload');
      if (str == null) {
        return MapEntry(trip, _SourceNotifier(this, trip));
      } else {
        return MapEntry(trip, _SourceNotifier(this, trip, _parse[str]));
      }
    });
    return Map.fromEntries(await Future.wait(entries));
  }

  Future<void> _writeInStore(Trip t, UploadStatus status) {
    // to restart upload in case of app crash,
    //     store `pending` instead of `uploading`.
    final rewrite = [UploadStatus.uploading, UploadStatus.error];
    if (rewrite.contains(status)) {
      status = UploadStatus.pending;
    }
    return _store.saveMeta(t, 'upload', _serialize[status]);
  }

  void _onStatusChanged(Trip t) async {
    var notifiers = await _notifiers;
    var notifier = notifiers[t];
    print('[UploadManager] ${notifier.value} : $t');

    await _writeInStore(t, notifier.value);
    notifier = notifiers[t];

    if (notifier.value == UploadStatus.pending) {
      _pendingUploads.add(t);
    } else {
      _pendingUploads.remove(t);
    }

    if (notifier.value == UploadStatus.error) {
      // on error, wait 1mn before retry
      print('[UploadManager] Waiting 1mn before retry');
      Timer(Duration(minutes: 1), (){
        if (notifier.value == UploadStatus.error)
          notifier.value = UploadStatus.pending;
      });
    }
  }

  Future<bool> _sendToUploader(Trip t, _SourceNotifier notifier) async {
    var tripEnd = (await _store.getInfo(t)).end;
    var up = Upload(t, tripEnd, notifier);

    for (Sensor sensor in Sensor.values) {
      up.items.add(() async {
        var data = await _store.readData(t, sensor);
        return UploadData(sensor.value, data.length, data.bytes);
      });
    }
    return await _uploader.upload(up);
  }

  Future<void> _onUpdate(String trigger) async {
    /// Helper with a non-void return type so that the compiler
    /// will enforce that all code-path are handled and
    /// syncStatus is updated correspondingly;
    syncStatus.value = await _onUpdateHelper(trigger);
  }

  Future<SyncStatus> _onUpdateHelper(String trigger) async {
    if (_pendingUploads.isEmpty) {
      return SyncStatus.done;
    }

    var notifiers = await _notifiers;

    // if network has gone off, cancel uploading
    if (_networkStatus.value != NetworkStatus.online) {
      print('[UploadManager] Network offline, stopping uploads (trigger: $trigger)');
      for (var status in notifiers.values) {
        if (status.value == UploadStatus.uploading)
          status.value = UploadStatus.pending;
      }
      return SyncStatus.awaitingNetwork;
    }

    switch(_uploader.status.value) {
      case UploaderStatus.uploading:
        return SyncStatus.uploading;

      case UploaderStatus.ready:
        print('[UploadManager] Processing next pending request (trigger: $trigger)');
        var trip = _pendingUploads.first;
        _sendToUploader(trip, notifiers[trip]);
        return SyncStatus.uploading;

      case UploaderStatus.offline:
        _uploader.start();
        print('[UploadManager] Uploader offline,'
            ' scheduling auto-start in 1mn (trigger: $trigger)');
        Timer.periodic(Duration(minutes: 1), (t) {
          var online = _networkStatus.value == NetworkStatus.online;
          var stopped = _uploader.status.value == UploaderStatus.offline;
          if (online && _pendingUploads.isNotEmpty && stopped) {
            print('\n\n\n\n[UploadManager] Auto-restarting Uploader now.');
            _uploader.start();
          } else {
            print('[UploadManager] Auto-restart obsolete. Cancelling Timer.');
            t.cancel();
          }
        });
        return SyncStatus.serverDown;
    }
    throw Exception('Not implemented');
  }

  static final _serialize =
  Map.fromEntries(
      UploadStatus.values.map(
              (v) => MapEntry(v, v.toString().split('.').last)
      )
  );

  static final _parse = Map.fromEntries(
      _serialize.entries.map((e) => MapEntry(e.value, e.key))
  );
}


class PendingList {
  final _data = <Trip>[];
  final Function onChanged;

  PendingList({this.onChanged});

  void add(Trip t) {
    _data.add(t);
    onChanged();
  }

  void remove(Trip t) {
    if (_data.remove(t))
      onChanged();
  }

  Trip get first => _data.first;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;
}

class _OutNotifier extends ValueNotifier<UploadStatus> {
  _OutNotifier() : super(UploadStatus.unknown);
}

class _SourceNotifier extends ValueNotifier<UploadStatus> {
  Trip _t;

  _SourceNotifier(UploadManager uploader, this._t, [UploadStatus value])
      : super(value ?? UploadStatus.pending)
  {
    this.addListener(() => uploader._onStatusChanged(this._t));
  }

  @override
  set value(UploadStatus newValue) {
    _ensureAllowed(newValue);
    super.value = newValue;
  }

  void _ensureAllowed(UploadStatus value) {
    if (value == UploadStatus.unknown) {
      throw Exception('SourceNotifier cannot hold unknown value');
    }
    else if (value == null) {
      throw Exception('SourceNotifier cannot hold null value');
    }
  }
}