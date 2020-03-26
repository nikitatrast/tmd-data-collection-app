import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';

class GpsAuthTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<GPSPrefNotifier>(
      builder: (context, auth, _) => ListTile(
        title: const Text('Autoriser l\'utilisation du GPS'),
        subtitle: Text(auth.value?.displayName ?? 'loading...'),
        leading: const Icon(Icons.map, size: 40),
        onTap: () => showDialog(
            context: context,
            builder: (BuildContext context) => SimpleDialog(
              title: const Text('Activer le GPS'),
              children: [
                for (var option in GPSPref.values)
                  Container(
                    padding: EdgeInsets.only(bottom: 0),
                    child: SimpleDialogOption(
                      onPressed: () =>
                          Navigator.pop(context, option),
                      child: RichText(
                        text: TextSpan(
                          //style: DefaultTextStyle.of(context).style,
                          children: [
                            WidgetSpan(
                                child: Icon(
                                    option.icon)),
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