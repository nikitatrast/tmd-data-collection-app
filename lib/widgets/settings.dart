import 'package:flutter/material.dart';
import 'async_switch_tile.dart';

abstract class SettingsBackend {
  Future<bool> setGPSValue(bool value);
  Future<bool> getGPSValue();
  Future<bool> set3GValue(bool value);
  Future<bool> get3GValue();
}

class Settings extends StatelessWidget {
  final SettingsBackend backend;
  final Function dataExplorer;

  Settings(this.backend, this.dataExplorer);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Réglages'),
      ),
      body: ListView(
        children: ListTile.divideTiles(
            context: context,
            tiles: [
              AsyncSwitchTile(
                title: const Text('Activer le GPS'),
                subtitle: const Text('Autoriser la collecte des données de géolocalisation.'),
                secondary: const Icon(Icons.map),
                setValue: backend.setGPSValue,
                getValue: backend.getGPSValue
              ),
              AsyncSwitchTile(
                title: const Text('Synchronisation 3G'),
                subtitle: const Text("Utiliser le réseau 3G ou 4G pour synchroniser les données."),
                secondary: const Icon(Icons.wifi),
                setValue: backend.set3GValue,
                getValue: backend.get3GValue
              ),
              ListTile(
                title: Text("Afficher les données enregistrées"),
                leading: Icon(Icons.insert_drive_file),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: dataExplorer
              )
            ]
        ).toList(),
      ),
    );
  }
}