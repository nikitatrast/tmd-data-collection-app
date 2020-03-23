import 'package:accelerometertest/backends/sensor_data_recorder.dart';
import 'package:flutter/material.dart';

import 'widgets/trip_selector.dart';
import 'widgets/settings.dart';
import 'widgets/data_explorer.dart';
import 'widgets/trip_recorder.dart';

import 'backends/settings_backend.dart';
import 'backends/data_explorer_backend.dart';

import 'modes.dart';

void main() => runApp(MyApp());

const List<Modes> enabledModes = [
  Modes.walk,
  Modes.bike,
  Modes.motorcycle,
  Modes.car,
  Modes.bus,
  Modes.metro,
  Modes.train
];

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('[App] build');
    return MaterialApp(
        title: 'TMD data collection',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/selection',
        routes: {
          for (var m in enabledModes)
            m.route: (context) => TripRecorder(
                  mode: m,
                  recorderBuilder: () => SensorDataRecorder(
                    gpsAllowed: SharedPrefsSettingsBackend().getGPSValue()
                  ),
                  exit: () =>
                      Navigator.of(context).pushReplacementNamed('/selection'),
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
                SharedPrefsSettingsBackend(),
                () => Navigator.of(context).pushNamed('/data-explorer'),
              ),
          '/data-explorer': (context) =>
              DataExplorer(FileSystemExplorerBackend())
        });
  }
}