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

const List<Modes> enabledModes = [
  Modes.walk,
  Modes.bike,
  Modes.motorcycle,
  Modes.car,
  Modes.bus,
  Modes.metro,
  Modes.train
];

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

class GPSLocationAllowed extends ValueNotifier<bool> {
  GPSLocationAllowed() : super(null);
}

enum Sensor { accelerometer, gps }

enum Connectivity { mobile, wifi, none, unknown }

enum SyncStatus { uploading, done, awaitingNetwork, serverDown }

enum ServerStatus { processing, down, ready }