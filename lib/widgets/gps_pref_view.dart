import 'package:flutter/material.dart';

import '../boundaries/preferences_provider.dart' show GPSPref;

extension GPSPrefView on GPSPref {
  String get displayName => (const {
    GPSPref.always: 'Toujours',
    GPSPref.whenCharging: 'En charge',
    GPSPref.batteryLevel20: 'Batterie > 20%',
    GPSPref.batteryLevel40: 'Batterie > 40%',
    GPSPref.batteryLevel60: 'Batterie > 60%',
    GPSPref.batteryLevel80: 'Batterie > 80%',
    GPSPref.never: 'Jamais'
  })[this];

  IconData get icon => (const {
    GPSPref.always: Icons.done,
    GPSPref.batteryLevel20: Icons.battery_full,
    GPSPref.batteryLevel40: Icons.battery_full,
    GPSPref.batteryLevel60: Icons.battery_full,
    GPSPref.batteryLevel80: Icons.battery_full,
    GPSPref.whenCharging: Icons.battery_charging_full,
    GPSPref.never: Icons.not_interested,
  })[this];
}