import 'package:flutter/material.dart';

import '../boundaries/data_store.dart' show GeoFenceStore;
import '../pages/geofence_picker_page.dart';
import '../models.dart' show GeoFence;

/// Displays the list of [GeoFence]s.
class GeoFencePage extends StatefulWidget {
  final GeoFenceStore store;

  GeoFencePage(this.store);

  @override
  _GeoFencePageState createState() => _GeoFencePageState();
}

class _GeoFencePageState extends State<GeoFencePage> {
  /// Set of [GeoFence]s that are displayed with a checked checkbox.
  Set<GeoFence> _selected = Set();

  /// [GeoFence]s to display.
  List<GeoFence> _geoFences;

  /// Used to be able to call [showSnackBar] on
  /// the displayed [Scaffold] instance.
  var _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    loadGeoFences();
  }

  /// Loads [GeoFence]s from the [GeoFenceStore].
  Future<void> loadGeoFences() async {
    var f = await widget.store.geoFences();
    setState(() => _geoFences = f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Zones privées'),
      ),
      body: body,
      floatingActionButton: (_selected.isEmpty)
        ? FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () => openGeoFencePicker(context),
        )
        : FloatingActionButton(
          child: Icon(Icons.delete),
          onPressed: deleteSelected,
        ),
    );
  }

  /// Opens a page to create a new [GeoFence]
  /// then stores the result in the [GeoFenceStore].
  void openGeoFencePicker(BuildContext context) async {
    var fence = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GeoFencePickerPage(
        title: "Nouvelle zone privée",
        existingGeoFences: _geoFences,
      )
    ));
    if (fence == null) {
      showSnackBar("Action annulée");
    } else {
      showSnackBar("Enregistrement en cours, veuillez patienter.", seconds: 60*60);
      var ok = await widget.store.saveGeoFences(_geoFences + [fence]);
      if (ok) {
        showSnackBar("Enregistrement réussi");
        setState(() => _geoFences.add(fence));
      } else {
        showSnackBar("Erreur lors de l'enregistrement");
      }
    }
  }

  /// Asks the [GeoFenceStore] to delete the [GeoFence]s in [_selected].
  void deleteSelected() async {
    showSnackBar("Suppression en cours, veuillez patienter.", seconds: 60*60);
    var remaining = _geoFences.where((f) => !_selected.contains(f));
    var ok = await widget.store.saveGeoFences(remaining);
    if (ok) {
      setState(() {
        _geoFences = remaining.toList();
        _selected.clear();
      });
      showSnackBar("Opération réussie");
    } else {
      await loadGeoFences();
      showSnackBar("Erreur lors de la suppression");
    }

  }

  /// Displays a [SnackBar] notification with [text] as content.
  ///
  /// Note: hides previous [SnackBar] if there was still one displayed.
  void showSnackBar(String text, {int seconds = 4}) {
    _scaffoldKey.currentState.hideCurrentSnackBar();
    _scaffoldKey.currentState.showSnackBar(
        SnackBar(content: Text(text), duration: Duration(seconds: seconds))
    );
  }

  Widget get body {
    if (_geoFences == null) {
      return SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(height:20),
            Text('Chargement des zones privées...',
            style: Theme.of(context).textTheme.title,),
            descriptionWidget(context),
            Container(height: 20),
            Container(
              width: 100,
              height: 100,
              child: CircularProgressIndicator()
            )
          ]
        ),
      );
    }
    else if (_geoFences.isEmpty) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(height:20),
            Text('Aucune zone privée enregistrée',
              style: Theme.of(context).textTheme.title,),
            descriptionWidget(context)
          ]
      );
    }
    else {
      return ListView(
        children: [
          for (var fence in _geoFences)
            CheckboxListTile(
              title: Text(fence.description),
              subtitle: Text('${fence.latitude.toStringAsFixed(7)}, ${fence.longitude.toStringAsFixed(7)}, ${fence.radiusInMeters}m'),
              secondary: Icon(Icons.location_on, size: 40),
              onChanged: (value) {
                if (value)
                  setState(() => _selected.add(fence));
                else
                  setState(() => _selected.remove(fence));
              },
              value: _selected.contains(fence)
            ),
        ]);
    }
  }
}

/// Explanation of what a [GeoFence] is.
final String descriptionText =
    "Votre géoposition à l'intérieur d'une zone privée ne sera pas publiée.\n"
    "Utilisez une zone privée pour dissimuler votre domicile ou lieu de travail par exemple.";

/// Widget to display [descriptionText].
Widget descriptionWidget(context) => Padding(
    padding: EdgeInsets.only(top: 50, left: 30, right: 30),
    child: Text(descriptionText,
      style: Theme.of(context).textTheme.body1, )
);