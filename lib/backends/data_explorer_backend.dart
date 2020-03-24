import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/explorer_item.dart';

import '../widgets/data_explorer.dart' show DataExplorerBackend;

class FileSystemExplorerBackend implements DataExplorerBackend {
  Future<Directory> get dataDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final dataDir = Directory(dir.path + '/data');
    return dataDir.create();
  }

  List<FileSystemEntity> dataFiles;
  Set<FileSystemEntity> checkedItems;

  @override
  Future<bool> delete(ExplorerItem item) async {
    var file = item.data as FileSystemEntity;
    try {
      file.deleteSync();
      return true;
    } on Exception catch(e) {
      print(e); // TODO handle this.
      return false;
    }
  }

  @override
  Future<List<ExplorerItem>> getItems() async {
    var items = (await dataDirectory).listSync();
    return items.map((item) {
      var stats = item.statSync();
      return ExplorerItem(
          item.path.split('/').last,
          stats.modified,
          stats.size,
          item
      );
    }).toList();
  }
}
