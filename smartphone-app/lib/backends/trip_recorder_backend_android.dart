import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:foreground_service/foreground_service.dart';

import '../backends/gps_pref_result.dart';
import '../backends/trip_recorder_backend.dart';
import '../boundaries/acceleration_provider.dart';
import '../boundaries/data_store.dart';
import '../boundaries/gyroscope_provider.dart';
import '../boundaries/location_provider.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart';
import '../pages/trip_recorder_page.dart';

/// An implementation of [TripRecorderBackend] that uses a foreground service
/// on Android to allow background data collection.
///
/// Implementation strategy:
/// - The main isolate calls methods on this class.
/// - The method calls are forwarded to the foreground service via messaging.
/// - Another instance of a [TripRecorderBackend] in the foreground service
///   implements the method calls.
///
class TripRecorderBackendAndroidImpl implements TripRecorderBackend {
  /// Whether usage of the GPS is allowed.
  GPSPrefResult _gpsAuth;

  /// Completes when save() method completes in the foreground service.
  Completer<bool> saveResponse;

  /// Completes when start() method complete in the foreground service.
  Completer<bool> startResponse;

  /// Whether foreground service's communication is setup.
  Completer _isCommunicationSetup;

  /// Controller to output [LocationData] for the UI to consume.
  var outputController = StreamController<LocationData>.broadcast();

  /// Called when a new trip is saved.
  final void Function(Trip) onNewTrip;

  TripRecorderBackendAndroidImpl(this._gpsAuth, this.onNewTrip) {
    _gpsAuth.addListener(_gpsAuthChanged);
  }

  @override
  void cancel() async {
    _sendToIsolate({'type': 'TripRecorderBackend.cancel'});
  }

  @override
  void dispose() async {
    _sendToIsolate({'type': 'TripRecorderBackend.dispose'});
  }

  @override
  Stream<LocationData> locationStream() {
    return outputController.stream;
  }

  @override
  Future<bool> save() async {
    saveResponse = Completer();
    _sendToIsolate({'type': 'TripRecorderBackend.save'});
    return saveResponse.future;
  }

  @override
  Future<bool> start(Mode tripMode) async {
    startResponse = Completer();
    _isCommunicationSetup = Completer();

    await Isolate.start();
    await ForegroundService.setupIsolateCommunication(_onIsolateMessage);

    _gpsAuthChanged();
    _sendToIsolate({
      'type': 'TripRecorderBackend.start',
      'mode': tripMode.value,
    });

    return startResponse.future;
  }

  void _gpsAuthChanged() async {
    _sendToIsolate({
      'type': 'GPSPrefResult.value',
      'value': _gpsAuth.value,
    });
  }

  void _onIsolateMessage(dynamic data) {
    print('[MainIsolate] Message received: $data');
    var message = data as Map;

    if (message['type'] == 'LocationData') {
      outputController.add(LocationData.parse(message['data']));
    } else if (message['type'] == 'ForegroundServiceReady') {
      _isCommunicationSetup.complete();
    } else if (message['type'] == 'TripRecorderBackend.start') {
      startResponse.complete(message['value']);
    } else if (message['type'] == 'TripRecorderBackend.save') {
      saveResponse.complete(message['value']);
    } else if (message['type'] == 'TripRecorderStorage.onNewTrip') {
      var trip = Trip.parse(message['trip']);
      onNewTrip(trip);
    } else if (message['type'] == 'LocationProvider.requestPermission') {
      LocationProvider(_gpsAuth)
          .requestPermission()
          .then((value) => _sendToIsolate({
                'type': 'LocationProvider.requestPermission',
                'value': value,
                'key': message['key'],
              }));
    }
  }

  Future<void> _sendToIsolate(Map data) async {
    await _isCommunicationSetup.future;
    ForegroundService.sendToPort(data);
  }
}

