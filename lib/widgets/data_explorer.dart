import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:filesize/filesize.dart';

class ExplorerItem {
  final name;
  final datetime;
  final size;
  final data;

  ExplorerItem(this.name, this.datetime, this.size, this.data);
}

abstract class DataExplorerBackend {
  Future<List<ExplorerItem>> getItems();
  Future<bool> delete(ExplorerItem item);
}

class DataExplorer extends StatefulWidget {
  final DataExplorerBackend backend;

  DataExplorer(this.backend);

  @override
  State<DataExplorer> createState() => DataExplorerState();
}

class DataExplorerState extends State<DataExplorer> {
  List<ExplorerItem> items;
  Set<ExplorerItem> selected = Set();

  @override
  void initState() {
    widget.backend.getItems().then((items) =>
      setState(() => this.items = items)
    );
  }

  String formatDate(datetime) {
    return datetime.toIso8601String().replaceAll('T', ' at ').split('.').first;
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
    print('Deleting ${item.name}');
    var ok = await widget.backend.delete(item);
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
          child: Text(
            "Chargement en cours...",
            textAlign: TextAlign.center,
          ));
    } else if (items.isEmpty) {
      body = Center(
          child: Text(
            "Aucun trajet enregistré",
            textAlign: TextAlign.center,
          ));
    } else {
      body = Column(
          mainAxisSize: MainAxisSize.max,
          children:[
            Expanded(child:ListView(
              children: <Widget>[
                for (var item in items)
                  CheckboxListTile(
                    title: Text(item.name),
                    subtitle: Text(filesize(item.size) + ', ' + formatDate(item.datetime)),
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
                    onPressed: selected.isEmpty ? null : () => deleteDialog(context),
                    child: Icon(Icons.delete),
                    heroTag: 'deleteButton',
                  )
                ]
            )
          ]);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Données enregistrées'),
      ),
      body: body,
    );
  }

  deleteDialog(BuildContext context) {
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
        }
    );

    AlertDialog alert = AlertDialog(
      title: Text("Confirmation"),
      content: Text("Voulez-vous vraiment effacer ${selected.length} trajet(s) ?"),
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

  loadingDialog(BuildContext context, String title) {
    var dialog = SimpleDialog(
      title: Text(title),
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child:SpinKitCircle(
              color: Theme.of(context).primaryColor
          )
        )
      ]
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }
}
