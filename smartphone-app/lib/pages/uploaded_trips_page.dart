import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/trip_tile.dart';

enum UploadedTripsBackendStatus { loading, error, loaded }

class UploadedTripsPageData {
  UploadedTripsBackendStatus status;
  List<SavedTrip> trips;
  String message;
}

abstract class UploadedTripsBackend {
  Stream<UploadedTripsPageData> get data;
}

class UploadedTripsPage extends StatefulWidget {
  final UploadedTripsBackend backend;

  @override
  _UploadedTripsPageState createState() => _UploadedTripsPageState();

  UploadedTripsPage(this.backend);
}

class _UploadedTripsPageState extends State<UploadedTripsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Données envoyées au serveur'),
      ),
      body: Builder(builder: this._body),
    );
  }

  Widget _body(BuildContext context) {
    return StreamBuilder<UploadedTripsPageData>(
        stream: widget.backend.data,
        builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('[UploadedTripsPage] snapshot has error');
              print(snapshot.error);
              return _errorText("");
            }
            if (!snapshot.hasData) {
              print('[UploadedTripsPage] snapshot has no data');
              return _loadingText;
            }
            print('[UploadedTripsPage] snapshot has data');

            UploadedTripsBackendStatus status = snapshot.data.status;
            List<SavedTrip> trips = snapshot.data.trips;

            switch (status) {
              case UploadedTripsBackendStatus.loading:
                return _loadingText;
              case UploadedTripsBackendStatus.error:
                return _errorText(snapshot.data.message);
              case UploadedTripsBackendStatus.loaded:
                if (trips == null) return _loadingText;
                if (trips.isEmpty) return _emptyText;
                return _listing(trips);
              default:
                throw Exception('Not implemented');
            }
          },
    );
  }

  Widget _textPage(title, content) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(height:20),
          Text(title, style: Theme.of(context).textTheme.title,),
          Padding(
              padding: EdgeInsets.only(top: 50, left: 30, right: 30),
              child: Text(content, style: Theme.of(context).textTheme.body1)
          )
        ]
    );

  Widget get _loadingText => _textPage(
      "Chargement en cours...",
      "Assurez-vous d'être connecté à internet.",
  );

  Widget _errorText([String message]) => _textPage(
    "Impossible de contacter le serveur",
    "Assurez-vous d'être connecté à internet et ré-essayez plus tard."
      + ((message != null) ? ("\n\n" + message) : "")
  );

  Widget get _emptyText => _textPage(
    "Le serveur n'a encore reçu aucun trajet",
      "Seulement les trajets envoyés avec cette version de l'application"
          " s'affichent ici. Si vous avez envoyé des trajets avec une autre"
          " version de l'application, c'est normal qu'ils ne soient pas"
          " visibles.\n\n"
          "Aller dans l'onglet \"Données locales\" pour voir"
          " les trajets en cours d'envoi."
  );

  Widget _listing(List<SavedTrip> items) =>
      Column(mainAxisSize: MainAxisSize.max, children: [
        Expanded(
            child: ListView(
          children: <Widget>[
            for (var item in items)
              SavedTripTile(item),
          ],
        ))
      ]);
}
