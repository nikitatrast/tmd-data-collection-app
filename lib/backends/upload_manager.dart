import 'dart:async';
import 'package:accelerometertest/boundaries/uploader.dart';
import 'package:flutter/cupertino.dart';

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
  ReadOnlyStore _store;
  SourceNotifierStore _notifiers;
  Map<Trip, _OutNotifier> _outNotifiers;
  PendingList _pendingUploads;
  Uploader _uploader;
  ValueNotifier<NetworkStatus> _networkStatus;
  ValueNotifier<SyncStatus> syncStatus = ValueNotifier<SyncStatus>(SyncStatus.done);

  UploadManager(DataStore store, this._networkStatus, this._uploader)
  : _store = store
  {
    _notifiers = SourceNotifierStore(this, store);
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
    _notifiers.loadFromStore();
    _outNotifiers = {}; // should reset each time _notifiers is reloaded
  }

  void scheduleUpload(Trip t) async {
    var notifier = await _notifiers[t];
    if (notifier.value == UploadStatus.local) {
      notifier.value = UploadStatus.pending;
    }
  }

  void cancelUpload(Trip t) async {
    var notifier = await _notifiers[t];
    print('[UploadManager] Cancelling upload for $t');
    notifier.value = UploadStatus.local;
  }
  
  _OutNotifier status(Trip t) {
    if (_outNotifiers.containsKey(t)) {
      return _outNotifiers[t];
    }
    print('[UploadManager] outNotifier not found for $t');

    _outNotifiers[t] = _OutNotifier();
    _notifiers[t].then((notifier) {
      print('[UploadManager] cabling outNotifier value for $t, ${notifier.value}');
      _outNotifiers[t].value = notifier.value;
      notifier.addListener(() => _outNotifiers[t].value = notifier.value);
    });
    return _outNotifiers[t];
  }

  void _onStatusChanged(Trip t, UploadStatus status) {
    //Important:
    //  keep the argument `status` with the status value that triggered thi call
    //  there is no time to reload the current status value from _notifiers
    //  because sometimes the value changes faster than the reload can happen
    //  and key value might be missed
    //
    // _pendingUploads.add and .remove should be called ASAP, avoid await before

    print('[UploadManager] statusChanged:: $status : $t');

    if (status == UploadStatus.pending) {
      _pendingUploads.add(t);
    } else {
      _pendingUploads.remove(t);
    }

    if (status == UploadStatus.error) {
      print('[UploadManager] Waiting 1mn before retry');
      Timer(Duration(minutes: 1), () async {
        var notifier = await _notifiers[t];
        if (notifier.value == UploadStatus.error)
          notifier.value = UploadStatus.pending;
      });
    }
  }

  Future<bool> _sendToUploader(Trip t) async {
    var notifier = await _notifiers[t];
    var tripEnd = (await _store.getInfo(t)).end;
    var up = Upload(t, tripEnd, notifier);

    for (Sensor sensor in Sensor.values) {
      up.items.add(() async {
        var data = await _store.readData(t, sensor);
        if (data != null) {
          return UploadData(sensor.value, data.length, data.bytes);
        } else {
          return null;
        }
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
    // if network has gone off, cancel uploading
    if (_networkStatus.value != NetworkStatus.online) {
      print('[UploadManager] Network offline, stopping uploads (trigger: $trigger)');
      for (var status in await _notifiers.values) {
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
        var pendingList = List.from(_pendingUploads);
        for (var trip in pendingList) {
          var notifier = await _notifiers[trip];
          if (notifier.value == UploadStatus.pending) {
            _sendToUploader(trip);
            return SyncStatus.uploading;
          }
        }
        return SyncStatus.done;

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
}


class PendingList extends Iterable{
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

  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  @override
  Iterator get iterator => _data.iterator;
}


class _OutNotifier extends ValueNotifier<UploadStatus> {
  _OutNotifier() : super(UploadStatus.unknown);
}


class SourceNotifierStore {
  Future<Map<Trip, ValueNotifier<UploadStatus>>> _notifiers;
  final UploadManager _uploader;
  final DataStore _store;
  final _loaded = Completer<Map<Trip, ValueNotifier<UploadStatus>>>();
  List<Trip> _created = [];

  SourceNotifierStore(this._uploader, this._store) {
     _notifiers = _loaded.future;
  }

  ValueNotifier<UploadStatus> _createNotifier(Trip t, [UploadStatus value]) {
    assert(!_created.contains(t));
    _created.add(t);

    var n = ValueNotifier<UploadStatus>(value ?? UploadStatus.local);
    n.addListener(() => _ensureValid(n.value));
    n.addListener(() => _uploader._onStatusChanged(t, n.value));
    n.addListener(() => writeInStore(t));
    _uploader._onStatusChanged(t, n.value);
    return n;
  }

  Future<void> loadFromStore() async {
    var trips = await _store.trips();
    var notifiers = Map<Trip, ValueNotifier<UploadStatus>>();
    for (var trip in trips) {
      var str = await _store.readMeta(trip, 'upload');
      notifiers[trip] = _createNotifier(trip, _parse[str]);
    }
    _loaded.complete(notifiers);
  }

  Future<void> writeInStore(Trip t) async {
    // to restart upload in case of app crash,
    //     store `pending` instead of `uploading`.
    var status = (await this[t]).value;
    final rewrite = [UploadStatus.uploading, UploadStatus.error];
    if (rewrite.contains(status)) {
      status = UploadStatus.pending;
    }
    return _store.saveMeta(t, 'upload', _serialize[status]);
  }

  Future<ValueNotifier<UploadStatus>> operator[](Trip t) async {
    var notifiers = await _notifiers;
    notifiers.putIfAbsent(t, () => _createNotifier(t));
    return notifiers[t];
  }

  get values => _notifiers.then((n) => n.values);
  get keys => _notifiers.then((n) => n.keys);

  void _ensureValid(UploadStatus value) {
    print('[SourceNotifier] setting new value: $value');
    if (value == UploadStatus.unknown) {
      throw Exception('SourceNotifier cannot hold unknown value');
    }
    else if (value == null) {
      throw Exception('SourceNotifier cannot hold null value');
    }
  }

  static final _serialize = Map.fromEntries(
      UploadStatus.values.map(
              (v) => MapEntry(v, v.toString().split('.').last)
      )
  );

  static final _parse = Map.fromEntries(
      _serialize.entries.map((e) => MapEntry(e.value, e.key))
  );
}