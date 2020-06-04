import 'package:flutter/material.dart';
import 'package:tmd/widgets/sync_status_widget.dart';
import '../models.dart' show Mode;
import '../widgets/modes_view.dart';

/// Page to select the travel [Mode] of a new [Trip].
class TripSelectorPage extends StatelessWidget {

  /// [Mode]s to display.
  final List<Mode> modes;

  /// Callback called when a [Mode] in [modes] is selected.
  final void Function(Mode) modeSelected;

  /// Callback called when the settings icon is tapped.
  final void Function() settingsAction;

  TripSelectorPage({this.modes, this.modeSelected, this.settingsAction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commencer un trajet'),
        actions: <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: settingsAction,
                child: Icon(Icons.settings),
              )
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            child: ListView(
              children: <Widget>[
                for (var m in modes)
                  ListTile(
                    leading: m.icon(size: 30),
                    title: Text(m.text),
                    onTap: () => modeSelected(m),
                  )
              ],
            ),
          ),
          Container(
            color: Colors.black87,
            child: Theme(
              data: ThemeData.dark(),
              child: SyncStatusWidget(hideFinished: true, dense: true)
            )
          ),
        ],
      ),
    );
  }
}