import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:tmd/backends/gps_status.dart';
import 'package:tmd/widgets/gps_status_tile.dart';

import '../models.dart';
import '../widgets/modes_view.dart';
import '../widgets/map_widget.dart';

/// Backend to provide data to [TripRecorderPage].
abstract class TripRecorderBackend {
  Future<bool> start(Mode tripMode);
  Future<bool> save();
  void cancel();
  void dispose();
  void toBackground() {}
  void toForeground() {}
  Stream<LocationData> locationStream();
}

/// Page to record sensor's data during a trip.
class TripRecorderPage extends StatefulWidget {
  /// Travel mode of the current [Trip].
  final Mode mode;

  /// Callback used to open a new page when this page exits.
  final void Function() onExit;

  final TripRecorderBackend backend;

  TripRecorderPage({
    @required this.mode,
    @required this.onExit,
    @required this.backend,
  });

  @override
  State<StatefulWidget> createState() => TripRecorderPageState();
}

class TripRecorderPageState extends State<TripRecorderPage> with WidgetsBindingObserver {
  TripRecorderBackend recorder;
  DateTime createdTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    recorder = widget.backend;
    recorder.start(widget.mode);
    createdTime = DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      print('[TripRecorderPage] going into background');
      recorder.toBackground();
    } else if (state == AppLifecycleState.resumed) {
      print('[TripRecorderPage] going into foreground');
      recorder.toForeground();
    }
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
    recorder.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget mainPane(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.max, children: [
      if (widget.mode == Mode.test)
        Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          child: Row(
            children: [
              Icon(Icons.help_outline, size: 30,),
              Container(width: 5),
              Flexible(
                  //width: MediaQuery.of(context).size.width,
                  child: Text('Vous pouvez utiliser ce mode pour découvrir l\'application, les données ne seront pas gardées sur le serveur.')
              ),
            ]
          ),
        ),
      Expanded(
          child: Consumer<GpsStatusNotifier>(builder: (context, status, _) {
        switch (status.value) {
          case GpsStatus.userDisabled:
            return noGPSPane(context);
          case GpsStatus.systemDisabled:
          case GpsStatus.systemForbidden:
            if (Platform.isIOS)
              return noGPSPaneIOS(context);
            return noGPSPane(context);
          case GpsStatus.available:
          default:
            return MapWidget(recorder.locationStream());
        }
      })),
      GpsStatusTile(),
    ]);
  }

  Widget noGPSPane(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 10),
      child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Expanded(child: Center(child: Icon(widget.mode.iconData, size: 200))),
        Container(
            padding: EdgeInsets.only(left: 10, top: 20, bottom: 20),
            child: Text(
                'Début du trajet : ' +
                    createdTime.toString().split('.').first.split(' ').last,
                style: TextStyle(fontSize: 20.0))),
        Container(
            padding: EdgeInsets.only(left: 10),
            child: Text(
                'Le GPS est désactivé.',
                style: TextStyle(fontSize: 20.0))),
        Container(
            padding: EdgeInsets.only(top: 5, left: 10, bottom: 10),
            child: Text(
                'Vous pouvez l\'activer ci dessous.',
                style: TextStyle(fontSize: 15.0))),
      ]),
    );
  }

  Widget noGPSPaneIOS(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 10),
      child: Column(
          mainAxisSize: MainAxisSize.max,
          //crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: Icon(widget.mode.iconData, size: 200))),
            Container(
                padding: EdgeInsets.only(left: 10, top: 20, bottom: 20),
                child: Text(
                    'Début du trajet : ' +
                        createdTime.toString().split('.').first.split(' ').last,
                    style: TextStyle(fontSize: 20.0))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: MarkdownBody(
                data: iosNeedsGpsText,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
              ),
            )
          ]),
    );
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
                    child: Text('Enregistrement en cours'))
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
                        color: Theme.of(context).colorScheme.primary,
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
            widget.onExit();
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
      content: Text(
          "Voulez-vous vraiment enregistrer ce trajet ? Les données seront transmises au server. Assurez-vous que le mode de transport est correctement renseigné."),
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
      widget.onExit();
    });
  }

  final String iosNeedsGpsText = """
# Attention


Sur iOS, le seul moyen pour l'application de collecter des données lorsque
l'application n'est pas au premier plan ou que votre écran est verrouillé
est d'utiliser le mode GPS. Pour cette raison, l'autorisation d'utiliser votre
GPS est nécessaire.


Si vous ne souhaitez pas activer le GPS, assurez-vous que l'application reste
ouverte et désactiver le verrouillage automatique de l'écran.


Vous pouvez activer le GPS ci-dessous.
""".replaceAll(RegExp(r' *\n(?!\n) *'), " ");
}