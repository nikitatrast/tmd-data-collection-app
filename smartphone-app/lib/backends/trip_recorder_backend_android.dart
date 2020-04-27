import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/cupertino.dart';

import '../backends/gps_auth.dart';
import '../boundaries/acceleration_provider.dart';
import '../boundaries/data_store.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show Mode, Sensor, SensorValue, Trip, LocationData;
import '../pages/trip_recorder_page.dart' show TripRecorderBackend;
import '../boundaries/location_provider.dart' show LocationProvider;

import 'package:foreground_service/foreground_service.dart';

/// Implementation of [TripRecorderBackend] to allow background processing
/// on Android.
///
/// The implementation records sensor data using an Android foreground service.
///
class TripRecorderBackendAndroidImpl implements TripRecorderBackend {

  /// Whether use of [Sensor] is allowed.
  final _isSensorEnabled = Map<Sensor, ValueNotifier<bool>>();

  /// Callbacks to request sensor's permission before recording
  final _requestPermission = Map<Sensor, Future<void> Function()>();

  /// Functions listening to [_isSensorEnabled] values.
  final _authListeners = Map<Sensor, void Function()>();

  /// File in which sensor data is recorded.
  final _recordingFiles = Map<Sensor, RecordingFile>();

  /// Store where the newly recorded trip will be persisted.
  DataStore _storage;

  /// The newly recorded trip.
  Trip _trip;

  /// Completes when [IsolateMessageType.allRecordingsFinished]
  /// message is received.
  Completer<DateTime> _tripEnd;

  /// Used to provide a [Stream<LocationData>] to the UI.
  StreamController<LocationData> _outputStream = StreamController.broadcast();


  TripRecorderBackendAndroidImpl(GPSAuth gpsAuth, this._storage) {
    // By default, all sensors are enabled and no permission required.
    for (var sensor in Sensor.values) {
      _isSensorEnabled[sensor] = ValueNotifier(true);
      _requestPermission[sensor] = () async {};
    }
    // Special case for the GPS.
    _isSensorEnabled[Sensor.gps] = gpsAuth;
    _requestPermission[Sensor.gps] = LocationProvider().requestPermission;
  }

  /// Initializes member variables, starts the foreground service and
  /// sensor data recording.
  @override
  Future<bool> start(Mode tripMode) async {
    await Isolate.start();
    await ForegroundService.setupIsolateCommunication(_onIsolateMessage);

    _trip = Trip();
    _trip.mode = tripMode;
    _trip.start = DateTime.now();
    _tripEnd = Completer();

    await ForegroundService.isBackgroundIsolateSetupComplete();
    return true;
  }

