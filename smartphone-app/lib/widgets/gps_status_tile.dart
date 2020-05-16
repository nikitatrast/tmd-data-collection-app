import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tmd/backends/gps_status.dart';
import 'package:tmd/boundaries/location_permission.dart';
import 'package:tmd/widgets/gps_pref_tile.dart';


class GpsStatusTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LocationPermission>(
      builder: (context, perm, _) => _GpsStatusTile(perm)
    );
  }
}

class _GpsStatusTile extends StatefulWidget {
  final LocationPermission permission;

  _GpsStatusTile(this.permission);

  @override
  _GpsStatusTileState createState() => _GpsStatusTileState();
}


class _GpsStatusTileState extends State<_GpsStatusTile> {
  Widget get _title => Text('Utilisation du GPS');
  Widget get _trailing => Icon(Icons.arrow_forward_ios);
  Widget get _leading => Icon(Icons.map, size: 40);

  @override
  void initState() {
    super.initState();
    widget.permission.updateStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GpsStatusNotifier>(
      builder: (context, status, _) {
        switch (status.value) {
          case GpsStatus.systemDisabled:
            return _disabled(context);
          case GpsStatus.systemForbidden:
            return _notAllowed(context);
          case GpsStatus.available:
          case GpsStatus.userDisabled:
            return enabledAndAllowed;
          default:
            return _loading;
        }
      });
  }

  Widget get _loading => ListTile(
    title: _title,
    subtitle: Text('chargement...'),
    leading: _leading,
    trailing: _trailing,
    onTap: null,
  );

  Widget _asWarning(BuildContext context, String subtitleText) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: subtitleText),
        TextSpan(text: '  '),
        WidgetSpan(
          child: Icon(
            Icons.warning,
            size: 15,
            color: Theme.of(context).colorScheme.error,),
          alignment: PlaceholderAlignment.middle,
        ),
      ],
    )
  );

  Widget _disabled(BuildContext context) => ListTile(
    title: _title,
    leading: _leading,
    trailing: _trailing,
    subtitle: _asWarning(context, 'GPS désactivé'),
    onTap: widget.permission.request,
  );

  Widget _notAllowed(BuildContext context) => ListTile(
    title: _title,
    leading: _leading,
    trailing: _trailing,
    subtitle: _asWarning(context, "GPS: autorisation requise"),
    onTap: () async {
      LocationSystemStatus p = await widget.permission.request();
      if (p != LocationSystemStatus.allowed) {
        _openSettingsDialog();
      }
    }
  );

  Widget get enabledAndAllowed =>
      GpsPrefTile();

  _openSettingsDialog() => showDialog(
    context: context,
    builder: (context) =>
      AlertDialog(
        title: Text('Utilisation du GPS'),
        content: Text(
            'Aller dans les réglages pour autoriser l\'application a utiliser le GPS'),
        actions: [
          RaisedButton(
            child: Text('ANNULER'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          RaisedButton(
            child: Text('OK'),
            onPressed: () async {
              var p = widget.permission;
              Navigator.of(context).pop();
              await p.openSettings();
              p.updateStatus();
            },
          )
        ]
      )
  );
}
