import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:foreground_service/foreground_service.dart';

import '../backends/gps_status.dart';
import '../backends/trip_recorder_backend.dart';
import '../boundaries/acceleration_provider.dart';
import '../boundaries/data_store.dart';
import '../boundaries/gyroscope_provider.dart';
import '../boundaries/location_provider.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart';
import '../pages/trip_recorder_page.dart';
import '../backends/message_handler.dart';

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
  GpsStatusProvider _gpsAuth;

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

  TripRecorderBackendAndroidImpl(this._gpsAuth, this.onNewTrip);

  @override
  void cancel() async {
    _sendToIsolate({'method': 'TripRecorderBackend.cancel'});
  }

  @override
  void dispose() async {
    _gpsAuth.status.removeListener(_gpsAuth.sendValueToPort);
    _sendToIsolate({'method': 'TripRecorderBackend.dispose'});
  }

  @override
  Stream<LocationData> locationStream() {
    return outputController.stream;
  }

  @override
  Future<bool> save() async {
    saveResponse = Completer();
    _sendToIsolate({'method': 'TripRecorderBackend.save'});
    return saveResponse.future;
  }

  @override
  Future<bool> start(Mode tripMode) async {
    startResponse = Completer();
    _isCommunicationSetup = Completer();

    await Isolate.start();
    await ForegroundService.setupIsolateCommunication(_onIsolateMessage);

    _sendToIsolate({
      'method': 'TripRecorderBackend.start',
      'mode': tripMode.value,
    }).then((_) {
      _gpsAuth.status.addListener(_gpsAuth.sendValueToPort);
      _gpsAuth.sendValueToPort(); // send initial value
    });

    return startResponse.future;
  }

  void _onIsolateMessage(dynamic data) async {
    print('[MainIsolate] Message received: $data');
    var message = data as Map;

    if (message['method'] == 'LocationData') {
      outputController.add(LocationData.parse(message['data']));
    } else if (message['method'] == 'ForegroundServiceReady') {
      _isCommunicationSetup.complete();
    } else if (message['method'] == 'TripRecorderBackend.start') {
      startResponse.complete(message['value']);
    } else if (message['method'] == 'TripRecorderBackend.save') {
      saveResponse.complete(message['value']);
    } else if (message['method'] == 'TripRecorderStorage.onNewTrip') {
      var trip = Trip.parse(message['trip']);
      onNewTrip(trip);
    } else if (await _gpsAuth.handleMessage(message)) {
      print('[MainIsolate] message handled by _gpsAuth');
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

    var gpsStatusProvider = IsolateGpsStatusProvider();

    var storage = DataStore.instance;
    storage.onNewTrip = (Trip t) {
      ForegroundService.sendToPort({
        'method': 'TripRecorderStorage.onNewTrip',
        'trip': t.serialize(),
      });
    };

    var locationProvider = LocationProvider(gpsStatusProvider);
    var providers = <Sensor, SensorDataProvider>{
      Sensor.gps: locationProvider,
      Sensor.accelerometer: AccelerationProvider(),
      Sensor.gyroscope: GyroscopeProvider(),
    };

    TripRecorderBackendImpl.logPrefix = "Isolate:TripRecorderBackend";
    var stopped = Completer();
    var backend = IsolateTripRecorderBackend(gpsStatusProvider, storage, providers);
    backend.onDispose = () => stopped.complete();

    // Callback to process message, where most of the stuff happens.
    await ForegroundService.setupIsolateCommunication(
        (data) => Isolate.onMessageReceived(
              data,
              [backend, gpsStatusProvider]
            ));

    // Tell the main isolate that we are ready to process messages.
    ForegroundService.sendToPort({'method': 'ForegroundServiceReady'});

    var subscription = backend.locationStream().listen((locationData) {
      ForegroundService.sendToPort({
        'method': 'LocationData',
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

/// Proxy for [TripRecorderBackendImpl] which translates messages received
/// from the main isolate into method calls on this instance.
class IsolateTripRecorderBackend extends TripRecorderBackendImpl
    with MessageHandler {

  /// Callback to notify that [dispose()] was called on this backend.
  Function onDispose = () {};

  IsolateTripRecorderBackend(GpsStatusProvider provider, TripRecorderStorage storage,
      Map<Sensor, SensorDataProvider> providers)
      : super(provider, storage, providers);

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['method'] == 'TripRecorderBackend.cancel') {
      cancel();
    } else if (message['method'] == 'TripRecorderBackend.dispose') {
      dispose();
      /// [stopped] will terminate the foreground service.
      //stopped.complete(true);
    } else if (message['method'] == 'TripRecorderBackend.save') {
      save().then((value) => ForegroundService.sendToPort({
        'method': 'TripRecorderBackend.save',
        'value': value,
      }));
    } else if (message['method'] == 'TripRecorderBackend.start') {
      Mode mode = ModeValue.fromValue(message['mode']);
      start(mode).then((value) => ForegroundService.sendToPort({
        'method': 'TripRecorderBackend.start',
        'value': value,
      }));
    } else {
      return false;
    }
    return true;
  }
}