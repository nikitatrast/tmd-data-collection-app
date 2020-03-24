import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:location/location.dart' as loc;
import 'package:sensors/sensors.dart';
import 'package:path_provider/path_provider.dart';

import '../models/modes.dart';
import '../models/sensor_event.dart';
import '../models/location.dart';

import '../widgets/trip_recorder.dart' show DataRecorder;

class SensorDataRecorder implements DataRecorder {
  ValueNotifier<bool> gpsEnabled;
  loc.Location locationService = loc.Location();
  StreamSubscription<loc.LocationData> inputLocationStream;
  StreamController<Location> outputLocationStream;

  List<loc.LocationData> locationEvents = [];
  List<Function> locationListeners = [];

  StreamSubscription<AccelerometerEvent> accelerationStream;
  List<SensorEvent<AccelerometerEvent>> accelerationEvents = [];
  
  SensorDataRecorder({this.gpsEnabled});

  Future<bool> get gpsAllowed async {
    // busy wait in case the ValueNotifier is not yet ready
    for (int i = 0; i < 10*1000*1000; ++i) {
      if (gpsEnabled.value != null)
        break;
      else
        await Future.delayed(Duration(microseconds: 1));
    }
    return gpsEnabled.value ?? false;
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
    return gpsAllowed;
  }

  @override
  void startRecording() async {
    print('[SensorRecorder] startRecording');
    accelerationStream = accelerometerEvents.listen(onNewAcceleration);

    outputLocationStream = StreamController<Location>();
    if (await locationAvailable()) {
      inputLocationStream = locationService.onLocationChanged().listen(onNewLocation);
    }
  }

  @override
  void pauseRecording() {
    print('[SensorRecorder] pauseRecording');
    inputLocationStream?.pause();
    accelerationStream?.pause();
  }

  @override
  void stopRecording() {
    print('[SensorRecorder] stopRecording');
    accelerationStream?.cancel();
    inputLocationStream?.cancel();
    outputLocationStream.close();
  }

  @override
  Stream<Location> locationStream() {
    return outputLocationStream.stream;
  }

  void onNewAcceleration(AccelerometerEvent event) {
    accelerationEvents.add(SensorEvent(DateTime.now(), event));
  }

  void onNewLocation(loc.LocationData loc) {
    locationEvents.add(loc);
    outputLocationStream.add(
        Location(loc.latitude, loc.longitude, loc.altitude)
    );
  }

  @override
  Future<bool> persistData(Modes travelMode) async {
    print('[SensorRecorder] persistData for ${travelMode.text}');
    var timestamp = new DateTime.now().millisecondsSinceEpoch;

    var accelFile = getFile(travelMode, 'accelerometer', timestamp);
    accelerationEvents.fold(accelFile, (file, e) async {
      return (await file).writeAsString(
        '${e.time.millisecondsSinceEpoch}'
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
