import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart' show Trip, Sensor;
import '../widgets/modes_view.dart' show ModeIcon;
import '../utils.dart' show StringExtension;

enum UploadStatus {
  local, pending, uploading, uploaded, unknown, error
}

abstract class ExplorerBackend {
  Future<List<ExplorerItem>> items();
  Future<bool> delete(ExplorerItem item);
  Future<int> nbEvents(ExplorerItem item, Sensor s);
  void scheduleUpload(ExplorerItem item);
  void cancelUpload(ExplorerItem item);
}

class ExplorerItem extends Trip {
  DateTime end;
  int sizeOnDisk;
  int nbSensors;
  ValueNotifier<UploadStatus> status;
}

class ExplorerPage extends StatefulWidget {
  final ExplorerBackend backend;

  ExplorerPage(this.backend);

  @override
  State<ExplorerPage> createState() => ExplorerPageState();
}

class ExplorerPageState extends State<ExplorerPage> {
  List<ExplorerItem> items;
  Set<ExplorerItem> selected = Set();

  @override
  void initState() {
    super.initState();
    widget.backend.items().then((items) => setState(() => this.items = List.from(items)));
  }

  void itemChanged(ExplorerItem item, bool isSelected) {
    setState(() {
      if (isSelected) {
        selected.add(item);
      } else {
        selected.remove(item);
      }
    });
  }

  Future<bool> deleteSelected() async {
    var toDelete = List.from(selected); // no iterator.remove() in dart...
    var results = toDelete.map((item) => deleteItem(item));
    var allOk = await results.reduce((a, b) async => await a && await b);
    setState(() {});
    return allOk;
  }

  Future<bool> deleteItem(ExplorerItem item) async {
    print('[ExplorerWidget] Deletion request for $item');
    var ok = await widget.backend.delete(item);
    print('[ExplorerWidget] deletion status: $ok');
    if (ok) {
      assert(selected.remove(item));
      assert(items.remove(item));
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (items == null) {
      body = Center(
          child: Text("Chargement en cours...", textAlign: TextAlign.center));
    } else if (items.isEmpty) {
      body = Center(
          child: Text("Aucun trajet enregistré", textAlign: TextAlign.center));
    } else {
      body = Column(mainAxisSize: MainAxisSize.max, children: [
        Expanded(
            child: ListView(
          children: <Widget>[
            for (var item in items) _makeTile(item),
          ],
        )),
        ButtonBar(
            alignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: (selected.isEmpty)
                ? []
                : [
                    FloatingActionButton(
                      onPressed:
                          selected.isEmpty ? null : () => deleteDialog(context),
                      child: Icon(Icons.delete),
                      heroTag: 'deleteButton',
                    )
                  ])
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Données enregistrées'),
      ),
      body: body,
    );
  }

  Widget _makeTile(ExplorerItem item) {
    if (selected.isNotEmpty) {
      return CheckboxListTile(
        title: _makeTitle(item),
        secondary: Icon(item.mode.iconData, size: 40),
        subtitle: _makeSubtitle(item),
        value: selected.contains(item),
        onChanged: (value) => itemChanged(item, value),
      );
    } else {
      return ListTile(
        title: _makeTitle(item),
        leading: Icon(item.mode.iconData, size: 40),
        subtitle: _makeSubtitle(item),
        onTap: () => _infoDialog(context, item),
        onLongPress: () =>
            setState(() {
              selected.add(item);
            }),
      );
    }
  }

  void _infoDialog(BuildContext context, ExplorerItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Info'),
          actions: [
            IconButton(
              icon: Icon(item.mode.iconData),
              onPressed: null,
            )
          ],
        ),
        body: ListView(
            shrinkWrap: true,
            //crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                  title: Container(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: Icon(item.mode.iconData, size: 80))))
            ]..addAll(ListTile.divideTiles(context: context, tiles: [
                  ListTile(
                    title: Text('Début: ' + _formatDate(item.start)),
                    leading: Icon(Icons.access_time, size: 40),
                  ),
                  ListTile(
                      title: Text('Fin: ' + _formatDate(item.end)),
                      leading: Icon(Icons.access_time, size: 40)),
                  ListTile(
                      title: Text('Durée: ' + _formatDuration(item)),
                      leading: Icon(Icons.timelapse, size: 40)),
                  for (Sensor sensor in Sensor.values)
                    ListTile(
                        title: _sensorDataWidget(item, sensor),
                        leading: Icon(sensor.iconData, size: 40)),
                ]).toList())
        ),
        floatingActionButton: OutlineButton(
          child: Text('retour'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ));
  }

  void deleteDialog(BuildContext context) {
    Widget cancelButton = FlatButton(
      child: Text("Non"),
      onPressed: () => Navigator.of(context).pop(),
    );

    Widget continueButton = FlatButton(
        child: Text("Oui, effacer."),
        onPressed: () {
          Navigator.of(context).pop(); // pop this dialog
          loadingDialog(context, 'Suppression');
          deleteSelected().then((success) {
            Navigator.of(context).pop(); // pop loading dialog
          }); // pop loading dialog
        });

    AlertDialog alert = AlertDialog(
      title: Text("Confirmation"),
      content:
          Text("Voulez-vous vraiment effacer ${selected.length} trajet(s) ?"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void loadingDialog(BuildContext context, String title) {
    var dialog = SimpleDialog(title: Text(title), children: [
      SizedBox(width: 50, height: 50, child: CircularProgressIndicator())
    ]);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  Widget _sensorDataWidget(ExplorerItem item, Sensor sensor) {
    var sName = _sensorName(sensor);
    return FutureBuilder(
        future: widget.backend.nbEvents(item, sensor),
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

extension SensorIcon on Sensor {
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
}

Widget _makeTitle(item) {
  return Text(_formatPeriod(item.start, item.end).capitalize());
}

Widget _makeSubtitle(item) {
  return RichText(
    text: TextSpan(
      children: [
        WidgetSpan(
          child: Icon(Icons.access_time, size: 14),
        ),
        TextSpan(
            text: ' ' + _formatDuration(item) + '    ',
            style: TextStyle(color: Colors.black)),
        WidgetSpan(
          child: Icon(Icons.computer, size: 14),
        ),
        TextSpan(
            text: ' ' + filesize(item.sizeOnDisk) + '    ',
            style: TextStyle(color: Colors.black)),
        WidgetSpan(
          child: Icon(Icons.location_on, size: 14),
        ),
        TextSpan(
            text: item.nbSensors.toString(),
            style: TextStyle(color: Colors.black)),
      ],
    ),
  );
}

String _sensorName(Sensor sensor) {
  return sensor.toString().split('.')[1].capitalize();
}



String _formatPeriod(start, stop) {
  var day = DateFormat('EEE d MMMM', 'fr_FR');
  var time = DateFormat.jm('fr_FR');
  return day.format(start) +
      ' entre ' +
      time.format(start) +
      ' et ' +
      ((start == stop) ? '??' : time.format(stop));
}

String _formatDate(DateTime date) {
  var format = DateFormat('EEE d MMMM,', 'fr_FR').add_Hms();
  return format.format(date);
}

String _formatDuration(ExplorerItem trip) {
  var d = trip.end.difference(trip.start);

  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}mn ${d.inSeconds.remainder(60)}s';
  }
  return '${d.inSeconds}s';
}
