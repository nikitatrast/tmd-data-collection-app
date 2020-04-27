import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart' show Sensor;
import '../widgets/modes_view.dart';
import '../widgets/sensor_view.dart';
import '../pages/explorer_page.dart';

/// Page to display information about an [ExplorerItem].
class InfoPage extends StatelessWidget {
  final ExplorerItem trip;
  final ExplorerBackend backend;

  InfoPage(this.backend, this.trip);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Info'),
        actions: [
          IconButton(
            icon: Icon(trip.mode.iconData),
            onPressed: null,
          )
        ],
      ),
      body: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
                title: Container(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Icon(trip.mode.iconData, size: 80))))
          ]..addAll(ListTile.divideTiles(context: context, tiles: [
              ListTile(
                title: Text('Début: ' + _formatDate(trip.start)),
                leading: Icon(Icons.access_time, size: 40),
              ),
              ListTile(
                  title: Text('Fin: ' + _formatDate(trip.end)),
                  leading: Icon(Icons.access_time, size: 40)),
              ListTile(
                  title: Text('Durée: ' + trip.formattedDuration),
                  leading: Icon(Icons.timelapse, size: 40)),
              for (Sensor sensor in Sensor.values)
                ListTile(
                    title: _sensorDataWidget(sensor),
                    leading: Icon(sensor.iconData, size: 40)),
            ]).toList())),
      floatingActionButton: OutlineButton(
        child: Text('retour'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _sensorDataWidget(Sensor sensor) {
    var sName = sensor.name;
    return FutureBuilder(
        future: backend.nbEvents(trip, sensor),
        builder: (context, snap) {
          if (!snap.hasData)
            return Text('$sName: calcul en cours...');
          else if (snap.data == -1)
            return Text('$sName: 0');
          else
            return Text('$sName: ${snap.data} lignes');
        });
  }
}

String _formatDate(DateTime date) {
  var format = DateFormat('EEE d MMMM,', 'fr_FR').add_Hms();
  return format.format(date);
}
