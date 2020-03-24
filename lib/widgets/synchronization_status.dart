import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/synchronization_status.dart';

class SyncStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ValueNotifier<SyncStatus>>(
        builder: (context, status, _) =>
            ListView(
              shrinkWrap: true,
              padding: EdgeInsets.only(top: 0),
              children: ListTile.divideTiles(context: context, tiles: [
                makeChild(status.value)
              ]).toList(),
            ));
  }

  Widget makeChild(SyncStatus status) {
    switch (status) {
      case SyncStatus.waiting:
        return ListTile(
            title: Text("Synchronisation : en attente du réseau"),
            //subtitle: Text('Synchronisation en pause'),
            trailing: Icon(Icons.cloud_off, color: Colors.red),
            onTap: null);
      case SyncStatus.done:
        return ListTile(
            title: Text("Synchronisation : terminée"),
            //subtitle: Text('Toutes les données ont été synchronisées'),
            trailing: Icon(Icons.cloud_done, color: Colors.green),
            onTap: null);
      case SyncStatus.uploading:
        return ListTile(
            title: Text("Synchronisation : en cours"),
            //subtitle: Text('Synchronisation en cours'),
            trailing: Icon(Icons.cloud_upload, color: Colors.green),
            onTap: null);
      default:
        return ListTile(
            title: Text("Synchronisation : état inconnu"),
            //subtitle: Text('Synchronisation en cours'),
            trailing: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator()
            ),
            onTap: null);
    }
  }
}