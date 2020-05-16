import 'dart:io' show Platform;
import 'package:grouped_list/grouped_list.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../backends/gps_status.dart';
import '../boundaries/preferences_provider.dart' show CellularNetworkAllowed;
import '../widgets/loading_switch_tile_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/uid_tile.dart';
import '../widgets/gps_status_tile.dart';

/// Page to display the app's settings and configuration options.
class SettingsPage extends StatelessWidget {
  /// Opens a page to display local trips.
  final void Function() openDataExplorer;

  /// Opens a page to display info about data sent to the server.
  final void Function() openUploadedTrips;

  /// Opens a page to display saved [GeoFences].
  final void Function() openGeoFences;

  /// Opens the page to display consent form.
  final void Function() openConsent;

  SettingsPage(this.openDataExplorer, this.openUploadedTrips,
      this.openGeoFences, this.openConsent);

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
    return ListView(
      children:
      ListTile.divideTiles(context: context, tiles: [
        GpsStatusTile(),
        _cellularNetworkTile,
        _consentTile,
        _dataExplorerTile,
        _uploadedTripsTile,
        _geoFenceTile,
        ]).toList()
      + [
        Divider(height:1),
        Container(height:50),
        Text('- info -', textAlign: TextAlign.center,),
      ]
      + ListTile.divideTiles(context: context, tiles: [
        UidTile(),
        SyncStatusWidget(),
        if (!Platform.isIOS)
          _gpsStatusTile,
        ]).toList(),
    );
  }

  /// Widget to open the page with consent text.
  Widget get _consentTile => ListTile(
        title: Text('Notice d\'information'),
        leading: Icon(Icons.info_outline, size: 40),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: openConsent,
      );

  /// Widget to open the data explorer page.
  Widget get _dataExplorerTile => ListTile(
      title: Text("Données locales"),
      leading: Icon(Icons.insert_drive_file, size: 40),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: openDataExplorer);

  /// Widget to open the data explorer page.
  Widget get _uploadedTripsTile => ListTile(
      title: Text("Données envoyées"),
      leading: Icon(Icons.cloud_circle, size: 40),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: openUploadedTrips);

  /// Widget to open the geoFence page.
  Widget get _geoFenceTile => ListTile(
      title: Text("Zones privées"),
      leading: Icon(Icons.security, size: 40),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: openGeoFences);

  /// Widget to choose if synchronisation is enabled over cellular network.
  Widget get _cellularNetworkTile => LoadingSwitchTile<CellularNetworkAllowed>(
        title: const Text('Synchronisation 3G'),
        options: [Text('Wifi uniquement'), Text('Autorisée')],
        secondary: const Icon(Icons.wifi, size: 40),
      );

  /// Widget to display whether the GPS is enabled.
  Widget get _gpsStatusTile => GpsStatusValue();
}

class GpsStatusValue extends StatefulWidget {
  @override
  _GpsStatusValueState createState() => _GpsStatusValueState();
}

class _GpsStatusValueState extends State<GpsStatusValue> {
  @override
  Widget build(BuildContext context) => (Platform.isIOS)
      ? Container()
      : Consumer<GpsStatusNotifier>(
          builder: (context, auth, _) => ListTile(
                title: Text(_gpsStatusTileTitle(auth.value)),
                trailing: Icon((auth.value == GpsStatus.available)
                    ? Icons.done
                    : Icons.not_interested),
              ));

  _gpsStatusTileTitle(GpsStatus value) {
    switch (value) {
      case GpsStatus.systemDisabled:
        return 'GPS: le capteur est éteint';
      case GpsStatus.systemForbidden:
        return 'GPS: autorisation requise';
      case GpsStatus.userDisabled:
        return 'GPS: désactivé';
      case GpsStatus.available:
        return 'GPS: autorisé';
    }
  }
}
