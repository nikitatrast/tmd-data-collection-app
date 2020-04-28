import 'package:flutter/material.dart';

import '../backends/upload_manager.dart' show UploadStatus;
import '../models.dart' show Trip, Sensor;
import '../widgets/explorer_item_tile.dart';
import '../widgets/modes_view.dart' show ModeIcon;

/// Controller to provide data to [ExplorerPage].
abstract class ExplorerBackend {
  Future<List<ExplorerItem>> items();
  Future<bool> delete(ExplorerItem item);
  Future<int> nbEvents(ExplorerItem item, Sensor s);
  void scheduleUpload(ExplorerItem item);
  void cancelUpload(ExplorerItem item);
  List<Future<void> Function(Trip)> get onTripDeleted;
}

/// An Item that can be displayed in [ExplorerPage].
class ExplorerItem extends Trip {
  DateTime end;
  int sizeOnDisk;
  int nbSensors;
  ValueNotifier<UploadStatus> status;

  String get formattedDuration {
    var d = this.end.difference(this.start);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}mn ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}

/// Page to display a list of [ExplorerItem] provided by an [ExplorerBackend].
///
/// Initially designed to display the list of recorded trips available on local
/// storage.
class ExplorerPage extends StatefulWidget {
  final ExplorerBackend backend;

  /// Callback to open the information page about an [ExplorerItem].
  final void Function(ExplorerItem) openInfoPage;

  ExplorerPage(this.backend, this.openInfoPage);

  @override
  State<ExplorerPage> createState() => ExplorerPageState();
}

class ExplorerPageState extends State<ExplorerPage> {
  /// Items to be displayed.
  List<ExplorerItem> items;

  /// Items of [items] that are currently displayed with a checked checkbox.
  Set<ExplorerItem> selected;

  @override
  void initState() {
    super.initState();
    selected = Set();
    widget.backend.items().then((items) => setState(() => this.items = List.from(items)));
    widget.backend.onTripDeleted.add(_onTripDeleted);
  }

  @override
  void dispose() {
    super.dispose();
    widget.backend.onTripDeleted.remove(_onTripDeleted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Données locales'),
      ),
      body: Builder(builder: this._body),
    );
  }

  Widget _body(BuildContext context) {
    if (items == null) {
      return Center(
          child: Text("Chargement en cours...", textAlign: TextAlign.center));
    } else if (items.isEmpty) {
      return Center(
          child: Text("Tous les trajets ont été envoyés au serveur.", textAlign: TextAlign.center));
    } else {
      return Column(mainAxisSize: MainAxisSize.max, children: [
        Expanded(
            child: ListView(
              children: <Widget>[
                for (var item in items)
                  ExplorerItemTile(
                    item: item,
                    asCheckbox: selected.isNotEmpty,
                    checked: selected.contains(item),
                    onChanged: (checked) => _itemSelected(item, checked),
                    onTap: () => widget.openInfoPage(item),
                    onLongPress: () => _itemSelected(item, true),
                    onUpload: () => _uploadItem(context, item),
                    onCancelUpload: () => widget.backend.cancelUpload(item),
                  ),
              ],
            )),
        ButtonBar(
            alignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: (selected.isEmpty) ? [] : [
              FloatingActionButton(
                onPressed:
                selected.isEmpty ? null : () => _deleteDialog(context),
                child: Icon(Icons.delete),
                heroTag: 'deleteButton',
              )
            ])
      ]);
    }
  }

  /// Adds or remove [item] to [selected] based on [isSelected]'s value.
  void _itemSelected(ExplorerItem item, bool isSelected) {
    setState(() {
      if (isSelected) {
        selected.add(item);
      } else {
        selected.remove(item);
      }
    });
  }

  /// Asks [widget.backend] to delete [ExplorerItem]s in [selected].
  Future<bool> _deleteSelected() async {
    var toDelete = List.from(selected); // no iterator.remove() in dart...
    var results = toDelete.map((item) async {
      print('[ExplorerWidget] Deletion request for $item');
      var ok = await widget.backend.delete(item);
      // Note: [_onTripDeleted] callback will update the UI.
      print('[ExplorerWidget] deletion status: $ok');
      return ok;
    });
    var allOk = await results.reduce((a, b) async => await a && await b);
    return allOk;
  }

  Future<void> _onTripDeleted(Trip t) {
    setState(() {
      selected.removeWhere((item) => item == t);
      items.removeWhere((item) => item == t);
    });
    return (() async {})();
  }

  /// Schedules [item] to be uploaded to the server.
  void _uploadItem(BuildContext context, ExplorerItem item) {
    var scaffold = Scaffold.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(SnackBar(
      content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.mode.iconData),
            Text("  Le trajet sera envoyé au serveur  "),
            Icon(Icons.cloud_upload),
          ]
      ),
    ));
    widget.backend.scheduleUpload(item);
  }

  /// Prompts for confirmation before deletion of [selected] items.
  void _deleteDialog(BuildContext context) {
    final onContinue = () {
      Navigator.of(context).pop(); // pop this dialog
      _loadingDialog(context, 'Suppression');
      _deleteSelected().then((success) {
        Navigator.of(context).pop(); // pop loading dialog
      });
    };
    showDialog(
        context: context,
        builder: (BuildContext context) =>
            AlertDialog(
              title: Text("Confirmation"),
              content:
              Text("Voulez-vous vraiment effacer ${selected
                  .length} trajet(s) ?"),
              actions: [
                FlatButton(
                  child: Text("Non"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FlatButton(
                    child: Text("Oui, effacer."),
                    onPressed: onContinue),
              ],
            )
    );
  }

  /// Displays a simple progress dialog.
  void _loadingDialog(BuildContext context, String title) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            SimpleDialog(title: Text(title), children: [
              SizedBox(
                  width: 50, height: 50, child: CircularProgressIndicator())
            ])
    );
  }
}
