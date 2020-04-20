import 'dart:async';
import 'package:accelerometertest/boundaries/acceleration_provider.dart';
import 'package:async/async.dart';

import 'dart:io';
import 'dart:convert';

import 'package:accelerometertest/backends/gps_auth.dart';
import 'package:flutter/cupertino.dart';

import '../boundaries/data_store.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show Mode, Sensor, SensorValue, Trip, LocationData;
import '../pages/trip_recorder_page.dart' show TripRecorderBackend;
import '../boundaries/location_provider.dart' show LocationProvider;

import 'package:foreground_service/foreground_service.dart';

class TripRecorderBackendAndroidImpl implements TripRecorderBackend {
  final _auth = Map<Sensor, ValueNotifier<bool>>();
  final _authListeners = Map<Sensor, void Function()>();
  final _recordingFiles = Map<Sensor, RecordingFile>();

  DataStore _storage;
  Trip _trip;
  Completer<DateTime> _tripEnd;
  StreamController<LocationData> _outputStream = StreamController.broadcast();


  TripRecorderBackendAndroidImpl(GPSAuth gpsAuth, this._storage) {
    for (var sensor in Sensor.values) {
      _auth[sensor] = (sensor == Sensor.gps) ? gpsAuth : ValueNotifier(true);
    }
  }

  @override
  Future<bool> start(Mode tripMode) async {
    await Isolate.start();
    await ForegroundService.setupIsolateCommunication(onIsolateMessage);

    _trip = Trip();
    _trip.mode = tripMode;
    _trip.start = DateTime.now();
    _tripEnd = Completer();

    await ForegroundService.isBackgroundIsolateSetupComplete();
    return true;
  }

  void onIsolateMessage(dynamic message) async {
    var m = Messages.parseIsolateMessage(message);
    print('[TripRecored] message received: ${m.type}');

    switch (m.type) {
      case IsolateMessageType.newLocation:
        _outputStream.add(LocationData.parse(m.data));
        break;

      case IsolateMessageType.isolateReady:
        for (var sensor in _auth.keys) {
          final listener = () => _authChanged(sensor);
          _authListeners[sensor] = listener;
          _auth[sensor].addListener(listener);
          listener(); // trigger the logic at least once
        }
        break;

      case IsolateMessageType.recordingEnded:
        var sensor = SensorValue.fromValue(m.data);
        print('[TripRecorder] recordingEnded for $sensor, (${m.data})');
        var file = _recordingFiles[sensor];
        _recordingFiles.remove(sensor);
        _storage.closeRecordingFile(file);
        break;

      case IsolateMessageType.allRecordingsFinished:
        if (!_tripEnd.isCompleted) {
          for (var file in _recordingFiles.values) {
            _storage.closeRecordingFile(file);
          }
          _recordingFiles.clear();
          _tripEnd.complete(DateTime.now());
        }
        break;
    }
  }

  Future<void> _authChanged(Sensor sensor) async {
    print('[TripRecorder] _authChanged($sensor): ${_auth[sensor]?.value}');

    if (_auth[sensor]?.value == true) {
      if (sensor == Sensor.gps) {
        // permission must be requested in main thread, not in Isolate
        await LocationProvider().requestPermission();
      }
      var file = await _storage.openRecordingFile(_trip, sensor);
      _recordingFiles[sensor] = file;
      Messages.sendToIsolate(MainMessageType.startRecordingSensor, {
        'sensor': sensor.value,
        'filepath': file.path,
      });

    } else if (_auth[sensor]?.value == false) {
      Messages.sendToIsolate(MainMessageType.stopRecordingSensor, {
        'sensor': sensor.value
      });
    }
    // nothing if _auth[sensor].value == null
  }

  Future<void> stop() async {
    for (var sensor in _auth.keys) {
      _auth[sensor].removeListener(_authListeners[sensor]);
      _authListeners[sensor] = null;
    }

    await ForegroundService.foregroundServiceIsStarted();
    Messages.sendToIsolate(MainMessageType.terminate);
    await _tripEnd.future;
  }

  @override
  Future<bool> save() async {
    print('[TripRecorder] save()');
    await stop();
    await _storage.save(_trip, await _tripEnd.future);
    return true;
  }

  @override
  Future<void> cancel() async {
    print('[TripRecorder] cancel()');
    await stop();
    await _storage.delete(_trip);
  }

  @override
  void dispose() {
    if (!_tripEnd.isCompleted) {
      stop();
      print('[TripRecorder] dispose(): not exited properly.');
    }
  }

  @override
  Stream<LocationData> locationStream() {
    return _outputStream.stream;
  }
}

Future<void> setupForegroundServiceNotification() async {
  var notification = ForegroundService.notification;
  await notification.startEditMode();
  await notification.setTitle("Data Collection App");
  await notification.setText("");
  await notification.finishEditMode();
}

class Isolate {
  static Future<void> start() async {
    if (!(await ForegroundService.foregroundServiceIsStarted())) {
      await ForegroundService.setServiceFunctionAsync(false);
      await setupForegroundServiceNotification();
      await ForegroundService.startForegroundService(Isolate.run);
      await ForegroundService.getWakeLock();
    }
  }

