import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as plugin;
import '../models.dart' show ModeRoute, Sensor, Serializable, Trip;
import '../widgets/explorer_widget.dart' show ExplorerBackend, ExplorerItem;

class DataStoreEntry {
  Trip _trip;
  Directory _dir;
  Future _recordingOps = Future.value(null);

  DataStoreEntry._make(this._trip, this._dir);

  Future<void> record(Sensor sensor, Stream<Serializable> data) async {
    print('[DataStoreEntry] opening file for $sensor');
    final destPath = _filepath(_trip, sensor, _dir.path);
    var file = File(destPath);
    var sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    Stream<String> strings = data.map((x) => x.serialize());

    var operation = sink
        .addStream(strings.transform(utf8.encoder))
        .then((v) async {
          sink.close();
          var length = await file.length();
          print('[DataStoreEntry] file closed for $sensor, length is $length');
          if (length == 0) {
            await file.delete();
            print('[DataStoreEntry] 0-length $sensor file deleted');
          }
        });

    _recordingOps = _recordingOps.then((v) async => await operation);
  }

  Future<bool> delete() async {
    try {
      print('[DataStoreEntry] waiting for operations to finish (${_trip.mode})');
      await _recordingOps;
      print('[DataStoreEntry] operations finished, deleting this entry (${_trip.mode})');
      _dir.deleteSync(recursive: true);
      return true;
    } on Exception catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> save(DateTime end) async {
    _trip.end = end;
    final destPath = await _folderPath(_trip);
    print('[DataStoreEntry] waiting for operations to finish (${_trip.mode})');
    await _recordingOps;
    print('[DataStoreEntry] operations finished, renaming this entry (${_trip.mode})');
    _dir.renameSync(destPath);
    return true;
  }

  Stream<String> readHistory(Sensor sensor) {
    final destPath = _filepath(_trip, sensor, _dir.path);
    var inputStream = File(destPath).openRead();
    return inputStream.transform(utf8.decoder).transform(LineSplitter());
  }
}


class DataStore implements ExplorerBackend {

  Future<DataStoreEntry> getEntry(Trip t) async {
    t.end = t.end ?? t.start;
    var tripDirectory = await _folderPath(t);
    var dir = Directory(tripDirectory);
    dir.createSync();
    return DataStoreEntry._make(t, dir);
  }

  Future<List<ExplorerItem>> trips() async {
    var items = (await _dataDirectory()).listSync();
    var fullItems = (await _dataDirectory()).listSync(recursive: true);
    print('[DataProvider] available items:');
    print('\t' + fullItems.join('\n\t'));
    print('---------------------------');
    var trips = <ExplorerItem>[];
    for (var item in items) {
      try {
        trips.add(_makeTrip(item));
      } on Exception {
        print('[DataProvider] Skipped ${item.path}');
      }
    }
    return trips;
  }

  @override
  Future<bool> delete(ExplorerItem item) async {
    var entry = await getEntry(item);
    return await entry.delete();
  }


}

// ---------------------------------------------------------------------------

const _sensorNames = {
  Sensor.gps: 'gps',
  Sensor.accelerometer: 'accel',
};

final _sensorFromName = _sensorNames.map((k,v) => MapEntry(v, k));

Future<Directory> _dataDirectory() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/data');
  return dataDir.create();
}

ExplorerItem _makeTrip(FileSystemEntity item) {
  var filename = item.path
      .split('/')
      .last;
  var parts = filename.split('_');
  var result = ExplorerItem();
  result.mode = ModeRoute.fromRoute('/' + parts[0]);
  result.start = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
  result.end = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]));

  var dir = item as Directory;
  List<FileSystemEntity> files = dir.listSync();
  var sizes = files.map((e) => e.statSync().size);
  result.nbSensors = files.length;
  result.sizeOnDisk = (sizes.isEmpty) ? 0 : sizes.reduce((a,b) => a + b);
  result.nbEvents = (Sensor sensor) async {
    var path = _filepath(result, sensor, dir.path);
    try {
      return File(path).readAsStringSync().length;
    } on FileSystemException {
      return -1;
    }
  };
  return result;
}

Future<String> _folderPath(Trip trip) async {
  var dir = await _dataDirectory();
  var name = [
        trip.mode.route,
        trip.start.millisecondsSinceEpoch.toString(),
        trip.end.millisecondsSinceEpoch.toString(),
      ].join('_');
  return '${dir.path}/$name';
}

String _filepath(Trip trip, Sensor sensor, String folderPath) {
  var filename = _sensorNames[sensor];
  return '$folderPath/$filename.csv';
}