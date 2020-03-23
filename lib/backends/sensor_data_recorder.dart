import 'dart:async';
import 'dart:io';

import 'package:location/location.dart' as loc;
import 'package:sensors/sensors.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/trip_recorder.dart' show DataRecorder;

import '../modes.dart';

class Event<B> {
  final DateTime datetime;
  final B event;

  Event(this.datetime, this.event);

  @override
  String toString() => '<$datetime, $event>';
}

class SensorDataRecorder implements DataRecorder {
  Future<bool> gpsEnabled;
  loc.Location locationService = loc.Location();
  StreamSubscription<loc.LocationData> locationStream;
  List<loc.LocationData> locationEvents = [];
  List<Function> locationListeners = [];

  StreamSubscription<AccelerometerEvent> accelerationStream;
  List<Event<AccelerometerEvent>> accelerationEvents = [];
  
  SensorDataRecorder({Future<bool> gpsAllowed}) {
    gpsEnabled = resolveGPS(gpsAllowed);
  }

  Future<bool> resolveGPS(Future<bool> gpsAllowed) async {
    var allowed = await gpsAllowed;
    print('[SensorRecorder] gps allowed: $allowed');
    if (allowed) { // only request authorization if allowed
      var enabled = await enableLocationService();
      print('[SensorRecorder] gps enabled: $enabled');
      return allowed && enabled;
    }
    return allowed;
  }

  @override
  Future<bool> locationAvailable() {
    return gpsEnabled;
  }

  @override
  void startRecording() async {
    print('[SensorRecorder] startRecording');
    accelerationStream = accelerometerEvents.listen(onNewAcceleration);

    if (await locationAvailable()) {
        locationStream = locationService.onLocationChanged().listen(onNewLocation);
    }
  }

  @override
  void pauseRecording() {
    print('[SensorRecorder] pauseRecording');
    locationStream?.pause();
    accelerationStream?.pause();
  }

  @override
  void stopRecording() {
    print('[SensorRecorder] stopRecording');
    accelerationStream?.cancel();
    locationStream?.cancel();
  }

  @override
  void addLocationListener(Function listener) {
    print('[SensorRecorder] addLocationListener'
        ' (already have ${locationListeners.length})');
    locationListeners.add(listener);
  }

  @override
  Future<bool> persistData(Modes travelMode) async {
    print('[SensorRecorder] persistData for ${travelMode.text}');
    var timestamp = new DateTime.now().millisecondsSinceEpoch;

    var accelFile = getFile(travelMode, 'accelerometer', timestamp);
    accelerationEvents.fold(accelFile, (file, e) async {
      return (await file).writeAsString(
        '${e.datetime.millisecondsSinceEpoch}'
            '${e.event.x}, ${e.event.y}, ${e.event.z}'
      );
    });

    if (!await locationAvailable()) {
      print('[SensorRecored] location data not persisted.');
    } else {
      var gpsFile = getFile(travelMode, 'gps', timestamp);
      locationEvents.fold(gpsFile, (file, e) async {
        return (await file).writeAsString(
            '${e.time.toInt()}'
             ', ${e.latitude}, ${e.longitude}, ${e.altitude}'
              ', ${e.speed}');
      });
    }
    return true;
  }

  Future<File> getFile(
      Modes travelMode, String sensorName, int timestamp) async {
    final root = await getApplicationDocumentsDirectory();
    var dataDir = Directory(root.path + '/data');
    dataDir = await dataDir.create();
    var filename = '${travelMode.route}_${timestamp}_$sensorName';
    assert(filename[0] == '/'); // routes start with a leading '/'
    var file = File(dataDir.path + '$filename.csv');
    return file;
  }

  void onNewAcceleration(AccelerometerEvent event) {
    accelerationEvents.add(Event(DateTime.now(), event));
  }

  void onNewLocation(loc.LocationData loc) {
    locationEvents.add(loc);
    for (var listener in locationListeners) {
      listener(loc.latitude, loc.longitude, loc.altitude);
    }
  }

  Future<bool> enableLocationService() async {
    var enabled = await requestPermission();
    if (enabled) {
      locationService.changeSettings(
          accuracy: loc.LocationAccuracy.HIGH,
          interval: 1000 ~/ 20 /* ms */,
      );
    }
    return enabled;
  }

  Future<bool> requestPermission() async {
    var serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    var permissionGranted = await locationService.hasPermission();
    if (permissionGranted == loc.PermissionStatus.DENIED) {
      permissionGranted = await locationService.requestPermission();
      if (permissionGranted != loc.PermissionStatus.GRANTED) {
        return false;
      }
    }
    return true; //ok, can use location plugin
  }
}
