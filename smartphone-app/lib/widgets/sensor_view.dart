import 'package:flutter/material.dart';
import '../models.dart' show Sensor;
import '../utils.dart' show StringExtension;

extension SensorView on Sensor {
  IconData get iconData {
    switch (this) {
      case Sensor.gps:
        return Icons.location_on;
      case Sensor.accelerometer:
        return Icons.font_download;
      default:
        return Icons.device_unknown;
    }
  }

  /// Short user-displayable string for this [Sensor] instance.
  String get name {
    return this.toString().split('.')[1].capitalize();
  }
}