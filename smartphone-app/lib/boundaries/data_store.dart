import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart' as plugin;

import '../models.dart' show GeoFence, ModeValue, Sensor, Serializable, Trip;
import '../utils.dart' show IterSum;

/// Information about a [Trip] stored on disk.
class TripInfo {
  Trip trip;

  /// End of [trip].
  DateTime end;

  /// Number of sensors from which data was collected during this [trip].
  int nbSensors;

  /// Size in bytes of all the data stored for this [trip].
  int sizeOnDisk;
}

/// Simple holder class for a stream of [bytes] and its [length].
class RecordedData {
  int length;
  Stream<List<int>> bytes;

  RecordedData(this.length, this.bytes);
}

/// Callback called when a new trip is persisted in the [DataStore].
typedef NewTripCallback = void Function(Trip t);

/// Callback called when a new trip is deleted from the [DataStore].
typedef BeforeTripDeletionCallback = Future<void> Function(Trip t);

/// Callback called when [GeoFence]s are persited in the [DataStore].
typedef GeoFencesChangedCallback = void Function();

/// Path to a file in which sensor data can be recorded.
class RecordingFile {
  /// Path to the file where sensor data may be recorded.
  String path;

  /// When [_completer] is completed, this [RecordingFile] is considered closed.
  Completer _completer;

  /// The [Trip] for which this [RecordingFile] records data.
  Trip _t;
}

/// A Read-only version of [DataStore] to access [Trip]s stored on disk.
abstract class ReadOnlyStore{
  /// Gets the [DateTime] at which [t] ended.
  Future<DateTime> getEnd(Trip t);

  /// Gets [TripInfo] for [t].
  Future<TripInfo> getInfo(Trip t);

  /// Gets the number of events collected for sensor [s] during trip [t].
  Future<int> nbEvents(Trip t, Sensor s);

  /// Reads the collected data for sensor [s] during trip [t].
  Future<RecordedData> readData(Trip t, Sensor s);

  /// Reads the meta-data associated with [key] for trip [t].
  Future<String> readMeta(Trip t, String key);

  /// The list of stored trips.
  Future<List<Trip>> trips();
}

/// Used by [TripRecorderBackendImpl] to persist trips.
abstract class TripRecorderStorage {
  /// Deletes all data persisted for trip [t].
  Future<bool> delete(Trip t);

  /// Persists [t] to disk.
  Future<void> save(Trip t, DateTime end);

  /// Records the sensor [s] data provided in [dataStream] for trip [t].
  Future<void> recordData(Trip t, Sensor s, Stream<Serializable> dataStream);
}

/// Store where to read and persist user's [GeoFence]s.
abstract class GeoFenceStore {
  /// This list of stored geofences.
  Future<List<GeoFence>> geoFences();

  /// Replace persisted geofences with [geoFences].
  Future<bool> saveGeoFences(Iterable<GeoFence> geoFences);

  /// Whether the last persisted geofences have been uploaded.
  bool get geoFencesUploaded;

  /// Mark the last persisted geofences as uploaded ([status = true]) or not.
  Future<bool> setGeoFencesUploaded(bool status);
}

class DataStore implements ReadOnlyStore, GeoFenceStore, TripRecorderStorage {
  /// Static instance to make sure MainIsolate and ForegroundService Isolate
  /// use the same class for storage.
  ///
  /// On Android, sensor recording is done in a foreground service, whose code
  /// is run in a dart Isolate. Isolates do not share any memory with the
  /// main Isolate, and therefore initialization must be static.
  static final DataStore instance = DataStore._make();

  /// A [List] of [Completer] for each [Trip] being recorded.
  ///
  /// The [Completer] are completed when a recording operation is finished.
  final _recordings = Map<Trip, List<Completer>>();

  /// Called when a new [Trip] is saved.
  NewTripCallback onNewTrip = (Trip t) {};

  /// Called when a [Trip] is deleted.
  List<BeforeTripDeletionCallback> beforeTripDeletion = [];

  /// Called when a [GeoFence] is added or deleted.
  GeoFencesChangedCallback onGeoFencesChanged = () {};

  /// Whether the current [GeoFence]s have been uploaded to the server.
  bool _geoFencesUploaded;

  /// Whether the current [GeoFence]s have been uploaded to the server.
  bool get geoFencesUploaded => _geoFencesUploaded;

  DataStore._make() {
    _loadGeoFencesUploaded();
  }

  @override
  Future<List<GeoFence>> geoFences() async {
    var filepath = await _geoFenceFilePath();
    try {
      var file = File(filepath);
      if (file.existsSync()) {
        var lines = file.readAsLinesSync();
        return lines.map((line) => GeoFence.parse(line)).toList();
      } else {
        return [];
      }
    } on Exception catch (e) {
      print('[DataStore] error while loading GeoFence file (see below).');
      print(e);
      return [];
    }
  }

