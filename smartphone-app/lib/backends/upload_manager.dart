import 'dart:async';
import 'package:flutter/cupertino.dart';

import '../backends/network_manager.dart' show NetworkStatus;
import '../boundaries/data_store.dart';
import '../boundaries/uploader.dart';
import '../models.dart' show Sensor, SensorValue, Trip;

enum UploadStatus {
  local, pending, uploading, uploaded, unknown, error
}

enum SyncStatus {
  uploading, done, awaitingNetwork, serverDown
}

typedef UploadedCallback = void Function(Trip);

/// Manager that schedules [Trip]s uploads.
///
/// Developer documentation:
///
/// All the scheduling happens through a trip's source notifier
/// (see [SourceNotifierStore]).
///
/// 1. When the source notifier's value goes to [UploadStatus.pending], this
/// triggers a value listener that adds the trip to [_pendingUploads].
/// 2. When a pending upload is sent to the [Uploader], it's source notifier
/// value is set to [UploadStatus.uploading]. And so on.
/// 3. When the source notifier's value is set to [UploadStatus.uploaded], the
/// trip is removed from the [_pendingUploads] list and the [uploadedCallback]
/// is called.
///
/// [_OutNotifier]s are simple [ValueNotifier]s that mimic the source notifier's
/// value.
class UploadManager {
  /// Store where to fetch the trips.
  ReadOnlyStore _store;

  /// Store where to fetch the geoFences.
  GeoFenceStore _geoFenceStore;

  /// Store where to fetch the [UploadStatus] of each trip.
  SourceNotifierStore _notifiers;

  /// Used to provide the [UploadStatus] of a trip to the outside world.
  Map<Trip, _OutNotifier> _outNotifiers;

  /// List of items to be uploaded.
  PendingList _pendingUploads;

  /// [Uploader] used to upload the trips in [_pendingUploads].
  Uploader _uploader;

  /// Called when a trip is successfully uploaded.
  UploadedCallback uploadedCallback;

  /// Whether we are allowed to use the network.
  ValueNotifier<NetworkStatus> _networkStatus;

  /// Status of the synchronisation, based on whether we have [_pendingUploads].
  ValueNotifier<SyncStatus> syncStatus = ValueNotifier<SyncStatus>(SyncStatus.done);

  /// Periodic [Timer] to restart the [Uploader] when something goes wrong.
  Timer _autoRestartUploader;

  UploadManager(DataStore store, this._networkStatus, this._uploader)
  : _store = store
  , _geoFenceStore = store
  , uploadedCallback = store.delete
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

  /// Loads the [SourceNotifiers] which will also setup the listeners.
  void start() async {
    print('[UploadManager] Start');
    _notifiers.loadFromStore();
    _outNotifiers = {}; // should reset each time _notifiers is reloaded
  }

  /// Schedules [t] to be uploaded.
  void scheduleUpload(Trip t) async {
    var notifier = await _notifiers[t];
    if (notifier.value == UploadStatus.local) {
      notifier.value = UploadStatus.pending;
    }
  }

  /// Removes [t] from the [_pendingList] and cancels upload.
  Future<void> beforeTripDeletion(Trip t) async {
    print('[UploadManager] unlinking trip before deletion');
    var notifier = await _notifiers[t];
    var toCancel = [UploadStatus.pending, UploadStatus.uploading];
    if (toCancel.contains(notifier.value)) {
      notifier.value = UploadStatus.local;
    }
    await _notifiers.delete(t);
  }

  /// Cancels upload of [t].
  void cancelUpload(Trip t) async {
    var notifier = await _notifiers[t];
    print('[UploadManager] Cancelling upload for $t');
    notifier.value = UploadStatus.local;
  }

  /// Returns a [ValueNotifier] with the [UploadStatus] of [t].
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

  /// Takes appropriate action in response to the new status [status].
  void _onStatusChanged(Trip t, UploadStatus status) {
    //Important:
    //  keep the argument `status` with the status value that triggered this
    //  call, there is no time to reload the current status value from
    //  _notifiers because sometimes the value changes faster than the reload
    //  can happen and a key intermediate value might be missed.
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

    if (status == UploadStatus.uploaded) {
      print('[UploadManager] uploadedCallback( $t )');
      // Just a safety to make sure everything is done before the callback.
      Timer(Duration(seconds:1), () => uploadedCallback(t));
    }
  }

