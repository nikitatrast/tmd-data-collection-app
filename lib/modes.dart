import 'package:slugify/slugify.dart';
import 'package:flutter/material.dart' show Icons, IconData;

enum Modes {
  walk,
  bike,
  motorcycle,
  car,
  bus,
  metro,
  train
}

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

extension ModeRoute on Modes {
  String get route {
    switch (this) {
      case Modes.walk:
        return "/walk";
      case Modes.bike:
        return "/bike";
      case Modes.motorcycle:
        return "/moto";
      case Modes.car:
        return "/car";
      case Modes.bus:
        return "/bus";
      case Modes.metro:
        return "/metro";
      case Modes.train:
        return "/train";
      default:
        return null;
    }
  }
}
