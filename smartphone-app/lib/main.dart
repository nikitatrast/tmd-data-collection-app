import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'backends/network_manager.dart';
import 'boundaries/sensor_data_provider.dart';
import 'boundaries/acceleration_provider.dart';
import 'boundaries/battery.dart';
import 'boundaries/data_store.dart';
import 'boundaries/location_provider.dart';
import 'boundaries/preferences_provider.dart';
import 'boundaries/uploader.dart';

import 'backends/trip_recorder_backend.dart';
import 'backends/gps_auth.dart';
import 'backends/explorer_backend.dart';

import 'backends/upload_manager.dart';
import 'models.dart' show Sensor, enabledModes;

import 'pages/trip_selector_page.dart';
import 'pages/settings_page.dart';
import 'pages/explorer_page.dart';
import 'pages/trip_recorder_page.dart';
import 'pages/info_page.dart';
import 'pages/register_page.dart';

import 'widgets/modes_view.dart' show ModeRoute;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  var prefs = PreferencesProvider();
  var uploader = Uploader(prefs.uidStore);
  var network = NetworkManager(prefs.cellularNetwork);
  var storage = DataStore();
  var battery = BatteryNotifier();
  var gpsAuth = GPSAuth(prefs.gpsAuthNotifier, battery);
  var sensorDataProviders = <Sensor, SensorDataProvider>{
    Sensor.gps: LocationProvider(gpsAuth),
    Sensor.accelerometer: AccelerationProvider()
  };
  var uploadManager = UploadManager(storage, network.status, uploader);
  storage.onNewTrip = uploadManager.scheduleUpload;

  uploadManager.start();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: gpsAuth),
      ChangeNotifierProvider.value(value: prefs.cellularNetwork),
      ChangeNotifierProvider.value(value: prefs.gpsAuthNotifier),
      ChangeNotifierProvider.value(value: uploadManager.syncStatus),
      Provider<UidStore>.value(value: prefs.uidStore),
      Provider<ExplorerBackend>.value(
          value: ExplorerBackendImpl(storage, uploadManager)),
      Provider<TripRecorderBackendImpl>(
          create: (_) =>
              TripRecorderBackendImpl(sensorDataProviders, gpsAuth, storage)),
    ],
    child: MyApp(),
  ));
}

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
          for (var mode in enabledModes)
            mode.route: (context) => Consumer<TripRecorderBackendImpl>(
                  builder: (context, recorder, _) => TripRecorderPage(
                    mode: mode,
                    recorderBuilder: () => recorder,
                    exit: () => Navigator.of(context)
                        .pushReplacementNamed('/selection'),
                  ),
                ),
          '/selection': _tripSelectorPage,
          '/settings': (context) => SettingsPage(
                () => Navigator.of(context).pushNamed('/data-explorer'),
              ),
          '/data-explorer': (context) => Consumer<ExplorerBackend>(
              builder: (context, backend, _) => ExplorerPage(
                  backend,
                  (item) => Navigator.of(context)
                      .pushNamed('/info', arguments: item))),
          '/info': (context) => Consumer<ExplorerBackend>(
              builder: (context, backend, _) =>
                  InfoPage(backend, ModalRoute.of(context).settings.arguments)),
          '/initial': (context) => Consumer<UidStore>(
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
                  })),
        });
  }

  Widget _tripSelectorPage(context) => TripSelectorPage(
        modes: enabledModes,
        actions: {
          for (var em in enabledModes)
            em: () => Navigator.of(context).pushReplacementNamed(em.route)
        },
        settingsAction: () => Navigator.of(context).pushNamed('/settings'),
      );

  Widget _registerPage(context, store) => RegisterPage(store, () {
    Navigator.of(context)
        .pushReplacementNamed('/selection');
  });
  
  Widget _loadingPage(context) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Container(
            width: 100,
            height: 100,
            child: CircularProgressIndicator()),
      )); 
}
