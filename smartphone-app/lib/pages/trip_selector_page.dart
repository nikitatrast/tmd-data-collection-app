import 'package:flutter/material.dart';
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
        title: Text('Nouveau trajet'),
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
      body: ListView(
        children: <Widget>[
          for (var m in modes)
            ListTile(
              leading: Icon(m.iconData, size: 30),
              title: Text(m.text),
              onTap: () => modeSelected(m),
            )
        ],
      ),
    );
  }
}