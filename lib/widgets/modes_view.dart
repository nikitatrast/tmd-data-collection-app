import 'package:flutter/material.dart' show Icons, IconData;
import '../models.dart' show Mode, ModeValue;

extension ModeText on Mode {
  String get text {
    switch (this) {
      case Mode.walk:
        return "Marche à pied";
      case Mode.bike:
        return "Vélo";
      case Mode.motorcycle:
        return "Moto";
      case Mode.car:
        return "Voiture";
      case Mode.bus:
        return "Bus";
      case Mode.metro:
        return "Métro / Tram";
      case Mode.train:
        return "Train";
      default:
        return null;
    }
  }
}

extension ModeRoute on Mode {
  static final _routes = {
    for (var m in Mode.values)
      m: '/${m.value}',
  };
  static final _modes = _routes.map((k, v) => MapEntry(v, k));

  String get route {
    return _routes[this];
  }
  static Mode fromRoute(String route) {
    return _modes[route];
  }
}

extension ModeIcon on Mode {
  IconData get iconData {
    switch (this) {
      case Mode.walk:
        return Icons.directions_walk;
      case Mode.bike:
        return Icons.directions_bike;
      case Mode.motorcycle:
        return Icons.motorcycle;
      case Mode.car:
        return Icons.directions_car;
      case Mode.bus:
        return Icons.directions_bus;
      case Mode.metro:
        return Icons.directions_subway;
      case Mode.train:
        return Icons.directions_railway;
      default:
        return null;
    }
  }
}