  /// Function to respond to a message from the foreground service Isolate.
  ///
  /// Messages ordering between the main thread and foreground service is:
  /// 1. <-- [IsolateMessageType.isolateReady]
  /// 2. --> [MainMessageType.startRecordingSensor]
  /// 3. <-- [IsolateMessageType.newLocation]
  /// 4. <-- [IsolateMessageType.newLocation]
  /// 5. <-- ...
  /// 6. --> [MainMessageType.stopRecordingSensor]
  /// 7. <-- [IsolateMessageType.recordingEnded].
  /// 8. (eventually repeat steps 2. to 7.)
  /// 9. --> [MainMessageType.terminate]
  /// 10. <-- [IsolateMessageType.allRecordingsFinished]
  ///
  void _onIsolateMessage(dynamic message) async {
    var m = Messages.parseIsolateMessage(message);
    print('[TripRecored] message received: ${m.type}');

    switch (m.type) {
      case IsolateMessageType.newLocation:
        _outputStream.add(LocationData.parse(m.data));
        break;

      case IsolateMessageType.isolateReady:
        for (var sensor in _isSensorEnabled.keys) {
          final listener = () => _authChanged(sensor);
          _authListeners[sensor] = listener;
          _isSensorEnabled[sensor].addListener(listener);
          listener(); // trigger the logic at least once now
        }
        break;

      case IsolateMessageType.recordingEnded:
        var sensor = SensorValue.fromValue(m.data);
        if (!_isRecording(sensor)) {
          print('[TripRecorder] recordingEnded for $sensor received'
                ' but was not recording !!');
        } else {
          print('[TripRecorder] recordingEnded for $sensor, (${m.data})');
        }
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
    var enabled = _isSensorEnabled[sensor]?.value;

    print('[TripRecorder] _authChanged($sensor): $enabled,'
          ' recording: ${_isRecording(sensor)}');

    if (enabled == null) {
      // Nothing to do.
      return;
    }

    if (enabled && !_isRecording(sensor)) {
      // Start recording sensor's data.

      // Permissions must be requested in main thread, not isolate.
      await _requestPermission[sensor]();

      var file = await _storage.openRecordingFile(_trip, sensor);
      _recordingFiles[sensor] = file;
      Messages.sendToIsolate(MainMessageType.startRecordingSensor, {
        'sensor': sensor.value,
        'filepath': file.path,
      });

    } else {
      // Stop recording sensor's data.
      Messages.sendToIsolate(MainMessageType.stopRecordingSensor, {
        'sensor': sensor.value
      });
    }
  }

  bool _isRecording(Sensor sensor) {
    return _recordingFiles.keys.contains(sensor);
  }

  /// Signals to stop recording sensors' data.
  Future<void> stop() async {
    for (var sensor in _isSensorEnabled.keys) {
      _isSensorEnabled[sensor].removeListener(_authListeners[sensor]);
      _authListeners[sensor] = null;
    }

    await ForegroundService.foregroundServiceIsStarted();
    Messages.sendToIsolate(MainMessageType.terminate);

    // [_tripEnd] is completed when Isolate answers back.
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
    // [save()] or [cancel()] should be called before [dispose()]
    // and therefore, [_tripEnd] should be completed.
    // To make sure the Isolate stops properly,
    // double check that [_tripEnd] is completed here.
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

  /// Starts the foreground service.
  static Future<void> start() async {
    if (!(await ForegroundService.foregroundServiceIsStarted())) {
      await ForegroundService.setServiceFunctionAsync(false);
      await setupForegroundServiceNotification();
      await ForegroundService.startForegroundService(Isolate.run);
      await ForegroundService.getWakeLock();
    }
  }


  /// Service function running in the foreground service.
  ///
  /// See [TripRecorderBackendAndroidImpl._onIsolateMessage()].
  static Future<void> run() async {
    print('[Isolate] --- started --- ');
    await ForegroundService.notification.setText('Trip started at (${DateTime.now()}');

    /// Completes when [MainMessageType.terminate] is received.
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
            /// Completes when [MainMessageType.stopRecordingSensor] is received.
            isRecording[sensor] = Completer();

            runningOperations.add(recordSensorData(
                sensor,
                providers[sensor],
                filePath,
                isRecording[sensor]
            ));

            if (sensor == Sensor.gps) {
              // also forward location data to backend for display in UI
              var gpsStream = providers[Sensor.gps].stream;
              recorderStream(gpsStream, isRecording[sensor].future).listen(
                (position) {
                  var loc = position as LocationData;
                  Messages.sendToMain(
                      IsolateMessageType.newLocation, loc.serialize());
                }
              );
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
              // Signals. to stop recording this sensor's data.
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


  /// Streams data of [provider] into [filePath], completes when streaming ends.
  static Future<void> recordSensorData(
      Sensor s,
      SensorDataProvider provider,
      String filePath,
      Completer isRecording
      ) async {
    var file = File(filePath);
    var sink = file.openWrite(mode: FileMode.writeOnlyAppend);

    // [recorderStream()] stops streaming as soon as [isRecording] completes.
    var sourceStream = recorderStream(
        provider.stream, isRecording.future);

    Stream<String> strings = sourceStream.map((x) => x.serialize());
    strings = strings.map((str) => '${str.trim()}\n'); // one per line
    var sinkIsClosed = Completer();
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
      sinkIsClosed.complete();
    }
    );

    /// Waits until [operation] is done.
    await sinkIsClosed.future;
    Messages.sendToMain(IsolateMessageType.recordingEnded, s.value);
  }

  /// Wraps [input] into a [Stream] that closes as soon as
  /// [signal] is completed.
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

/// Message sent from the foreground service to the main Isolate.
class IsolateMessage {
  IsolateMessageType type;
  String data;
}

/// Message sent from main Isolate to the foreground service.
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