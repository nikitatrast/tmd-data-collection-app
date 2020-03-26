import 'package:accelerometertest/backends/gps_auth.dart';
import 'package:provider/provider.dart';

import '../models.dart'
    show
        CellularNetworkAllowed,
        GPSPref,
        GPSPrefExt;

import '../widgets/gps_auth_tile.dart';

import 'package:flutter/material.dart';
import 'loading_switch_tile_widget.dart';
import 'sync_status_widget.dart';

class SettingsWidget extends StatelessWidget {
  final Function dataExplorer;

  SettingsWidget(this.dataExplorer);

  @override
  Widget build(BuildContext context) {
    print(GPSPref.values.map((v) => v.value).toList());
    return Scaffold(
      appBar: AppBar(
        title: Text('Réglages'),
      ),
      body: body(context),
    );
  }

  Widget body(BuildContext context) {
    return Column(children: [
      ListView(
          shrinkWrap: true,
          children: ListTile.divideTiles(context: context, tiles: [
            GpsAuthTile(),
            LoadingSwitchTile<CellularNetworkAllowed>(
              title: const Text('Synchronisation 3G'),
              options: [Text('Wifi uniquement'), Text('Autorisée')],
              secondary: const Icon(Icons.wifi, size: 40),
            ),
            ListTile(
                title: Text("Afficher les données enregistrées"),
                leading: Icon(Icons.insert_drive_file, size: 40),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: dataExplorer)
          ]).toList()),
      Divider(),
      Expanded(child: Container()),
      Divider(),
      Consumer<GPSAuth>(
          builder: (context, auth, _) => ListTile(
            title: auth.value ? Text('Collecte GPS : autorisée') : Text('Collecte GPS : désactivée'),
            trailing: Icon(auth.value ? Icons.done : Icons.not_interested),
          )
      ),
      SyncStatusWidget(),
    ]);
  }
}
