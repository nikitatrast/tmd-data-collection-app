import 'package:accelerometertest/pages/info_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'boundaries/sensor_data_provider.dart';
import 'boundaries/acceleration_provider.dart';
import 'boundaries/battery.dart';
import 'boundaries/data_store.dart';
import 'boundaries/location_provider.dart';
import 'boundaries/preferences_provider.dart';

import 'backends/trip_recorder_backend.dart';
import 'backends/sync_manager.dart';
import 'backends/gps_auth.dart';
import 'backends/explorer_backend.dart';

import 'models.dart' show enabledModes, Sensor;

import 'pages/trip_selector_page.dart';
import 'pages/settings_page.dart';
import 'pages/explorer_page.dart';
import 'pages/trip_recorder_page.dart';

import 'widgets/modes_view.dart' show ModeRoute;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var prefs = PreferencesProvider();
  var sync = SyncManager(prefs.cellularNetwork);
  var storage = DataStore();
  var battery = BatteryNotifier();
  var gpsAuth = GPSAuth(prefs.gpsAuthNotifier, battery);
  var sensorDataProviders = <Sensor, SensorDataProvider>{
    Sensor.gps: LocationProvider(gpsAuth),
    Sensor.accelerometer: AccelerationProvider()
  };

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: gpsAuth),
      ChangeNotifierProvider.value(value: prefs.cellularNetwork),
      ChangeNotifierProvider.value(value: prefs.gpsAuthNotifier),
      ChangeNotifierProvider.value(value: sync.status),
      Provider<ExplorerBackend>.value(
          value: ExplorerBackendImpl(storage)),
      Provider<TripRecorderBackendImpl>(
          create: (_) => TripRecorderBackendImpl(
              sensorDataProviders, gpsAuth, storage)),
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
        //initialRoute: '/test-location',
        initialRoute: '/selection',
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
          '/selection': (context) => TripSelectorPage(
                modes: enabledModes,
                actions: {
                  for (var em in enabledModes)
                    em: () =>
                        Navigator.of(context).pushReplacementNamed(em.route)
                },
                settingsAction: () =>
                    Navigator.of(context).pushNamed('/settings'),
              ),
          '/settings': (context) => SettingsPage(
                () => Navigator.of(context).pushNamed('/data-explorer'),
              ),
          '/data-explorer': (context) => Consumer<ExplorerBackend>(
              builder: (context, backend, _) => ExplorerPage(
                  backend, (item) => Navigator.of(context).pushNamed('/info', arguments: item))),
          '/info': (context) => Consumer<ExplorerBackend>(
              builder: (context, backend, _) => InfoPage(backend, ModalRoute.of(context).settings.arguments)),
        });
  }
}
