import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models.dart' show GeoFence;

class GeoFencePickerPage extends StatefulWidget {
  final String title;
  final List<GeoFence> existingGeoFences;

  GeoFencePickerPage({this.title, existingGeoFences})
  : existingGeoFences = existingGeoFences ?? [];

  @override
  _GeoFencePickerPageState createState() => _GeoFencePickerPageState();
}

class _GeoFencePickerPageState extends State<GeoFencePickerPage> {
  static const double _RADIUS = 200;

  MapController mapController;
  TextEditingController textController;
  LatLng _position;
  Future<Position> _currentPosition;
  var _scaffoldKey = GlobalKey<ScaffoldState>();
  List<CircleMarker> existingFences;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    textController = TextEditingController();
    _currentPosition = Geolocator().getLastKnownPosition();
    existingFences = widget.existingGeoFences.map((fence) =>
        CircleMarker(
          point: LatLng(fence.latitude, fence.longitude),
          radius: fence.radiusInMeters,
          useRadiusInMeter: true,
          color: Color.fromRGBO(0, 0, 0, 0.4),
        )
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(title: Text(widget.title)),
        body: Stack(children: [
          FutureBuilder(
            future: _currentPosition,
            builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: Container(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator()
                  ));

                var center = LatLng(46.526977, 6.629825);
                if (snapshot.data != null)
                  center = LatLng(snapshot.data.latitude, snapshot.data.longitude);

                return FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: center,
                    zoom: 16.0,
                    onTap: _handleTap,
                  ),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                      subdomains: ['a', 'b', 'c'],
                      tileProvider: CachedNetworkTileProvider(),
                    ),
                    MarkerLayerOptions(markers: (_position == null) ? [] : [
                      Marker(
                        point: _position,
                        builder: (context) => Icon(Icons.pin_drop),
                      )
                    ]),
                    CircleLayerOptions(circles: (_position == null)
                        ? existingFences
                        : existingFences + [
                      CircleMarker(
                        point: _position,
                        radius: _RADIUS,
                        useRadiusInMeter: true,
                        color: Color.fromRGBO(0, 0, 0, 0.5),
                      )
                    ])
                  ],
                );
            }
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
                width: MediaQuery.of(context).size.width,
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: TextField(
                        controller: textController,
                        autofocus: false,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(40)),
                          ),
                          hintText: "Addresse: 01 rue de l'Exemple, 1007 Lausanne",
                          suffixIcon: Icon(Icons.search),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        )))),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child:
            ButtonBar(
              children: <Widget>[
                RaisedButton(
                  child: Text('Enregistrer'),
                  color: Colors.blue,
                  onPressed: () => _saveAndExit(context)
                ),
                RaisedButton(
                  child: Text('Annuler'),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            )
          )
        ]));
  }

  void _handleTap(LatLng position) {
    setState(() => _position = position);
  }

  void _search(String address) async {
    try {
      List<Placemark> marks = await Geolocator().placemarkFromAddress(address);
      var mark = marks.first;
      var pos = LatLng(mark.position.latitude, mark.position.longitude);
      setState(() {
        _position = pos;
        mapController.move(pos, 16);
      });
    } on PlatformException catch(e) {
      if (e.code == 'ERROR_GEOCODNG_ADDRESSNOTFOUND') {
        _scaffoldKey.currentState.showSnackBar(
          SnackBar(content: Text('Addresse introuvable'))
        );
      } else {
        print(e);
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(content: Text('Fonction indisponible sur votre appareil'))
        );
      }
    }
  }

  Future<void> _saveAndExit(BuildContext context) async {
    if (_position == null) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Cliquez sur la carte pour choisir une position')
      ));
      return;
    }

    var controller = TextEditingController();
    if (textController.text != null && textController.text.trim().isNotEmpty)
      controller.text = textController.text;
    else {
      try {
        List<Placemark> pms = await Geolocator().placemarkFromCoordinates(
            _position.latitude,
            _position.longitude,
            localeIdentifier: 'fr-FR');
        if (pms.isNotEmpty) {
          var pm = pms.first;
          controller.text =
              '${pm.subThoroughfare} ${pm.thoroughfare}, ${pm.postalCode} ${pm
                  .locality}, ${pm.country}'.trim();
        }
      } on PlatformException catch(e) {
        print(e);
      }
    }

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        content: new Row(
          children: <Widget>[
            new Expanded(
              child: new TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                decoration: new InputDecoration(
                  labelText: 'Description', hintText: 'exemple: "Maison"',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    tooltip: 'Close',
                    onPressed: () {
                      controller.text = '';
                    },
                  )
                ),
              ),
            )
          ],
        ),
        actions: <Widget>[
          new FlatButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.pop(context);
              }),
          new FlatButton(
              child: const Text('Enregistrer'),
              onPressed: () {
                Navigator.pop(context); //pop dialog
                Navigator.pop(context, GeoFence(
                  _position.latitude,
                  _position.longitude,
                  _RADIUS,
                   controller.text,
                ));
              })
        ],
      ),
    );
  }
}
