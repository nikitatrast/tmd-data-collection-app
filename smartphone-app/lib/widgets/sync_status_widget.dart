import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backends/upload_manager.dart' show SyncStatus;

/// Widget to display the current [SyncStatus]'s value.
class SyncStatusWidget extends StatelessWidget {
  final bool hideFinished;
  final bool dense;

  SyncStatusWidget({this.hideFinished=false, this.dense=false});

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
            onTap: null,
            dense: this.dense);
      case SyncStatus.serverDown:
        return ListTile(
            title: Text("Synchronisation : serveur indisponible"),
            trailing: Icon(Icons.cloud_off, color: Colors.red),
            onTap: null,
            dense: this.dense);
      case SyncStatus.done:
        return (hideFinished) ? Container() : ListTile(
            title: Text("Synchronisation : terminée"),
            trailing: Icon(Icons.cloud_done, color: Colors.green),
            onTap: null,
            dense: this.dense);
      case SyncStatus.uploading:
        return ListTile(
            title: Text("Synchronisation : en cours"),
            trailing: Icon(Icons.cloud_upload, color: Colors.green),
            onTap: null,
            dense: this.dense);
      default:
        return ListTile(
            title: Text("Synchronisation : état inconnu"),
            trailing: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator()
            ),
            onTap: null,
            dense: this.dense);
    }
  }
}