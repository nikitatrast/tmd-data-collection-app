import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tmd/backends/gps_status.dart';

import 'backends/uploaded_trips_backend.dart';
import 'backends/network_manager.dart';
import 'backends/trip_recorder_backend.dart';
import 'backends/gps_pref_result.dart';
import 'backends/explorer_backend.dart';
import 'backends/trip_recorder_backend_android.dart';
import 'backends/upload_manager.dart';

import 'boundaries/acceleration_provider.dart';
import 'boundaries/battery.dart';
import 'boundaries/data_store.dart';
import 'boundaries/gyroscope_provider.dart';
import 'boundaries/location_permission.dart';
import 'boundaries/location_provider_background.dart';
import 'boundaries/preferences_provider.dart';
import 'boundaries/sensor_data_provider.dart';
import 'boundaries/uploader.dart';

import 'models.dart' show Sensor, enabledModes;

import 'pages/geofence_page.dart';
import 'pages/trip_selector_page.dart';
import 'pages/settings_page.dart';
import 'pages/explorer_page.dart';
import 'pages/trip_recorder_page.dart';
import 'pages/info_page.dart';
import 'pages/register_page.dart';
import 'pages/consent_page.dart';
import 'pages/uploaded_trips_page.dart';

import 'widgets/modes_view.dart' show ModeRoute;

/// Creates the stores, initializes the backends then runs the UI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  var prefs = PreferencesProvider();
  var uploader = Uploader(prefs.uidStore);
  var network = NetworkManager(prefs.cellularNetwork);
  var battery = BatteryNotifier();
  var gpsPrefRes = GPSPrefResult(prefs.gpsAuthNotifier, battery);
  var gpsSysPref = LocationPermission();
  var gpsStatus = GpsStatusNotifierImpl(gpsPrefRes, gpsSysPref);

  var printGpsStatus = () {
    print('[main.dart] gpsPrefRes = ${gpsPrefRes.value}');
    print('[main.dart] gpsSysPref = ${gpsSysPref.status.value}');
    print('[main.dart] gpsStatus = ${gpsStatus.value}');
  };
  gpsPrefRes.addListener(printGpsStatus);
  gpsSysPref.status.addListener(printGpsStatus);
  gpsStatus.addListener(printGpsStatus);

  var storage = DataStore.instance;
  var uploadManager = UploadManager(storage, network.status, uploader);
  storage.onNewTrip = uploadManager.scheduleUpload;
  storage.beforeTripDeletion.add(uploadManager.beforeTripDeletion);
  storage.onGeoFencesChanged = uploadManager.scheduleGeoFenceUpload;

  var makeProvidersForIos = () => <Sensor, SensorDataProvider>{
    Sensor.gps: LocationProviderBackground(gpsPrefRes),
    Sensor.accelerometer: AccelerationProvider(),
    Sensor.gyroscope: GyroscopeProvider(),
  };

  uploadManager.start();

  // Note: provide every piece of logic to the UI using a Provider<T>.

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: gpsPrefRes),
      ChangeNotifierProvider.value(value: prefs.cellularNetwork),
      ChangeNotifierProvider.value(value: prefs.gpsAuthNotifier),
      ChangeNotifierProvider.value(value: uploadManager.syncStatus),
      ChangeNotifierProvider.value(value: gpsStatus as GpsStatusNotifier),
      Provider<UidStore>.value(value: prefs.uidStore),
      Provider<ExplorerBackend>.value(
          value: ExplorerBackendImpl(storage, uploadManager)),
      Provider<UploadedTripsBackend>.value(
          value: UploadedTripsBackendImpl(uploader),
      ),
      Provider<TripRecorderBackend>(
          // On iOS, we need to have the GPS running to be able to collect
          // data in background. But on android, we can use a foreground service
          // to collect data in background even when GPS is off.
          // Hence the custom implementation for android.
          create: (_) => (Platform.isIOS)
              ? TripRecorderBackendImpl(gpsStatus, storage, makeProvidersForIos())
              : TripRecorderBackendAndroidImpl(gpsStatus, storage.onNewTrip)),
      Provider<GeoFenceStore>.value(value: storage),
    ],
    child: MyApp(),
  ));
}

/// The app's UI.
///
/// Uses Consumer<T> to fetch backends and stores.
class MyApp extends StatelessWidget {
  MyApp() {
    initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
    print('[App] build');
    /*
    For consistency: in this tree, only instantiate widgets and Consumer<T>,
    Data Providers or backends should by instantiated in main() through
    Provider<T> mechanism.
     */
    return MaterialApp(
        title: 'TMD data collection',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/initial',
        routes: {
          '/initial': _initialPage,
          '/selection': _tripSelectorPage,
          for (var mode in enabledModes)
            mode.route: (context) => _tripRecorderPage(context, mode),
          '/settings': _settingsPage,
          '/data-explorer': _dataExplorerPage,
          '/uploaded-trips': _uploadedTripsPage,
          '/info': _infoPage,
          '/geofences': _geoFencesPage,
          '/consent': (context) => ConsentPage(),
        });
  }

  Widget _initialPage(context) => Consumer<UidStore>(
      builder: (context, store, _) => FutureBuilder(
          future: store.getLocalUid(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _loadingPage(context);
            } else if (snapshot.data == null) {
              return _registerPage(context, store);
            } else {
              return _tripSelectorPage(context);
            }
          }));

  Widget _registerPage(context, store) => RegisterPage(store, () {
        Navigator.of(context).pushReplacementNamed('/selection');
      });

  Widget _loadingPage(context) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Container(
            width: 100, height: 100, child: CircularProgressIndicator()),
      ));

  Widget _tripSelectorPage(context) => TripSelectorPage(
        modes: enabledModes,
        modeSelected: (m) {
          Navigator.of(context).pushReplacementNamed(m.route);
        },
        settingsAction: () {
          Navigator.of(context).pushNamed('/settings');
        },
      );

  Widget _tripRecorderPage(context, mode) => Consumer<TripRecorderBackend>(
        builder: (context, backend, _) => TripRecorderPage(
          mode: mode,
          backend: backend,
          onExit: () =>
              Navigator.of(context).pushReplacementNamed('/selection'),
        ),
      );

  Widget _settingsPage(context) => SettingsPage(
        () => Navigator.of(context).pushNamed('/data-explorer'),
        () => Navigator.of(context).pushNamed('/uploaded-trips'),
        () => Navigator.of(context).pushNamed('/geofences'),
        () => Navigator.of(context).pushNamed('/consent'),
      );

  Widget _dataExplorerPage(context) => Consumer<ExplorerBackend>(
      builder: (context, backend, _) => ExplorerPage(backend,
          (item) => Navigator.of(context).pushNamed('/info', arguments: item)));

  Widget _infoPage(context) => Consumer<ExplorerBackend>(
      builder: (context, backend, _) =>
          InfoPage(backend, ModalRoute.of(context).settings.arguments));

  Widget _geoFencesPage(c) => Consumer<GeoFenceStore>(
      builder: (context, store, _) => GeoFencePage(store));

  Widget _uploadedTripsPage(context) => Consumer<UploadedTripsBackend>(
      builder: (context, backend, _) => UploadedTripsPage(backend)
  );

}