  @override
  Future<bool> saveGeoFences(Iterable<GeoFence> geoFences) async {
    try {
      var file = await _geoFenceFilePath();
      var lines = geoFences.map((f) => f.serialize());
      File(file).writeAsStringSync(lines.join('\n'));

      var uploadedFile = await _geoFenceUploadedFilePath();
      try {
        File(uploadedFile).deleteSync();
      } on FileSystemException {
        // ignore
      }
      _geoFencesUploaded = false;

      onGeoFencesChanged();
      return true;
    } on Exception catch (e) {
      print('[DataStore] error while saving GeoFences (see below).');
      print(e);
      return false;
    }
  }

  /// Loads the value of [_geoFencesUploaded] from disk.
  Future<void> _loadGeoFencesUploaded() async {
    try {
      var file = await _geoFenceUploadedFilePath();
      _geoFencesUploaded = File(file).existsSync();
    } on Exception catch (e) {
      print('[DataStore] error while loading GeoFences status (see below).');
      print(e);
    }
  }

  @override
  Future<bool> setGeoFencesUploaded(bool status) async {
    _geoFencesUploaded = status;
    try {
      var file = File(await _geoFenceUploadedFilePath());
      if (status == true) {
        file.createSync();
      } else if (status == false) {
        try {
          file.deleteSync();
        } on FileSystemException catch(e) {
          //ignore
        }
      }
      return true;
    } on Exception catch (e) {
      print('[DataStore] error in setGeoFencesUploaded (see below).');
      print(e);
      return false;
    }
  }

  @override
  Future<List<Trip>> trips() async {
    var root = await _rootDir();
    var rawTrips = root.listSync().map((e) => _readTrip(e.path));
    var trips = <Trip>[];
    for (var raw in rawTrips) {
      if (await getEnd(raw) != null) {
        trips.add(raw);
      }
    }
    return trips;
  }

  /// Completes when all sensor data recordings for [t] have ended.
  Future<void> awaitRecordingsEnded(Trip t) async {
    var toAwait = _recordings[t];
    if (toAwait != null) {
      await Future.wait(toAwait.map((c) => c.future));
    }
  }

  @override
  Future<TripInfo> getInfo(Trip t) async {
    await awaitRecordingsEnded(t);
    try {
      var info = TripInfo();
      var dir = Directory(await _dirPath(t));
      var getSize = (FileSystemEntity file) =>
      file
          .statSync()
          .size;
      info.trip = t;
      info.end = await getEnd(t);
      info.nbSensors = (await Future.wait(Sensor.values.map((sensor) async {
        var file = File(await _filePath(t, sensor));
        return file.existsSync() ? 1 : 0;
      }))).sum;
      info.sizeOnDisk = dir
          .listSync(recursive: true)
          .map(getSize)
          .sum;
      return info;
    } on FileSystemException catch (e) {
      print('[DataStore] getInfo(Trip) exception: ');
      print(e);
      return null;
    }
  }

  @override
  Future<DateTime> getEnd(Trip t) async {
    await awaitRecordingsEnded(t);
    if (t == null)
      return null;
    try {
      return DateTime.fromMillisecondsSinceEpoch(
          int.parse(await File(await _endPath(t)).readAsString())
      );
    } on FileSystemException catch(e) {
      return null;
    }
  }

  /// Deletes all data persisted for trip [t].
  Future<bool> delete(Trip t) async {
    await awaitRecordingsEnded(t);
    // Make a copy of beforeTripDeletion to allow concurrent modifications.
    for (var callback in List.from(beforeTripDeletion))
      await callback(t);
    var path = await _dirPath(t);
    Directory(path).deleteSync(recursive: true);
    return true;
  }

  /// Persists [t] to disk.
  Future<void> save(Trip t, DateTime end) async {
    await _makeTripDirectory(t);
    await awaitRecordingsEnded(t);
    var endFile = File(await _endPath(t));
    endFile.writeAsStringSync(end.millisecondsSinceEpoch.toString());

    t.start = DateTime.fromMillisecondsSinceEpoch(t.start.millisecondsSinceEpoch);
    onNewTrip(t);
  }

  /// Records the sensor [s] data provided in [dataStream] for trip [t].
  Future<void> recordData(Trip t, Sensor s, Stream<Serializable> dataStream) async {
    _recordings.putIfAbsent(t, () => <Completer>[]);
    var c = Completer();
    _recordings[t].add(c);
    await _makeTripDirectory(t);
    var file = File(await _filePath(t, s));
    var sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    Stream<String> strings = dataStream.map((x) => x.serialize());
    strings = strings.map((str) => '${str.trim()}\n'); // one per line

    var operation = sink
        .addStream(strings.transform(utf8.encoder))
        .then((v) async {
      sink.close();
      var length = await file.length();
      print('[DataStoreEntry] file closed for $s, length is $length');
      if (length == 0) {
        await file.delete();
        print('[DataStoreEntry] 0-length $s file deleted');
      }
      c.complete();
      _recordings[t].remove(c);
    });
  }

