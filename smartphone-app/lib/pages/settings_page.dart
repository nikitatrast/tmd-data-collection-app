import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../backends/gps_auth.dart';
import '../boundaries/preferences_provider.dart' show CellularNetworkAllowed;

import '../widgets/gps_auth_tile.dart';
import '../widgets/loading_switch_tile_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets//uid_tile.dart';

class SettingsPage extends StatelessWidget {
  final Function openDataExplorer;

  SettingsPage(this.openDataExplorer);

  @override
  Widget build(BuildContext context) {
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
            UidTile(),
            GpsAuthTile(),
            LoadingSwitchTile<CellularNetworkAllowed>(
              title: const Text('Synchronisation 3G'),
              options: [Text('Wifi uniquement'), Text('Autorisée')],
              secondary: const Icon(Icons.wifi, size: 40),
            ),
            ListTile(
                title: Text("Afficher les données locales"),
                leading: Icon(Icons.insert_drive_file, size: 40),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: openDataExplorer)
          ]).toList()),
      Divider(),
      Expanded(child: Container()),
      Divider(),
      Consumer<GPSAuth>(
          builder: (context, auth, _) => ListTile(
            title: auth.value
                ? Text('Collecte GPS : autorisée')
                : Text('Collecte GPS : désactivée'),
            trailing: Icon(auth.value ? Icons.done : Icons.not_interested),
          )
      ),
      SyncStatusWidget(),
    ]);
  }
}
