import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'backends/data_explorer_backend.dart';
import 'backends/preferences_provider.dart';
import 'backends/sensor_data_recorder.dart';
import 'backends/synchronization_manager.dart';

import 'models/modes.dart';

import 'widgets/trip_selector.dart';
import 'widgets/settings.dart';
import 'widgets/data_explorer.dart';
import 'widgets/trip_recorder.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  var prefs = PreferencesProvider();
  var sync = SyncManager(prefs.cellularNetwork);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
          value: prefs.gpsLocation),
      ChangeNotifierProvider.value(
          value: prefs.cellularNetwork),
      ChangeNotifierProvider.value(
          value: sync.status),
      Provider<DataExplorerBackend>(
          create: (_) => FileSystemExplorerBackend()),
      Provider<SensorDataRecorder>(
          create: (_) => SensorDataRecorder(gpsEnabled: prefs.gpsLocation)),
    ],
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('[App] build');
    /*
    For consistency: in this tree, only instanciate widgets and Consumer<T>,
    Data Providers or backends should by instanciated in main() through
    Provider<T> mechanism.
     */
    return MaterialApp(
        title: 'TMD data collection',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/selection',
        routes: {
          for (var mode in enabledModes)
            mode.route: (context) => Consumer<SensorDataRecorder>(
                  builder: (context, recorder, _) => TripRecorder(
                    mode: mode,
                    recorderBuilder: () => recorder,
                    exit: () => Navigator.of(context)
                        .pushReplacementNamed('/selection'),
                  ),
                ),
          '/selection': (context) => TripSelector(
                modes: enabledModes,
                actions: {
                  for (var em in enabledModes)
                    em: () =>
                        Navigator.of(context).pushReplacementNamed(em.route)
                },
                settingsAction: () =>
                    Navigator.of(context).pushNamed('/settings'),
              ),
          '/settings': (context) => Settings(
                () => Navigator.of(context).pushNamed('/data-explorer'),
              ),
          '/data-explorer': (context) => Consumer<DataExplorerBackend>(
              builder: (context, backend, _) => DataExplorer(backend))
        });
  }
}
