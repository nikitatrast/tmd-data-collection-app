import 'package:accelerometertest/models/preferences.dart';

import 'package:flutter/material.dart';
import 'loading_switch_tile.dart';
import 'synchronization_status.dart';

class Settings extends StatelessWidget {
  final Function dataExplorer;

  Settings(this.dataExplorer);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Réglages'),
      ),
      body: Column(children: [
          ListView(
              shrinkWrap: true,
              children: ListTile.divideTiles(context: context, tiles: [
                LoadingSwitchTile<GPSLocationAllowed>(
                  title: const Text('Activer le GPS'),
                  subtitle: const Text(
                      'Autoriser la collecte des données de géolocalisation.'),
                  secondary: const Icon(Icons.map),
                ),
                LoadingSwitchTile<CellularNetworkAllowed>(
                  title: const Text('Synchronisation 3G'),
                  subtitle: const Text(
                      "Utiliser le réseau 3G ou 4G pour synchroniser les données."),
                  secondary: const Icon(Icons.wifi),
                ),
                ListTile(
                    title: Text("Afficher les données enregistrées"),
                    leading: Icon(Icons.insert_drive_file),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: dataExplorer)
              ]).toList()),
      Divider(),
      Expanded(child: Container()),
      Divider(),
      SyncStatusWidget(),
      ]),
    );
  }
}
