import 'package:flutter/cupertino.dart' show ValueNotifier;
import 'package:flutter/material.dart';

enum Modes { walk, bike, motorcycle, car, bus, metro, train }

extension ModeText on Modes {
  String get text {
    switch (this) {
      case Modes.walk:
        return "Marche à pied";
      case Modes.bike:
        return "Vélo";
      case Modes.motorcycle:
        return "Moto";
      case Modes.car:
        return "Voiture";
      case Modes.bus:
        return "Bus";
      case Modes.metro:
        return "Métro / Tram";
      case Modes.train:
        return "Train";
      default:
        return null;
    }
  }
}

extension ModeRoute on Modes {
  static final _routes = {
    Modes.walk: "/walk",
    Modes.bike: "/bike",
    Modes.motorcycle: "/moto",
    Modes.car: "/car",
    Modes.bus: "/bus",
    Modes.metro: "/metro",
    Modes.train: "/train"
  };
  static final _modes = _routes.map((k, v) => MapEntry(v, k));

  String get route {
    return _routes[this];
  }
  static Modes fromRoute(String route) {
    return _modes[route];
  }
}

extension ModeIcon on Modes {
  IconData get iconData {
    switch (this) {
      case Modes.walk:
        return Icons.directions_walk;
      case Modes.bike:
        return Icons.directions_bike;
      case Modes.motorcycle:
        return Icons.motorcycle;
      case Modes.car:
        return Icons.directions_car;
      case Modes.bus:
        return Icons.directions_bus;
      case Modes.metro:
        return Icons.directions_subway;
      case Modes.train:
        return Icons.directions_railway;
      default:
        return null;
    }
  }
}

const List<Modes> enabledModes = Modes.values;

enum GPSPref {
  always,
  whenCharging,
  batteryLevel20,
  batteryLevel40,
  batteryLevel60,
  batteryLevel80,
  never
}

extension GPSPrefExt on GPSPref {
  String get value => (const {
    GPSPref.always: 'always',
    GPSPref.batteryLevel20: 'batteryLevel20',
    GPSPref.batteryLevel40: 'batteryLevel40',
    GPSPref.batteryLevel60: 'batteryLevel60',
    GPSPref.batteryLevel80: 'batteryLevel80',
    GPSPref.whenCharging: 'whenCharging',
    GPSPref.never: 'never',
  })[this];

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

class Acceleration {
  DateTime time;
  double x;
  double y;
  double z;

  Acceleration({this.time, this.x, this.y, this.z});
}

class Trip {
  DateTime start;
  DateTime end;
  Modes mode;
  Map<Sensor, List> sensorsData = {};

  String toString() => 'Trip(${mode.text} à ${start.toIso8601String()})';
}

class StoredTrip extends Trip {
  int sizeOnDisk;
}

class Location {
  DateTime time;
  double latitude;
  double longitude;
  double altitude;

  Location({this.time, this.latitude, this.longitude, this.altitude});
}

class CellularNetworkAllowed extends ValueNotifier<bool> {
  CellularNetworkAllowed() : super(null);
}

class GPSPrefNotifier extends ValueNotifier<GPSPref> {
  GPSPrefNotifier() : super(null);
}

enum Sensor { accelerometer, gps }

enum Connectivity { mobile, wifi, none, unknown }

enum SyncStatus { uploading, done, awaitingNetwork, serverDown }

enum ServerStatus { processing, down, ready }