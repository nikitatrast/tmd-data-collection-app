import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../backends/gps_auth.dart';
import '../boundaries/location_provider.dart' show LocationData;
import '../widgets/modes_view.dart';
import '../widgets/map_widget.dart';
import '../widgets/gps_auth_tile.dart';

abstract class TripRecorderBackend {
  Future<bool> start(Mode tripMode);
  Future<bool> save();
  void cancel();
  void dispose();
  Stream<LocationData> locationStream();
}

class TripRecorderPage extends StatefulWidget {
  final Mode mode;
  final Function exit;
  final Function recorderBuilder;

  TripRecorderPage({
    @required this.mode,
    @required this.exit,
    @required this.recorderBuilder,
  });

  @override
  State<StatefulWidget> createState() => TripRecorderPageState();
}

class TripRecorderPageState extends State<TripRecorderPage> {
  TripRecorderBackend recorder;
  DateTime createdTime;

  @override
  void initState() {
    super.initState();
    recorder = widget.recorderBuilder();
    recorder.start(widget.mode);
    createdTime = DateTime.now();
  }

  Future<bool> onSave() async {
    return recorder.save();
  }

  Future<bool> onCancel() async {
    recorder.cancel();
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    recorder.dispose(); // make sure recorder's resources are released!
  }

  Widget noGPSPane() {
    return Column(mainAxisSize: MainAxisSize.max, children: [
      Container(
          padding: EdgeInsets.only(top: 20, bottom: 10),
          child: Text('Enregistrement en cours',
              style: TextStyle(fontSize: 30.0))),
      Container(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
              'Début du trajet : ' +
                  createdTime.toString().split('.').first.split(' ').last,
              style: TextStyle(fontSize: 20.0))),
      Expanded(child: Center(child: Icon(widget.mode.iconData, size: 200))),
      GpsAuthTile(),
    ]);
  }

  Widget mainPane(BuildContext context) {
    return Consumer<GPSAuth>(builder: (context, auth, _) {
      if (auth.value == true) {
        return Column(children: [
          Expanded(child: MapWidget(recorder.locationStream())),
          GpsAuthTile(),
        ]);
      } else {
        return noGPSPane();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('[TripRecorderWidget] building UI');
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(children: [
                Icon(widget.mode.iconData),
                Container(
                    padding: EdgeInsets.only(left: 10),
                    child: Text(widget.mode.text))
              ]),
            ),
            body: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: mainPane(context),
                  ),
                  ButtonBar(
                    children: <Widget>[
                      RaisedButton(
                        child: Text('Enregistrer ce trajet'),
                        color: Colors.blue,
                        onPressed: () => saveDialog(context),
                      ),
                      OutlineButton(
                        child: Text('Effacer ce trajet'),
                        onPressed: () => cancelDialog(context),
                      ),
                    ],
                  )
                ])));
  }

  void cancelDialog(BuildContext context) {
    Widget cancelButton = FlatButton(
      child: Text("Non"),
      onPressed: () => Navigator.of(context).pop(),
    );
    Widget continueButton = FlatButton(
        child: Text("Oui, effacer."),
        onPressed: () {
          onCancel().then((value) {
            Navigator.of(context).pop(); // pop dialog
            widget.exit();
          });
        });
    AlertDialog alert = AlertDialog(
      title: Text("Confirmation"),
      content: Text("Voulez-vous vraiment effacer les données de ce trajet ?"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void saveDialog(BuildContext context) {
    Widget cancelButton = FlatButton(
      child: Text("Non"),
      onPressed: () => Navigator.of(context).pop(),
    );
    Widget continueButton = FlatButton(
        child: Text("Oui, enregistrer."),
        onPressed: () {
          Navigator.of(context).pop(); // pop dialog
          saveAndExit(context);
        });
    AlertDialog alert = AlertDialog(
      title: Text("Confirmation"),
      content: Text("Voulez-vous vraiment enregistrer ce trajet ? Les données seront transmises au server. Assurez-vous que le mode de transport est correctement renseigné."),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void saveAndExit(BuildContext context) {
    AlertDialog alert = AlertDialog(
      title: Text("Enregistrement"),
      content: Text("Enregistrement des données..."),
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
    onSave().then((value) {
      Navigator.of(context, rootNavigator: true).pop(); // pop dialog
      widget.exit();
    });
  }
}
