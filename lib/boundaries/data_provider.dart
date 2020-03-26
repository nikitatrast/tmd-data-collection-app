import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as plugin;
import '../models.dart' show Trip, StoredTrip, Sensor, ModeRoute, Acceleration, Location;
import '../widgets/explorer_widget.dart' show ExplorerBackend;

class DataProvider implements ExplorerBackend {

  Future<List<StoredTrip>> trips() async {
    var items = (await _dataDirectory()).listSync();
    var fullItems = (await _dataDirectory()).listSync(recursive: true);
    print('[DataProvider] available items:');
    print('\t' + fullItems.join('\n\t'));
    print('---------------------------');
    var trips = <StoredTrip>[];
    for (var item in items) {
      try {
        trips.add(_makeTrip(item));
      } on Exception {
        print('[DataProvider] Skipped ${item.path}');
      }
    }
    return trips;
  }

  Future<bool> delete(Trip t) async {
    try {
      var path = await _folderPath(t);
      var dir = Directory(path);
      dir.deleteSync(recursive: true);
      return true;
    } on Exception catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> persist(Trip t) async {
    assert(t.start != null);
    assert(t.end != null);
    assert(t.mode != null);

    var tripDirectory = await _folderPath(t);
    Directory(tripDirectory).createSync();

    for (var sensor in t.sensorsData.keys) {
      var data = t.sensorsData[sensor];
      if (data != null && data.isNotEmpty) {
        var file = File(await _filepath(t, sensor));
        data.fold(file, (file, e) async {
          return (await file).writeAsString(
              sensor.toCsvLine(e)
          );
        });
      }
    }
  }

  Future<Trip> getSensorData(Trip t, Sensor sensor) async {
    var path = await _filepath(t, sensor);
    var file = File(path);
    if (!file.existsSync()) {
      t.sensorsData[sensor] = null;
      print('[DataProvider] Sensor data not found at $path');
      return t;
    }

    var data = [];
    file.openRead()
        .transform(utf8.decoder)       // Decode bytes to UTF-8.
        .transform(new LineSplitter()) // Convert stream to individual lines.
        .listen((String line) {
      data.add(sensor.makeFromString(line));
    });
    t.sensorsData[sensor] = data;
    print('[DataProvider] Sensor data found at $path');
    return t;
  }
}

// ---------------------------------------------------------------------------

const _sensorNames = {
  Sensor.gps: 'gps',
  Sensor.accelerometer: 'accel',
};

final _sensorFromName = _sensorNames.map((k,v) => MapEntry(v, k));

extension _SensorParser on Sensor {
  dynamic makeFromString(String line) {
    var parts = line.split(',');
    switch(this) {
      case Sensor.gps:
        return Location(
          time: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
          latitude: double.parse(parts[1]),
          longitude: double.parse(parts[2]),
          altitude: double.parse(parts[3]),
        );
    break;
      case Sensor.accelerometer:
        return Acceleration(
          time: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
          x: double.parse(parts[1]),
          y: double.parse(parts[2]),
          z: double.parse(parts[3]),
        );
        break;
    }
  }
  String toCsvLine(dynamic data) {
    switch(this) {
      case Sensor.gps:
        var e = data as Location;
        return '${e.time.millisecondsSinceEpoch}'
            '${e.latitude}, ${e.longitude}, ${e.altitude}';
        break;
      case Sensor.accelerometer:
        var e = data as Acceleration;
        return '${e.time.millisecondsSinceEpoch}'
            '${e.x}, ${e.y}, ${e.z}';
        break;
      default:
        assert(false);
        return 'unknown sensor data';
    }
  }
}

Future<Directory> _dataDirectory() async {
  final dir = await plugin.getApplicationDocumentsDirectory();
  final dataDir = Directory(dir.path + '/data');
  return dataDir.create();
}

StoredTrip _makeTrip(FileSystemEntity item) {
  var filename = item.path
      .split('/')
      .last;
  var parts = filename.split('_');
  var result = StoredTrip();
  result.mode = ModeRoute.fromRoute('/' + parts[0]);
  result.start = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
  result.end = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]));

  var dir = item as Directory;
  var files = dir.listSync();
  var sensors = files.map((e) => e.path.split('/').last.split('.').first);
  var sizes = files.map((e) => e.statSync().size);
  result.sizeOnDisk = (sizes.isEmpty) ? 0 : sizes.reduce((a,b) => a + b);
  result.sensorsData = Map.fromEntries(sensors.map(
          (s) => MapEntry(_sensorFromName[s], null)
  ));
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

Future<String> _filepath(Trip trip, Sensor sensor) async {
  var folderPath = await _folderPath(trip);
  var filename = _sensorNames[sensor];
  return '$folderPath/$filename.csv';
}