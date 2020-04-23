import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../boundaries/preferences_provider.dart'
    show GPSPrefNotifier, GPSPref;

import '../widgets/gps_pref_view.dart';

class GpsAuthTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      // We need the GPS running on iOS to be able to record data in the background
      // => don't show this tile to make sure user can't disable the GPS.
      // note: an option would be to allow choosing the power_save precision
      return Container();

    } else
      return Consumer<GPSPrefNotifier>(
        builder: (context, auth, _) => ListTile(
          title: const Text('Utilisation du GPS'),
          subtitle: Text(auth.value?.displayName ?? 'chargement...'),
          leading: const Icon(Icons.map, size: 40),
          onTap: () => showDialog(
              context: context,
              builder: (BuildContext context) => SimpleDialog(
                    title: const Text('Utilisation du GPS'),
                    children: [
                      for (var option in GPSPref.values)
                        Container(
                          padding: EdgeInsets.only(bottom: 0),
                          child: SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, option),
                            child: RichText(
                              text: TextSpan(
                                //style: DefaultTextStyle.of(context).style,
                                children: [
                                  WidgetSpan(child: Icon(option.icon)),
                                  TextSpan(
                                      text: '  ' + option.displayName,
                                      style: TextStyle(
                                        color: Colors.black,
                                      )
                                      //style: DefaultTextStyle.of(context).style
                                      )
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )).then((choice) => auth.value = choice ?? auth.value),
        ),
      );
  }
}
