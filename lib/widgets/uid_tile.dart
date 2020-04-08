import 'package:accelerometertest/boundaries/preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UidTile extends StatefulWidget {
  @override
  _UidTileState createState() => _UidTileState();
}

class _UidTileState extends State<UidTile> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UidStore>(
        builder: (context, store, _) =>
            FutureBuilder(
                future: Future.wait(<Future<String>>[store.getLocalUid(), store.getUid()]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(
                        title: Text('UID'),
                        subtitle: Text('Loading...')
                    );
                  } else {
                    var data = snapshot.data;
                    var name = data[0];
                    var uid = data[1];
                    return ListTile(
                        title: Text("${name ?? 'Anonyme'}"),
                        subtitle: Text("uid: ${uid ?? ''}"),
                        onTap: () => confirmationDialog(context, store)
                    );
                  }
                }
            )
    );
  }

  void confirmationDialog(context, store) {
    showDialog(
        context: context,
        child: AlertDialog(
            title: Text("Effacer les données ?"),
            content: Text("Voulez-vous effacer votre UID ?"),
            actions: [
              FlatButton(
                  child: Text('non'),
                  onPressed: () => Navigator.of(context).pop()
              ),
              FlatButton(
                  child: Text('oui'),
                  onPressed: () {
                    store.setLocalUid(null);
                    store.setUid(null);
                    Navigator.of(context).pop();
                    restartDialog(context);
                  }
              )
            ]
        )
    );
  }

  void restartDialog(context) {
    showDialog(
        barrierDismissible: false,
        context: context,
        child: WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text("Redémarrer l'application"),
              content: Text("Veuillez redémarrer l'application"),
            )
        )
    );
  }
}