  static Future<void> run() async {
    print('[Isolate] --- started --- ');
    await ForegroundService.notification.setText('Trip started at (${DateTime.now()}');
    var isTerminated = Completer();

    Map<Sensor, SensorDataProvider> providers = {
      Sensor.gps: LocationProvider(),
      Sensor.accelerometer: AccelerationProvider()
    };

    var isRecording = Map<Sensor, Completer>();
    var runningOperations = <Future>[];
    bool terminateMessageReceived = false;

    await ForegroundService.setupIsolateCommunication((data) {
      var message = Messages.parseMainMessage(data);
      print('[Isolate] message received: ${message.type}');

      switch (message.type) {
        case MainMessageType.startRecordingSensor:
          var sensor = SensorValue.fromValue(message.data['sensor']);
          var filePath = message.data['filepath'];

          if (isRecording[sensor] != null && !isRecording[sensor].isCompleted)
            print('[Isolate] received startRecording($sensor) but already recording');
          else {
            isRecording[sensor] = Completer();
            runningOperations.add(recordSensorData(
                sensor,
                providers,
                filePath,
                isRecording[sensor]
            ));

            if (sensor == Sensor.gps) {
              // also forward location data to backend for display in UI
              var gpsStream = providers[Sensor.gps].stream;
              recorderStream(gpsStream, isRecording[sensor].future).listen((
                  position) {
                var loc = position as LocationData;
                Messages.sendToMain(
                    IsolateMessageType.newLocation, loc.serialize());
              });
            }
          }
          break;

        case MainMessageType.stopRecordingSensor:
          var sensor = SensorValue.fromValue(message.data['sensor']);
          var context = '[Isolate] received stopRecording($sensor)';

          if (isRecording[sensor] == null) {
            print('$context but was not recording');
          } else if (isRecording[sensor].isCompleted) {
            print('$context but already stopped');
          } else {
            isRecording[sensor].complete();
          }
          break;

        case MainMessageType.terminate:
          if (!terminateMessageReceived && !isTerminated.isCompleted) {
            terminateMessageReceived = true;

            for (var c in isRecording.values) {
              if (!c.isCompleted)
                c.complete();
            }
            Future.wait(runningOperations).then((_) {
              Messages.sendToMain(IsolateMessageType.allRecordingsFinished);
              isTerminated.complete();
            });
          }
          break;
      }
    });

    Messages.sendToMain(IsolateMessageType.isolateReady);
    await isTerminated.future;
    print('[Isolate] --- terminated --- ');
    await ForegroundService.stopForegroundService();
  }

  static Future<void> recordSensorData(Sensor s, providers, filePath, isRecording) async {
    var file = File(filePath);
    var provider = providers[s];
    var sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    var sourceStream = recorderStream(
        provider.stream, isRecording.future);
    Stream<String> strings = sourceStream.map((x) => x.serialize());
    strings = strings.map((str) => '${str.trim()}\n'); // one per line
    var c = Completer();
    var operation = sink
        .addStream(strings.transform(utf8.encoder))
        .then((v) async {
      sink.close();
      var length = await file.length();
      print('[Isolate] file closed for $s, length is $length');
      if (length == 0) {
        await file.delete();
        print('[Isolate] 0-length $s file deleted');
      }
      c.complete();
    }
    );
    await c.future;
    Messages.sendToMain(IsolateMessageType.recordingEnded, s.value);
  }

  static Stream<T> recorderStream<T>(Stream<T> input, Future signal) {
    // Provider won't close stream
    // So, this function wraps the Provider's streams and closes when
    // recording is done.
    Stream<T> done = signal.asStream().map((e) => null);
    return StreamGroup.merge<T>([done, input]).takeWhile((e) => e != null);
  }
}

enum IsolateMessageType {
  isolateReady, recordingEnded, allRecordingsFinished, newLocation
}

enum MainMessageType {
  startRecordingSensor, stopRecordingSensor, terminate
}

class IsolateMessage {
  IsolateMessageType type;
  String data;
}

class MainMessage {
  MainMessageType type;
  Map data;
}

class Messages {
  static void sendToIsolate(MainMessageType type, [Map data]) {
    ForegroundService.sendToPort({
      'type': type.toString(),
      'data': data
    });
  }

  static MainMessage parseMainMessage(dynamic receivedData) {
    var m = receivedData as Map;
    return MainMessage()
      ..type=_parseMainMessageType(m['type'])
      ..data=m['data'] as Map
    ;
  }

  static void sendToMain(IsolateMessageType type, [String data]) {
    ForegroundService.sendToPort({
      'type': type.toString(),
      'data': data
    });
  }

  static IsolateMessage parseIsolateMessage(dynamic receivedData) {
    var m = receivedData as Map;
    return IsolateMessage()
      ..type=_parseIsolateMessageType(m['type'])
      ..data=m['data'] as String
    ;
  }

  static IsolateMessageType _parseIsolateMessageType(String str) {
    for (var t in IsolateMessageType.values)
      if (t.toString() == str)
        return t;
    return null;
  }

  static MainMessageType _parseMainMessageType(String str) {
    for (var t in MainMessageType.values)
      if (t.toString() == str)
        return t;
    return null;
  }
}