  /// Provides a [RecordingFile] in which sensor data for [s] can be written.
  ///
  /// Remember to call [closeRecordingFile()] to close the handle.
  Future<RecordingFile> openRecordingFile(Trip t, Sensor s) async {
    _recordings.putIfAbsent(t, () => <Completer>[]);
    var c = Completer();
    _recordings[t].add(c);
    await _makeTripDirectory(t);
    var f = RecordingFile();
    f.path = await _filePath(t, s);
    f._t = t;
    f._completer = c;
    return f;
  }

  /// Closes the file handler associated to [f].
  Future<void> closeRecordingFile(RecordingFile f) async {
    f._completer.complete();
    _recordings[f._t].remove(f._completer);
  }

  /// Reads sensor [s] data recorded for [t].
  ///
  /// null if no data available.
  Future<RecordedData> readData(Trip t, Sensor s) async {
    var file = File(await _filePath(t, s));
    await awaitRecordingsEnded(t);
    try {
      return RecordedData(
          file.lengthSync(),
          file.openRead()
      );
    } on FileSystemException catch(e) {
      return null;
    }
  }

  /// Associates the key-value pair ([key], [content]) to trip [t]'s data.
  Future<void> saveMeta(Trip t, String key, String content) async {
    var file = File(await _metaPath(t, key));
    file.writeAsStringSync(content);
  }

  /// Read the value associated to [t] using key [key].
  ///
  /// See [saveMeta()].
  Future<String> readMeta(Trip t, String key) async {
    var file = File(await _metaPath(t, key));
    if (file.existsSync())
      return file.readAsStringSync();
    else
      return null;
  }

  /// Reads the number of sensor events recorded in trip [t] for sensor [s].
  Future<int> nbEvents(Trip t, Sensor s) async {
    var file = File(await _filePath(t, s));
    await awaitRecordingsEnded(t);
    return file.readAsStringSync().split('\n').length;
  }

  //----------------------------------------------------------------------------

  /// Creates a directory in which dat for trip [t] can be persisted.
  Future<void> _makeTripDirectory(Trip t) async {
    var dir = Directory(await _dirPath(t));
    dir.createSync();
  }
}

/// Slug used to create sensor's data filenames.
final _sensorNames = {
  Sensor.gps: 'gps',
  Sensor.accelerometer: 'accel',
};

/// Root directory in which to store [DataStore]'s data.
Future<Directory> _rootDir() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/data');
  return dataDir.create();
}

/// Path to the file where to persist the geofences.
Future<String> _geoFenceFilePath() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/geoFence');
  await dataDir.create();
  return dataDir.path + "/geofences.csv";
}

/// Path to the file where the uploaded status of the geofences is written.
Future<String> _geoFenceUploadedFilePath() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/geoFence');
  await dataDir.create();
  return dataDir.path + "/uploaded.txt";
}

/// Path to the directory where to persist [trip]'s data.
Future<String> _dirPath(Trip trip) async {
  var root = await _rootDir();
  var name = [
    trip.mode.value,
    trip.start.millisecondsSinceEpoch.toString(),
  ].join('_');
  return '${root.path}/$name';
}

/// Path to the file where the ending date of [trip] can be persisted.
Future<String> _endPath(Trip trip) async {
  return (await _dirPath(trip) + '/end.txt');
}

/// Path to the file where the metadata associated with [key] can be stored.
///
/// [key] should be a valid filename identifier. For instance, use only
/// lower-case and upper-case letters.
Future<String> _metaPath(Trip trip, String key) async {
  return (await _dirPath(trip) + '/$key.meta');
}

/// Parses the trip serialized in the file at [path].
Trip _readTrip(String path) {
  try {
    var name = path.split('/').last;
    var parts = name.split('_');
    if (parts.length != 2) {
      File(path).delete(recursive: true);
      throw Exception('[DataStore] Unexpected filename encountered, skipped');
    }
    var t = Trip();
      t.mode = ModeValue.fromValue(parts[0]);
      t.start = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
      if (t.mode == null) throw Exception('trip mode is null');
      if (t.start == null) throw Exception('trip start is null');
      return t;
    } on Exception catch (e) {
    print(e);
    return null;
  }
}

/// Path to the file where data for [sensor] collected during [trip] can be
/// persisted.
Future<String> _filePath(Trip trip, Sensor sensor) async {
  var tripDir = await _dirPath(trip);
  var filename = _sensorNames[sensor];
  return '$tripDir/$filename.csv';
}