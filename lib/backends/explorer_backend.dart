import 'package:accelerometertest/boundaries/data_store.dart';
import 'package:accelerometertest/backends/upload_manager.dart';
import 'package:accelerometertest/pages/explorer_page.dart';
import '../models.dart' show Sensor;

class ExplorerBackendImpl implements ExplorerBackend {
  DataStore _store;
  UploadManager _uploader;

  ExplorerBackendImpl(this._store, this._uploader);

  @override
  Future<bool> delete(ExplorerItem item) {
    return _store.delete(item);
  }

  @override
  Future<List<ExplorerItem>> items() async {
    var trips = await _store.trips();
    var infos = await Future.wait(trips.map(_store.getInfo));
    infos = infos.where((i) => i != null).toList();
    return infos.map((i) =>
      ExplorerItem()
        ..mode = i.trip.mode
        ..start = i.trip.start
        ..end = i.end
        ..sizeOnDisk = i.sizeOnDisk
        ..nbSensors = i.nbSensors
        ..status = _uploader.status(i.trip)).toList();
  }

  @override
  Future<int> nbEvents(ExplorerItem item, Sensor s) {
    return _store.nbEvents(item, s);
  }

  @override
  void scheduleUpload(ExplorerItem item) {
    _uploader.scheduleUpload(item);
  }

  @override
  void cancelUpload(ExplorerItem item) {
    _uploader.cancelUpload(item);
  }
}