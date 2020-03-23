import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class LocationProvider {
  List<MapWidgetState> listeners = [];

  void addListener(MapWidgetState listener) {
    listeners.add(listener);
  }

  void removeListener(MapWidgetState listener) {
    listeners.remove(listener);
  }

  void put(double latitude, double longitude, double altitude) {
    listeners.forEach((l) => l.newLocation(latitude, longitude, altitude));
  }
}

abstract class LocationStreamListener {
  void newLocation(double latitude, double longitude, double altitude);
}

class MapWidget extends StatefulWidget {
  final LocationProvider stream;

  MapWidget(this.stream);

  @override
  State<MapWidget> createState() => MapWidgetState(stream);
}

enum ViewModes { trip, center, free }

class MapWidgetState extends State<MapWidget>
    with LocationStreamListener, WidgetsBindingObserver {
  final LocationProvider locationStream;
  MapController mapController;
  LatLngBounds bounds;
  List<Marker> markers;
  LatLng lastLocation;
  bool inForeground;
  ViewModes viewMode;

  MapWidgetState(this.locationStream);

  void initState() {
    super.initState();
    print('[MapWidget] initState()');
    WidgetsBinding.instance.addObserver(this);
    viewMode = ViewModes.center;
    mapController = MapController();
    bounds = LatLngBounds();
    markers = [];
    this.inForeground = true;
    locationStream.addListener(this);
  }

  void dispose() {
    super.dispose();
    print('[MapWidget] dispose()');
    WidgetsBinding.instance.removeObserver(this);
    locationStream.removeListener(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      print('[MapWidget] going into background');
      this.inForeground = false;
    } else if (state == AppLifecycleState.resumed) {
      print('[MapWidget] going into foreground');
      this.inForeground = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[MapWidget] building UI');
    return Stack(children: [
      FlutterMap(
        mapController: mapController,
        options: new MapOptions(
          center: new LatLng(46.526977, 6.629825),
          zoom: 16.0,
        ),
        layers: [
          TileLayerOptions(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
            subdomains: ['a', 'b', 'c'],
            tileProvider: CachedNetworkTileProvider(),
          ),
          MarkerLayerOptions(markers: markers)
        ],
      ),
      Positioned(
        bottom: 5,
        right: 5,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          FloatingActionButton(
              onPressed: () {
                if (viewMode == ViewModes.center) {
                  viewMode = ViewModes.free;
                } else {
                  viewMode = ViewModes.center;
                  centerView();
                }
              },
              backgroundColor:
                  viewMode == ViewModes.center ? Colors.blue : Colors.white,
              elevation: viewMode == ViewModes.center ? 0 : 6,
              child: Icon(Icons.navigation,
                  color: viewMode == ViewModes.center
                      ? Colors.white
                      : Colors.blue),
              heroTag: 'centerView',
              mini: true),
          SizedBox(height: 5, width: 5),
          FloatingActionButton(
              onPressed: () {
                if (viewMode == ViewModes.trip) {
                  viewMode = ViewModes.free;
                } else {
                  viewMode = ViewModes.trip;
                  fullTripView();
                }
              },
              backgroundColor:
                  viewMode == ViewModes.trip ? Colors.blue : Colors.white,
              elevation: viewMode == ViewModes.trip ? 0 : 6,
              child: Icon(Icons.zoom_out_map,
                  color:
                      viewMode == ViewModes.trip ? Colors.white : Colors.blue),
              heroTag: 'fulltripView',
              mini: true),
        ]),
      )
    ]);
  }

  void centerView() {
    mapController.move(lastLocation, 16.0);
  }

  void fullTripView() {
    mapController.fitBounds(
      bounds,
      options: FitBoundsOptions(
        padding: EdgeInsets.only(left: 10, right: 25),
      ),
    );
  }

  Marker firstMarker(LatLng point) {
    return Marker(
      width: 3.0,
      height: 3.0,
      point: point,
      builder: (ctx) => Opacity(
          opacity: 1,
          child: Icon(
            Icons.pin_drop,
            size: 15,
            //color: Colors.blue
          )),
    );
  }

  Marker middleMarker(LatLng point) {
    return Marker(
      width: 1.0,
      height: 1.0,
      point: point,
      builder: (ctx) => Opacity(
          opacity: 1,
          child: Icon(Icons.trip_origin, size: 15, color: Colors.blue)),
    );
  }

  Marker lastMarker(LatLng point) {
    return Marker(
      width: 3.0,
      height: 3.0,
      point: point,
      builder: (ctx) => Opacity(
          opacity: 1,
          child: Icon(
            Icons.person_pin_circle,
            size: 15,
            //color: Colors.blue
          )),
    );
  }

  @override
  void newLocation(double latitude, double longitude, double altitude) {
    print('[MapWidget] location received: $latitude, $longitude');

    if (lastLocation != null &&
        (((lastLocation.latitude - latitude).abs() < 0.0001) ||
            ((lastLocation.longitude - longitude).abs() < 0.0001))) {
      return;
    }
    lastLocation = LatLng(latitude, longitude);
    bounds.extend(lastLocation);

    if (markers.isEmpty) {
      markers.add(firstMarker(lastLocation));
    } else if (markers.length == 1) {
      markers.add(middleMarker(lastLocation));
    } else {
      markers.last = middleMarker(markers.last.point);
      markers.add(lastMarker(lastLocation));
    }

    if (viewMode == ViewModes.trip) {
      fullTripView();
    } else if (viewMode == ViewModes.center) {
      centerView();
    }
  }
}