  Future<bool> _sendToUploader(Trip t) async {
    var notifier = await _notifiers[t];
    var info = await _store.getInfo(t);
    if (info == null) {

    }
    var tripEnd = info.end;
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

  /// Listener called when something changed and an action must be taken.
  ///
  /// Triggers can be:
  /// - [_pendingUploads] changed,
  /// - [_networkStatus] changed,
  /// - [_uploader.status] changed,
  /// - [scheduleGeoFenceUpload()],
  /// etc.
  ///
  Future<void> _onUpdate(String trigger) async {
    /// Helper with a non-void return type so that the compiler
    /// will enforce that all code-path are handled and
    /// syncStatus is updated correspondingly;
    syncStatus.value = await _onUpdateHelper(trigger);
  }

  /// See [_onUpdate()].
  Future<SyncStatus> _onUpdateHelper(String trigger) async {
    //if (_pendingUploads.isEmpty && _geoFenceStore.geoFencesUploaded != false) {
      // note: _geoFenceStore.geoFencesUploaded can be `null` hence the test
      //       for `false`.
    //  return SyncStatus.done;
    //}

    // if network has gone off, cancel uploading
    if (_networkStatus.value != NetworkStatus.online) {
      print('[UploadManager] Network offline, stopping uploads (trigger: $trigger)');
      for (var status in await _notifiers.values) {
        if (status.value == UploadStatus.uploading)
          status.value = UploadStatus.pending;
      }
      if (_geoFenceStore.geoFencesUploaded != false && _pendingUploads.isEmpty) {
        // fine, we're done anyways
        return SyncStatus.done;
      }
      return SyncStatus.awaitingNetwork;
    }

    switch(_uploader.status.value) {
      case UploaderStatus.uploading:
        return SyncStatus.uploading;

      case UploaderStatus.ready:
        if (_geoFenceStore.geoFencesUploaded == false) {
          print('[UploadManager] Uploading geoFences (trigger: $trigger, uploader: ${_uploader.status.value})');
          _geoFenceStore.setGeoFencesUploaded(null);
          _geoFenceStore.geoFences().then((geoFences) {
            _uploader.uploadGeoFences(geoFences).then((uploaded) {
                _geoFenceStore.setGeoFencesUploaded(uploaded);
            });
          }).catchError((e) => _geoFenceStore.setGeoFencesUploaded(false));
          return SyncStatus.uploading;
        }
        else if (_pendingUploads.isNotEmpty) {
          print(
              '[UploadManager] Processing next pending request (trigger: $trigger)');
          var pendingList = List.from(_pendingUploads);
          for (var trip in pendingList) {
            var notifier = await _notifiers[trip];
            if (notifier.value == UploadStatus.pending) {
              _sendToUploader(trip);
              return SyncStatus.uploading;
            }
          }
          print('[UploadManager] incoherent state: _pendingUploads.isNotEmpty but no _notifiers.value are pending...');
          return SyncStatus.uploading;
        }
        else {
          return SyncStatus.done;
        }
        break;

      case UploaderStatus.offline:
        // geoFencesUploaded can be null
        if (_geoFenceStore.geoFencesUploaded != false && _pendingUploads.isEmpty) {
          // fine, we're done anyways
          return SyncStatus.done;
        }
        if (_autoRestartUploader == null) {
          print('[UploadManager] Uploader offline,'
              ' starting now & scheduling auto-start in 1mn (trigger: $trigger)');
          _uploader.start();
          _autoRestartUploader = Timer.periodic(Duration(minutes: 1), (t) {
            var online = _networkStatus.value == NetworkStatus.online;
            var stopped = _uploader.status.value == UploaderStatus.offline;
            var hasFencesWork = _geoFenceStore.geoFencesUploaded == false;
            var workToDo = _pendingUploads.isNotEmpty || hasFencesWork;
            if (online && workToDo && stopped) {
              print('\n\n\n\n[UploadManager] Auto-restarting Uploader now.');
              _uploader.start();
            } else {
              print('[UploadManager] Auto-restart obsolete. Cancelling Timer.');
              _autoRestartUploader = null;
              t.cancel();
            }
          });
        }
        return SyncStatus.serverDown;
    }
    throw Exception('Not implemented');
  }

  void scheduleGeoFenceUpload() async {
    _onUpdate('geofences.changed');
  }
}


/// Implementation of a [List<Trip>] with an [onChanged] callback.
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


/// A type alias for [ValueNotifier<UploadStatus>] with default value.
///
/// Having a named type avoids confusion between a [ValueNotifier] that
/// is a source notifier, and one that is an out notifier.
class _OutNotifier extends ValueNotifier<UploadStatus> {
  _OutNotifier() : super(UploadStatus.unknown);
}

/// Class responsible to load source notifiers from the [DataStore].
class SourceNotifierStore {
  Future<Map<Trip, ValueNotifier<UploadStatus>>> _notifiers;
  final UploadManager _uploader;
  final DataStore _store;
  final _loaded = Completer<Map<Trip, ValueNotifier<UploadStatus>>>();
  List<Trip> _created = [];

  SourceNotifierStore(this._uploader, this._store) {
     _notifiers = _loaded.future;
  }

  /// Creates the [ValueNotifier] with all the required listeners.
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

  Future<void> delete(Trip t) async {
    var notifiers = await _notifiers;
    var notifier = notifiers[t];
    notifiers.remove(notifier);
    notifier.dispose();
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
    print('source notifier setting new value: $value');
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