import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:foreground_service/foreground_service.dart';

import '../backends/message_handler.dart';
import '../backends/gps_status.dart';
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
class TripRecorderBackendAndroidImpl extends TripRecorderBackend {
  /// Whether usage of the GPS is allowed.
  ForwardingGpsStatusProvider _gpsStatus;

  /// Delegate for [_gpsStatus].
  GpsStatusNotifier _gpsStatusDelegate;

  /// Completes when save() method completes in the foreground service.
  Completer<bool> saveResponse;

  /// Completes when start() method complete in the foreground service.
  Completer<bool> startResponse;

  /// Whether foreground service's communication is setup.
  Completer _isCommunicationSetup;

  /// Used to answer the pings from background isolate.
  var _pingHandler = KeepAlivePing();

  /// Controller to output [LocationData] for the UI to consume.
  var outputController = StreamController<LocationData>.broadcast();

  /// Called when a new trip is saved.
  final void Function(Trip) onNewTrip;

  TripRecorderBackendAndroidImpl(this._gpsStatusDelegate, this.onNewTrip);

  @override
  void cancel() async {
    _sendToIsolate({'method': 'TripRecorderBackend.cancel'});
  }

  @override
  void dispose() async {
    _sendToIsolate({'method': 'TripRecorderBackend.dispose'});
    _gpsStatus.dispose(); // unregisters the wrapper's listeners.
    _pingHandler.stop();
  }

  @override
  Stream<LocationData> locationStream() {
    return outputController.stream;
  }

  @override
  void toForeground() {
    _gpsStatus.forceUpdate(requestAuth: false);
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
    _gpsStatus = ForwardingGpsStatusProvider(_gpsStatusDelegate, _sendToIsolate);

    await Isolate.start();
    await ForegroundService.setupIsolateCommunication(_onIsolateMessage);

    _sendToIsolate({
      'method': 'TripRecorderBackend.start',
      'mode': tripMode.value,
    });


    return startResponse.future;
  }

  void _onIsolateMessage(dynamic data) async {
    print('[MainIsolate] Message received: $data');
    var message = data as Map;

    var handlers = [_pingHandler, _gpsStatus];

    for (var h in handlers) {
      if (await h.handleMessage(message)) {
        return;
      }
    }

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
    }
  }

  Future<void> _sendToIsolate(Map data) async {
    await _isCommunicationSetup.future;
    ForegroundService.sendToPort(data);
  }
}

/// Proxy for [TripRecorderBackendImpl] which translates messages received
/// from the main isolate into method calls on this instance.
class IsolateTripRecorderBackend extends TripRecorderBackendImpl
    with MessageHandler {

  /// Callback to notify that [dispose()] was called on this backend.
  Function onDispose = () {};
  StreamSubscription subscription;
  
  IsolateTripRecorderBackend(GpsStatusNotifier provider, TripRecorderStorage storage,
      Map<Sensor, SensorDataProvider> providers)
      : super(provider, storage, providers);

  @override
  Future<bool> start(Mode m) async {
    bool ok = await super.start(m);
    if (ok) {
      subscription = locationStream().listen((locationData) {
          ForegroundService.sendToPort({
            'method': 'LocationData',
            'data': locationData.serialize(),
          });
      });
    } else {
      print('[IsolateTripRecorderBackend] Error: start() returned false');
    }
    return ok;

  }
  @override
  void dispose() {
    print('[IsolateTripRecorderBackend] dispose()');
    onDispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['method'] == 'TripRecorderBackend.cancel') {
      cancel();
    } else if (message['method'] == 'TripRecorderBackend.dispose') {
      dispose();
    } else if (message['method'] == 'TripRecorderBackend.save') {
      save().then((value) => ForegroundService.sendToPort({
        'method': 'TripRecorderBackend.save',
        'value': value,
      }));
    } else if (message['method'] == 'TripRecorderBackend.start') {
      Mode mode = ModeValue.fromValue(message['mode']);
      start(mode).then((value) {
        ForegroundService.sendToPort({
          'method': 'TripRecorderBackend.start',
          'value': value,
        });
      });
    } else {
      return false;
    }
    return true;
  }
}

//------------------------------------------------------------------------------


class ForwardingGpsStatusProvider implements GpsStatusNotifier, MessageHandler {
  GpsStatusNotifier delegate;
  List<void Function()> listeners = [];
  void Function(Map) sendMessage;

  ForwardingGpsStatusProvider(this.delegate, this.sendMessage) {
    sendValueToPort('constructor_call_main_isolate');
    delegate.addListener(sendValueToPort);
    delegate.addListener(_show);
  }

  void _show() {
    print('[ForwardingGpsStatus] listener called: ${delegate.value}');
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['method'] == 'GpsStatusNotifier.forceUpdate') {
      await this.forceUpdate(requestAuth: message['requestAuth']);
      sendMessage({
        'methodResult': 'GpsStatusNotifier.forceUpdate',
        'key': message['key'],
      });
      return true;

    } else if (message['method'] == 'GpsStatusNotifier.value') {
      sendValueToPort(message['key']);
      return true;
    }
    return false;
  }

  void sendValueToPort([String key]) {
    sendMessage({
      'methodResult': 'GpsStatusNotifier.value',
      'result': this.value.value,
      'key': key,
    });
  }

  @override
  void addListener(void Function() listener) {
    delegate.addListener(listener);
  }

  @override
  void dispose() {
    delegate.removeListener(sendValueToPort);
    delegate.removeListener(_show);
    print('[ForwardingGpsStatus] dispose() called');
    sendMessage({
      'method': 'GpsStatusNotifier.dispose',
    });
  }

  @override
  Future<void> forceUpdate({bool requestAuth}) {
    return delegate.forceUpdate(requestAuth: requestAuth);
  }

  @override
  bool get hasListeners => delegate.hasListeners;

  @override
  void removeListener(void Function() listener) {
    delegate.removeListener(listener);
  }

  @override
  void notifyListeners() {
    delegate.notifyListeners();
  }

  @override
  GpsStatus get value => delegate.value;
}


