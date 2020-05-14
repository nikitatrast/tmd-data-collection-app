import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../utils.dart' show StringExtension;
import '../widgets/modes_view.dart';

class TripTile extends StatelessWidget {
  final Trip trip;

  TripTile(this.trip);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: title(trip),
      leading: leadingIcon(trip, size: 40),
    );
  }

  static Widget leadingIcon(Trip item, {double size = 40}) {
    return Icon(item.mode.iconData, size: size);
  }
  
  static Widget title(Trip item) {
    return Text(formatTime(item.start).capitalize());
  }

  static String formatTime(start) {
    var day = DateFormat('EEE d MMMM', 'fr_FR');
    var time = DateFormat.jm('fr_FR');
    return day.format(start) + ' à ' + time.format(start);
  }
}

class SavedTripTile extends StatelessWidget {
  final SavedTrip trip;

  SavedTripTile(this.trip);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: TripTile.title(trip),
      leading: TripTile.leadingIcon(trip, size: 40),
      subtitle: RichText(text: subtitle(trip, trip.nbSensors, trip.end)),
    );
  }

  static TextSpan subtitle(Trip trip, int nbSensors, DateTime end) {
    return TextSpan(children: [
      durationText(end.difference(trip.start)),
      TextSpan(text: '    '),
      sensorsCount(nbSensors, trailing:' capteurs'),
    ]);
  }

  static TextSpan durationText(Duration d) {
    return TextSpan(children: [
      WidgetSpan(
        child: Icon(Icons.access_time, size: 14),
        alignment: PlaceholderAlignment.middle,
      ),
      TextSpan(
          text: ' ' + formatDuration(d),
          style: TextStyle(color: Colors.black)),
    ]);
  }

  static formatDuration(Duration d) {
    if (d.inHours != 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}';
    }
    if (d.inMinutes != 0) {
      return '${d.inMinutes}mn ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  static TextSpan sensorsCount(int nbSensors, {trailing = ''}) {
    return TextSpan(children: [
      WidgetSpan(
        child: Icon(Icons.location_on, size: 14),
        alignment: PlaceholderAlignment.middle,
      ),
      TextSpan(
          text: nbSensors.toString() + trailing,
          style: TextStyle(color: Colors.black)),
    ]);
  }
}