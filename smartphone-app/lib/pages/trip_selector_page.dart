import 'package:flutter/material.dart';
import '../models.dart' show Mode;
import '../widgets/modes_view.dart';

class TripSelectorPage extends StatelessWidget {
  final List<Mode> modes;
  final Map<Mode, Function> actions;
  final Function settingsAction;

  TripSelectorPage({this.modes, this.actions, this.settingsAction});

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
              onTap: actions[m],
            )
        ],
      ),
    );
  }
}