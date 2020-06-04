import 'package:flutter/material.dart' show AssetImage, Icon, IconData, Icons, ImageIcon;
import '../models.dart' show Mode, ModeValue;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/my_flutter_app_icons.dart';

extension ModeText on Mode {
  /// Text used to display this [Mode] to the user.
  String get text {
    switch (this) {
      case Mode.test:
        return "Juste pour tester l'application";
      case Mode.walk:
        return "Trajet à pied";
      case Mode.hike:
        return "Randonnée";
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
      case Mode.minibus:
        return "Trajet en minibus";
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
  dynamic icon({double size = 24.0}) {
    switch (this) {
      case Mode.test:
        return Icon(Icons.weekend, size: size);
      case Mode.walk:
        return Icon(Icons.directions_walk, size: size);
      case Mode.hike:
        return Icon(MyFlutterApp.hike, size: size);
      case Mode.run:
        return Icon(Icons.directions_run, size: size);
      case Mode.bike:
        return Icon(Icons.directions_bike, size: size);
      case Mode.motorcycle:
        return Icon(Icons.motorcycle, size: size);
      case Mode.car:
        return Icon(Icons.directions_car, size: size);
      case Mode.bus:
        return Icon(MyFlutterApp.bus, size:size-3); //Icon(Icons.airport_shuttle, size: size);
      case Mode.minibus:
        return Icon(Icons.airport_shuttle, size: size);
      case Mode.metro:
        return Icon(Icons.subway, size: size);
      case Mode.train:
        return Icon(Icons.train, size: size);
      default:
        throw Exception("Not implemented");
    }
  }
}