class IsolateGpsStatusProvider extends ValueNotifier<GpsStatus>
    implements GpsStatusNotifier, MessageHandler{

  Map<int, Completer> _responses = {};

  IsolateGpsStatusProvider() : super(GpsStatus.systemDisabled);

  @override
  Future<void> forceUpdate({bool requestAuth}) async {
    int key = DateTime.now().millisecondsSinceEpoch;
    _responses[key] = Completer();
    ForegroundService.sendToPort({
      'method': 'GpsStatusNotifier.forceUpdate',
      'requestAuth': requestAuth,
      'key': key,
    });
    await _responses[key].future;
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['methodResult'] == 'GpsStatusNotifier.value') {
      this.value = GpsStatusValue.fromValue(message['result']);
      _responses[message['key']]?.complete();
      return true;

    } else if (message['methodResult'] == 'GpsStatusNotifier.forceUpdate') {
      _responses[message['key']]?.complete();
      return true;
    } else if (message['method'] == 'GpsStatusNotifier.dispose') {
      dispose();
      return true;
    }
    return false;
  }
}

//------------------------------------------------------------------------------

class KeepAlivePing extends MessageHandler {
  RestartableTimer killTimer;
  Timer pingTimer;

  KeepAlivePing();

  void start({Function() killBackgroundIsolate}) async {
    if (!await ForegroundService.isBackgroundIsolate) {
      throw Exception('[KeepAlivePing] should be started in Background Isolate');
    }

    killTimer = RestartableTimer(Duration(seconds: 20), () {
      killBackgroundIsolate();
      pingTimer?.cancel();
    });

    pingTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      ForegroundService.sendToPort({'method': 'keepAlivePing'});
    });
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['method'] == 'keepAlivePing') {
      ForegroundService.sendToPort({
        'methodResult': 'keepAlivePing'
      });
      return true;
    } else if (message['methodResult'] == 'keepAlivePing') {
      killTimer?.reset();
      return true;
    }
    return false;
  }

  void stop() {
    killTimer?.cancel();
    pingTimer?.cancel();
  }
}

/// Code to run in the Foreground Service's Isolate.
class Isolate {
  /// Starts the foreground service.
  static Future<void> start() async {
    if (!(await ForegroundService.foregroundServiceIsStarted())) {
      await ForegroundService.setServiceFunctionAsync(false);
      await setupForegroundServiceNotification();
      await ForegroundService.startForegroundService(Isolate.run, true);
      //await ForegroundService.setContinueRunningAfterAppKilled(false);
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
    var stopped = Completer();
    ForegroundService.notification.setText('Trip recording started ($now)');
    TripRecorderBackendImpl.logPrefix = "Isolate:TripRecorderBackendImpl";
    GpsStatusNotifierImpl.logPrefix = "Isolate:GpsStatusNotifierImpl";
    
    print('[Isolate] initializing storage');
    var storage = DataStore.instance;
    storage.onNewTrip = (Trip t) {
      ForegroundService.sendToPort({
        'method': 'TripRecorderStorage.onNewTrip',
        'trip': t.serialize(),
      });
    };

    print('[Isolate] initializing GpsStatusProvider');
    var gpsStatusProvider = IsolateGpsStatusProvider();

    print('[Isolate] initializing Locatoin Provider');
    var locationProvider = LocationProvider(gpsStatusProvider);
    var providers = <Sensor, SensorDataProvider>{
      Sensor.gps: locationProvider,
      Sensor.accelerometer: AccelerationProvider(),
      Sensor.gyroscope: GyroscopeProvider(),
    };

    print('[Isolate] initializing TripRecorderBackend');
    var backend = IsolateTripRecorderBackend(gpsStatusProvider, storage, providers);
    backend.onDispose = () => stopped.complete();

    // We want to stop using the GPS as soon as the main Isolate dies
    // to avoid "GPS leak". For that, ping MainIsolate regularly.
    var ping = KeepAlivePing();
    
    // Callback to process message, where most of the stuff happens.
    print('[Isolate] waiting for setupIsolateCommunication');
    await ForegroundService.setupIsolateCommunication(
        (data) => Isolate.onMessageReceived(
            data,
            [ping, backend, gpsStatusProvider]
        )
    );
    print('[Isolate] setupIsolateCommunication done.');

    // Tell the main isolate that we are ready to process messages.
    print('[Isolate] sending ForegroundServiceReady signal');
    ForegroundService.sendToPort({'method': 'ForegroundServiceReady'});

    ping.start(killBackgroundIsolate: () {
      if (stopped.isCompleted) {
        print('[Isolate] Error: keepAlivePing still running after Isolate terminated! Calling dispose now.');
        ping.stop();
      } else {
        print('[Isolate] /!\\ Killing Isolate now.');
        backend.cancel();
        backend.dispose();
      }
    });

    /// Keeps the foreground service running until [stopped] completes.
    await stopped.future;
    ping.stop();
    
    // Note: objects should be disposed via the messaging system.
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
