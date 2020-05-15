import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_locator/background_locator.dart';
import 'package:background_locator/location_dto.dart';
import 'package:background_locator/location_settings.dart';

import '../backends/gps_pref_result.dart';
import '../boundaries/sensor_data_provider.dart';
import '../models.dart' show LocationData;

/// Provides [LocationData] using a background Isolate (iOS) or a
/// foreground service (Android).
class LocationProviderBackground implements SensorDataProvider<LocationData> {
  GPSPrefResult _gpsAuth;

  LocationProviderBackground(this._gpsAuth) {
    setupStream();

    assert(_gpsAuth != null);
    _gpsAuth.addListener(_gpsAuthChanged);
    _gpsAuthChanged(); // Trigger the logic at least once.
  }

  void _gpsAuthChanged() {
    isolateMayStart = _gpsAuth.value == true;

    if (_gpsAuth.value == true && _controller.hasListener) {
      _startBackgroundIsolate();
    } else { /* false or null */
      _stopBackgroundIsolate();
    }
  }

  @override
  Stream<LocationData> get stream => _controller.stream;
}


// -----------------------------------------------------------------------------

final _controller = StreamController<LocationData>.broadcast(
    onListen: () {
      print('[Isolate] controller.onListen() (mayStart: $isolateMayStart)');
      if (isolateMayStart)
        _startBackgroundIsolate();
    },
    onCancel: () {
      _stopBackgroundIsolate();
    }
);
const String _isolateName = "LocatorIsolate";
final _receivePort = ReceivePort();
bool isolateMayStart = false;
bool _isSetup = false;
bool _isStarted = false;

void setupStream() async {
  if (!_isSetup) {
    print('[LocationProviderBackground] setup()');
    _isSetup = true;
    await BackgroundLocator.initialize();
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, _isolateName);
    _receivePort.listen((d) => _controller.add(d as LocationData));
  }
}

Future<void> _startBackgroundIsolate() async {
  if (!_isStarted) {
    print('[LocationProviderBackground] startIsolate()');
    _isStarted = true;
    await BackgroundLocator.registerLocationUpdate(
      callback,
      androidNotificationCallback: notificationCallback,
      settings: LocationSettings(
          notificationTitle: "Collecte des données en cours...",
          notificationMsg: "Data Collection enregistre les données de votre déplacement",
          wakeLockTime: 24 * 60,
          autoStop: false,
          interval: 1
      ),
    );
  } else {
    print('[LocationProviderBackground] startIsolate() skipped because already started');
  }
}

Future<void> _stopBackgroundIsolate() async {
  if (_isStarted) {
    print('[LocationProviderBackground] stopIsolate()');
    _isStarted = false;
    await BackgroundLocator.unRegisterLocationUpdate();
  } else {
    print('[LocationProviderBackground] stopIsolate() skipped because not started.');
  }
}

void callback(LocationDto locationDto) async {
  print('[Isolate] $locationDto');
  final SendPort send = IsolateNameServer.lookupPortByName(_isolateName);
  var loc = LocationData(
      millisecondsSinceEpoch: locationDto.time.toInt(),
      latitude: locationDto.latitude,
      longitude: locationDto.longitude,
      altitude: locationDto.altitude,
      accuracy: locationDto.accuracy,
      speed: locationDto.speed,
      speedAccuracy: locationDto.speedAccuracy,
      heading: locationDto.heading
  );
  send?.send(loc);
}

void notificationCallback() {
  print('User clicked on the notification');
}