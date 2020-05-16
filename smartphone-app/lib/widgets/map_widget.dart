import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:provider/provider.dart';

import '../boundaries/data_store.dart' show GeoFenceStore;
import '../models.dart' show GeoFence, LocationData;

/// Widget to display recorded GPS locations during a trip.
class MapWidget extends StatefulWidget {

  /// Input stream of [LocationData] recorded during the trip.
  final Stream<LocationData> stream;

  MapWidget(this.stream);

  @override
  State<MapWidget> createState() => MapWidgetState();
}

/// Indicates how the [MapWidget] should be centered.
enum ViewMode {
  /// Show the whole trip in the [MapWidget].
  trip,

  /// Center the [MapWidget] on the current user location.
  center,

  /// Do not programmatically center the [MapWidget].
  free
}

class MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  MapController mapController;
  LatLngBounds bounds;
  List<Marker> markers;
  LatLng lastLocation;
  bool inForeground;
  ViewMode viewMode;
  StreamSubscription subscription;

  MapWidgetState();

  @override
  void initState() {
    super.initState();
    print('[MapWidget] initState()');
    WidgetsBinding.instance.addObserver(this);
    viewMode = ViewMode.trip;
    mapController = MapController();
    bounds = LatLngBounds();
    markers = [];
    this.inForeground = true;
    subscription?.cancel(); // initState may be called multiple times!
    subscription = widget.stream
        .listen((v) => newLocation(v.latitude, v.longitude, v.altitude));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('[MapWidget] dispose()');
    var s = subscription;
    subscription = null;
    s?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      print('[MapWidget] going into background ${this.hashCode} / ${subscription.hashCode}');
      this.inForeground = false;
    } else if (state == AppLifecycleState.resumed) {
      print('[MapWidget] going into foreground ${this.hashCode} / ${subscription.hashCode}');
      this.inForeground = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[MapWidget] building UI');
    return Stack(children: [
      Consumer<GeoFenceStore>(
          builder: (context, store, _) =>
            FutureBuilder(
              future: store.geoFences(),
              builder: (context, snap) {
                return FlutterMap(
                  mapController: mapController,
                  options: new MapOptions(
                    center: new LatLng(46.526977, 6.629825),
                    onPositionChanged: _onPositionChanged,
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
                  ] + ((!snap.hasData || snap.data == null) ? [] : [
                    CircleLayerOptions(
                      circles: (snap.data as List<GeoFence>).map((fence) =>
                        CircleMarker(
                          point: LatLng(fence.latitude, fence.longitude),
                          radius: fence.radiusInMeters,
                          useRadiusInMeter: true,
                          color: Color.fromRGBO(0, 0, 0, 0.5),
                        )).toList()
                    )
                  ]),
                );
              },
            )
      ),
      Positioned(
        bottom: 5,
        right: 5,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          FloatingActionButton(
              onPressed: () {
                if (viewMode == ViewMode.center) {
                  viewMode = ViewMode.free;
                } else {
                  centerView();
                }
              },
              backgroundColor:
                  viewMode == ViewMode.center ? Theme.of(context).colorScheme.primary : Colors.white,
              elevation: viewMode == ViewMode.center ? 0 : 6,
              child: Icon(Icons.navigation,
                  color: viewMode == ViewMode.center
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary),
              heroTag: 'centerView',
              mini: true),
          SizedBox(height: 5, width: 5),
          FloatingActionButton(
              onPressed: () {
                if (viewMode == ViewMode.trip) {
                  viewMode = ViewMode.free;
                } else {
                  fullTripView();
                }
              },
              backgroundColor:
                  viewMode == ViewMode.trip ? Theme.of(context).colorScheme.primary : Colors.white,
              elevation: viewMode == ViewMode.trip ? 0 : 6,
              child: Icon(Icons.zoom_out_map,
                  color:
                      viewMode == ViewMode.trip ? Colors.white : Theme.of(context).colorScheme.primary),
              heroTag: 'fulltripView',
              mini: true),
        ]),
      )
    ]);
  }

  /// Centers the [FlutterMap] on [lastLocation].
  void centerView() {
    mapController.move(lastLocation, 16.0);
    if (viewMode != ViewMode.center)
      setState(() => viewMode = ViewMode.center);
  }

  /// Scales the [FlutterMap] to display the whole trip.
  void fullTripView() {
    if (markers.length < 2) {
      mapController.move(lastLocation, 16.0);
      return;
    }
    mapController.fitBounds(
      bounds,
      options: FitBoundsOptions(
        padding: EdgeInsets.only(left: 10, right: 25),
      ),
    );
    if (viewMode != ViewMode.trip) setState(() => viewMode = ViewMode.trip);
  }

  /// Enables [ViewMode.free] if user moved the map by hand.
  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (hasGesture) {
      setState(() => viewMode = ViewMode.free);
    }
  }

  /// Builds the first marker put on the map.
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

  /// Builds a marker representing a location during the trip.
  Marker middleMarker(LatLng point) {
    return Marker(
      width: 1.0,
      height: 1.0,
      point: point,
      builder: (ctx) => Opacity(
          opacity: 1,
          child: Icon(Icons.trip_origin, size: 15, color: Theme.of(context).colorScheme.primary)),
    );
  }

  /// Builds the marker used for the last recorded position.
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

  /// Adds the new location to the [FlutterMap] (re-centering it if needed).
  void newLocation(double latitude, double longitude, double altitude) {
    // Avoid overlapping markers with this simple rule.
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

    if (viewMode == ViewMode.trip) {
      fullTripView();
    } else if (viewMode == ViewMode.center) {
      centerView();
    }
  }
}
