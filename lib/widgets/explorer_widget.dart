import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../models.dart' show StoredTrip, Mode, ModeIcon;
import '../utils.dart' show StringExtension;

abstract class ExplorerBackend {
  Future<List<StoredTrip>> trips();

  Future<bool> delete(StoredTrip item);
}

class ExplorerWidget extends StatefulWidget {
  final ExplorerBackend backend;

  ExplorerWidget(this.backend);

  @override
  State<ExplorerWidget> createState() => ExplorerWidgetState();
}

class ExplorerWidgetState extends State<ExplorerWidget> {
  List<StoredTrip> items;
  Set<StoredTrip> selected = Set();

  @override
  void initState() {
    super.initState();
    widget.backend.trips().then((items) => setState(() => this.items = items));
  }

  void itemChanged(StoredTrip item, bool isSelected) {
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

  Future<bool> deleteItem(StoredTrip item) async {
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
          child: Text("Chargement en cours...",textAlign: TextAlign.center));
    } else if (items.isEmpty) {
      body = Center(
          child: Text("Aucun trajet enregistré",textAlign: TextAlign.center));
    } else {
      body = Column(mainAxisSize: MainAxisSize.max, children: [
        Expanded(
            child: ListView(
              children: <Widget>[
                for (var item in items)
                  CheckboxListTile(
                    title: _makeTitle(item),
                    secondary: Icon(item.mode.iconData, size: 40),
                    subtitle: _makeSubtitle(item),
                    value: selected.contains(item),
                    onChanged: (value) => itemChanged(item, value),
                  )
              ],
            )),
        ButtonBar(
            alignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
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

  Widget _makeTitle(item) {
    return Text(_formatDate(item.start, item.end).capitalize());
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
              style: TextStyle(color: Colors.black)
          ),
          WidgetSpan(
            child: Icon(Icons.computer, size: 14),
          ),
          TextSpan(
              text: ' ' + filesize(item.sizeOnDisk) + '    ',
              style: TextStyle(color: Colors.black)
          ),
          WidgetSpan(
            child: Icon(Icons.location_on, size: 14),
          ),
          TextSpan(
              text: item.sensorsData.keys.length.toString(),
              style: TextStyle(color: Colors.black)
          ),
        ],
      ),
    );
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
}

String _formatDate(start, stop) {
  var day = DateFormat('EEE d MMMM', 'fr_FR');
  var time = DateFormat.jm('fr_FR');
  return day.format(start) + ' entre ' + time.format(start) + ' et ' + time.format(stop);
}

String _formatDuration(StoredTrip trip) {
  var d = trip.end.difference(trip.start);

  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}mn ${d.inSeconds.remainder(60)}s';
  }
  return '${d.inSeconds}s';
}
