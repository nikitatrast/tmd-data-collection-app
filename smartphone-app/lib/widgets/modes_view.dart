import 'package:flutter/material.dart' show Icons, IconData;
import '../models.dart' show Mode, ModeValue;

extension ModeText on Mode {
  /// Text used to display this [Mode] to the user.
  String get text {
    switch (this) {
      case Mode.test:
        return "Juste pour tester";
      case Mode.walk:
        return "Trajet à pied";
      case Mode.run:
        return "Trajet en courant";
      case Mode.bike:
        return "Trajet en vélo";
      case Mode.motorcycle:
        return "Trajet en moto / scooter";
      case Mode.car:
        return "Trajet en voiture";
      case Mode.bus:
        return "Trajet en bus / car";
      case Mode.metro:
        return "Trajet en métro / tram";
      case Mode.train:
        return "Trajet en train";
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
        return Icons.weekend;
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
        return Icons.airport_shuttle;
      case Mode.metro:
        return Icons.subway;
      case Mode.train:
        return Icons.train;
      default:
        throw Exception("Not implemented");
    }
  }
}
