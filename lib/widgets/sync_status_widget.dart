import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backends/sync_manager.dart' show SyncStatus;

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
      case SyncStatus.awaitingNetwork:
        return ListTile(
            title: Text("Synchronisation : en attente du réseau"),
            trailing: Icon(Icons.cloud_off, color: Colors.red),
            onTap: null);
      case SyncStatus.serverDown:
        return ListTile(
            title: Text("Synchronisation : serveur indisponible"),
            trailing: Icon(Icons.cloud_off, color: Colors.red),
            onTap: null);
      case SyncStatus.done:
        return ListTile(
            title: Text("Synchronisation : terminée"),
            trailing: Icon(Icons.cloud_done, color: Colors.green),
            onTap: null);
      case SyncStatus.uploading:
        return ListTile(
            title: Text("Synchronisation : en cours"),
            trailing: Icon(Icons.cloud_upload, color: Colors.green),
            onTap: null);
      default:
        return ListTile(
            title: Text("Synchronisation : état inconnu"),
            trailing: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator()
            ),
            onTap: null);
    }
  }
}