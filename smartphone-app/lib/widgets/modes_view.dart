import 'package:flutter/material.dart' show Icons, IconData;
import '../models.dart' show Mode, ModeValue;

extension ModeText on Mode {
  /// Text used to display this [Mode] to the user.
  String get text {
    switch (this) {
      case Mode.test:
        return "Test mode";
      case Mode.walk:
        return "Marche à pied";
      case Mode.run:
        return "Course à pied";
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
        throw Exception("Not implemented");
    }
  }
}

extension ModeRoute on Mode {
  static final _routes = {
    for (var m in Mode.values)
      m: '/${m.value}',
  };
  static final _modes = _routes.map((k, v) => MapEntry(v, k));

  /// Route used to open a [TripRecorderPage] for this mode.
  String get route {
    return _routes[this];
  }

  /// Parses the [route] to retrieve the corresponding [Mode].
  static Mode fromRoute(String route) {
    return _modes[route];
  }
}

extension ModeIcon on Mode {
  /// [IconData] to display to the user for this [Mode].
  IconData get iconData {
    switch (this) {
      case Mode.test:
        return Icons.departure_board;
      case Mode.walk:
        return Icons.directions_walk;
      case Mode.run:
        return Icons.directions_run;
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
        throw Exception("Not implemented");
    }
  }
}
