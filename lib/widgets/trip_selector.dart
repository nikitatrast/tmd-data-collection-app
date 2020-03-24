import 'package:flutter/material.dart';
import '../models/modes.dart';

class TripSelector extends StatelessWidget {
  final List<Modes> modes;
  final Map<Modes, Function> actions;
  final Function settingsAction;

  TripSelector({this.modes, this.actions, this.settingsAction});

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
              leading: Icon(m.iconData),
              title: Text(m.text),
              onTap: actions[m],
            )
        ],
      ),
    );
  }
}
