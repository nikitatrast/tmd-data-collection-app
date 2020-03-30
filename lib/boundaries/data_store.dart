import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart' as plugin;

import '../models.dart' show Sensor, Serializable, Trip, ModeValue;
import '../utils.dart' show IterSum;

class TripInfo {
  Trip trip;
  DateTime end;
  int nbSensors;
  int sizeOnDisk;
}

class DataStore {
  Future<List<Trip>> trips() async {
    var root = await _rootDir();
    var trips = root.listSync().map((e) => _readTrip(e.path));
    trips = trips.where((trip) => trip != null);
    return trips.toList(growable: true);
  }

  Future<TripInfo> getInfo(Trip t) async {
    var info = TripInfo();
    var dir = Directory(await _dirPath(t));
    var getSize = (FileSystemEntity file) => file.statSync().size;
    info.trip = t;
    info.end = DateTime.fromMillisecondsSinceEpoch(
        int.parse(await File(await _endPath(t)).readAsString())
    );
    info.nbSensors = (await Future.wait(Sensor.values.map((sensor) async {
      var file = File(await _filePath(t, sensor));
      return file.existsSync() ? 1 : 0;
    }))).sum;
    info.sizeOnDisk = dir.listSync(recursive: true).map(getSize).sum;

    return info;
  }

  Future<bool> delete(Trip t) async {
    var path = await _dirPath(t);
    Directory(path).deleteSync(recursive: true);
    return true;
  }

  Future<void> save(Trip t, DateTime end) async {
    await _makeTripDirectory(t);
    var endFile = File(await _endPath(t));
    endFile.writeAsStringSync(end.millisecondsSinceEpoch.toString());
  }

  Future<void> recordData(Trip t, Sensor s, Stream<Serializable> dataStream) async {
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
    });
  }

  Future<int> nbEvents(Trip t, Sensor s) async {
    var file = File(await _filePath(t, s));
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

Trip _readTrip(String path) {
  try {
    var name = path.split('/').last;
    var parts = name.split('_');
    if (parts.length != 2) throw Exception('bad data');
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