/// Code to run in the Foreground Service's Isolate.
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

  /// Create the foreground service's notification in notification center.
  static Future<void> setupForegroundServiceNotification() async {
    var notification = ForegroundService.notification;
    await notification.startEditMode();
    await notification.setTitle("Data Collection App");
    await notification.setText("");
    await notification.finishEditMode();
  }

  /// Service function to be run by the foreground service.
  static Future<void> run() async {
    print('[Isolate] --- started --- ');

    var now = DateTime.now();
    ForegroundService.notification.setText('Trip recording started ($now)');

    var gpsPrefRes = IsolateGPSPrefResult(false);

    var storage = DataStore.instance;
    storage.onNewTrip = (Trip t) {
      ForegroundService.sendToPort({
        'type': 'TripRecorderStorage.onNewTrip',
        'trip': t.serialize(),
      });
    };

    var locationProvider = IsolateLocationProvider(gpsPrefRes);
    var providers = <Sensor, SensorDataProvider>{
      Sensor.gps: locationProvider,
      Sensor.accelerometer: AccelerationProvider(),
      Sensor.gyroscope: GyroscopeProvider(),
    };

    TripRecorderBackendImpl.logPrefix = "Isolate:TripRecorderBackend";
    var stopped = Completer();
    var backend = IsolateTripRecorderBackend(gpsPrefRes, storage, providers);
    backend.onDispose = () => stopped.complete();

    // Callback to process message, where most of the stuff happens.
    await ForegroundService.setupIsolateCommunication(
        (data) => Isolate.onMessageReceived(
              data,
              [backend, locationProvider, gpsPrefRes]
            ));

    // Tell the main isolate that we are ready to process messages.
    ForegroundService.sendToPort({'type': 'ForegroundServiceReady'});

    var subscription = backend.locationStream().listen((locationData) {
      ForegroundService.sendToPort({
        'type': 'LocationData',
        'data': locationData.serialize(),
      });
    });

    /// Keeps the foreground service running until [stopped] completes.
    await stopped.future;
    subscription.cancel();
    print('[Isolate] --- stopped --- ');
    await ForegroundService.stopForegroundService();
  }

  /// Callback to handle message received from the main Isolate.
  static void onMessageReceived(
    dynamic data,
    List<MessageHandler> handlers
  ) async
  {
    print('[Isolate] Message received: $data');
    var message = data as Map;

    for (var handler in handlers) {
      if (await handler.handleMessage(message)) {
        // Ok, message was for handler, we're done.
        return;
      }
    }

    print('[Isolate] unknown message:');
    print('-----------------------------------');
    print(message);
    print('-----------------------------------');
  }
}

abstract class MessageHandler {
  /// Translates a message from main Isolate to a method call on this instance.
  ///
  /// Returns `true` if have been translated successfully,
  /// returns `false` if the message should be propagated to another handler.
  Future<bool> handleMessage(Map message);
}

/// Proxy for [TripRecorderBackendImpl] which translates messages received
/// from the main isolate into method calls on this instance.
class IsolateTripRecorderBackend extends TripRecorderBackendImpl
    with MessageHandler {

  /// Callback to notify that [dispose()] was called on this backend.
  Function onDispose = () {};

  IsolateTripRecorderBackend(GPSPrefResult gpsPrefRes, TripRecorderStorage storage,
      Map<Sensor, SensorDataProvider> providers)
      : super(gpsPrefRes, storage, providers);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['type'] == 'TripRecorderBackend.cancel') {
      cancel();
    } else if (message['type'] == 'TripRecorderBackend.dispose') {
      dispose();
      /// [stopped] will terminate the foreground service.
      //stopped.complete(true);
    } else if (message['type'] == 'TripRecorderBackend.save') {
      save().then((value) => ForegroundService.sendToPort({
        'type': 'TripRecorderBackend.save',
        'value': value,
      }));
    } else if (message['type'] == 'TripRecorderBackend.start') {
      Mode mode = ModeValue.fromValue(message['mode']);
      start(mode).then((value) => ForegroundService.sendToPort({
        'type': 'TripRecorderBackend.start',
        'value': value,
      }));
    } else {
      return false;
    }
    return true;
  }
}

/// A proxy for [GPSPrefResult] that can be used to forward the GPSPrefResult value
/// from the main isolate to the foreground service's isolate.
class IsolateGPSPrefResult extends ValueNotifier<bool>
    with MessageHandler
    implements GPSPrefResult {
  IsolateGPSPrefResult(bool value) : super(value);

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['type'] == 'GPSPrefResult.value') {
      super.value = message['value'];
      return true;
    }
    return false;
  }
}

/// [requestPermission] must be called in the main isolate,
/// this implementation of [LocationProvider] forwards the method call
/// to the main isolate via a message.
class IsolateLocationProvider extends LocationProvider with MessageHandler {
  IsolateLocationProvider(GPSPrefResult gpsPrefRes) : super(gpsPrefRes);

  Map<int, Completer<bool>> _permissions = Map();

  @override
  Future<bool> requestPermission() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    _permissions[now] = Completer<bool>();
    ForegroundService.sendToPort({
      'type': 'LocationProvider.requestPermission',
      'key': now,
    });
    return _permissions[now].future;
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['type'] == 'LocationProvider.requestPermission') {
      _permissions[message['key']].complete(message['value']);
      return true;
    }
    return false;
  }
}
