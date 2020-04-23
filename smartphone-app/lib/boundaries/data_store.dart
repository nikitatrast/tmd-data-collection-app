import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart' as plugin;

import '../models.dart' show GeoFence, ModeValue, Sensor, Serializable, Trip;
import '../utils.dart' show IterSum;

class TripInfo {
  Trip trip;
  DateTime end;
  int nbSensors;
  int sizeOnDisk;
}

class RecordedData {
  int length;
  Stream<List<int>> bytes;

  RecordedData(this.length, this.bytes);
}

typedef NewTripCallback = void Function(Trip t);
typedef GeoFencesChangedCallback = void Function();

class RecordingFile {
  String path;
  Completer _completer;
  Trip _t;
}

abstract class ReadOnlyStore{
  Future<DateTime> getEnd(Trip t);
  Future<TripInfo> getInfo(Trip t);
  Future<int> nbEvents(Trip t, Sensor s);
  Future<RecordedData> readData(Trip t, Sensor s);
  Future<String> readMeta(Trip t, String key);
  Future<List<Trip>> trips();
}

abstract class GeoFenceStore {
  Future<List<GeoFence>> geoFences();
  Future<bool> saveGeoFences(Iterable<GeoFence> geoFences);
  bool get geoFencesUploaded;
  Future<bool> setGeoFencesUploaded(bool status);
}

class DataStore implements ReadOnlyStore, GeoFenceStore {
  final _recordings = Map<Trip, List<Completer>>();
  NewTripCallback onNewTrip = (Trip t) {};
  GeoFencesChangedCallback onGeoFencesChanged = () {};
  bool _geoFencesUploaded;
  bool get geoFencesUploaded => _geoFencesUploaded;

  DataStore() {
    _loadGeoFencesUploaded();
  }

  @override
  Future<List<GeoFence>> geoFences() async {
    var file = await _geoFenceFilePath();
    try {
      var lines = File(file).readAsLinesSync();
      return lines.map((line) => GeoFence.parse(line)).toList();
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

  Future<void> _loadGeoFencesUploaded() async {
    try {
      var file = await _geoFenceUploadedFilePath();
      _geoFencesUploaded = File(file).existsSync();
    } on Exception catch (e) {
      print('[DataStore] error while loading GeoFences status (see below).');
      print(e);
    }
  }

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

  Future<void> awaitRecordingsEnded(Trip t) async {
    var toAwait = _recordings[t];
    if (toAwait != null) {
      await Future.wait(toAwait.map((c) => c.future));
    }
  }

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

  Future<bool> delete(Trip t) async {
    await awaitRecordingsEnded(t);
    var path = await _dirPath(t);
    Directory(path).deleteSync(recursive: true);
    return true;
  }

  Future<void> save(Trip t, DateTime end) async {
    await _makeTripDirectory(t);
    await awaitRecordingsEnded(t);
    var endFile = File(await _endPath(t));
    endFile.writeAsStringSync(end.millisecondsSinceEpoch.toString());

    t.start = DateTime.fromMillisecondsSinceEpoch(t.start.millisecondsSinceEpoch);
    onNewTrip(t);
  }

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

  Future<void> closeRecordingFile(RecordingFile f) async {
    f._completer.complete();
    _recordings[f._t].remove(f._completer);
  }

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

  Future<void> saveMeta(Trip t, String key, String content) async {
    var file = File(await _metaPath(t, key));
    file.writeAsStringSync(content);
  }

  Future<String> readMeta(Trip t, String key) async {
    var file = File(await _metaPath(t, key));
    if (file.existsSync())
      return file.readAsStringSync();
    else
      return null;
  }

  Future<int> nbEvents(Trip t, Sensor s) async {
    var file = File(await _filePath(t, s));
    await awaitRecordingsEnded(t);
    return file.readAsStringSync().split('\n').length;
  }

  //----------------------------------------------------------------------------

  Future<void> _makeTripDirectory(Trip t) async {
    var dir = Directory(await _dirPath(t));
    dir.createSync();
  }
}

final _sensorNames = {
  Sensor.gps: 'gps',
  Sensor.accelerometer: 'accel',
};

Future<Directory> _rootDir() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/data');
  return dataDir.create();
}

Future<String> _geoFenceFilePath() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/geoFence');
  await dataDir.create();
  return dataDir.path + "/geofences.csv";
}

Future<String> _geoFenceUploadedFilePath() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/geoFence');
  await dataDir.create();
  return dataDir.path + "/uploaded.txt";
}

Future<String> _dirPath(Trip trip) async {
  var root = await _rootDir();
  var name = [
    trip.mode.value,
    trip.start.millisecondsSinceEpoch.toString(),
  ].join('_');
  return '${root.path}/$name';
}

Future<String> _endPath(Trip trip) async {
  return (await _dirPath(trip) + '/end.txt');
}

Future<String> _metaPath(Trip trip, String key) async {
  return (await _dirPath(trip) + '/$key.meta');
}

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

Future<String> _filePath(Trip trip, Sensor sensor) async {
  var tripDir = await _dirPath(trip);
  var filename = _sensorNames[sensor];
  return '$tripDir/$filename.csv';
}