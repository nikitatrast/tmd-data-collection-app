import 'package:accelerometertest/boundaries/data_store.dart';
import 'package:accelerometertest/pages/explorer_page.dart';
import '../models.dart' show Sensor;

class ExplorerBackendImpl implements ExplorerBackend {
  DataStore _store;

  ExplorerBackendImpl(this._store);

  @override
  Future<bool> delete(ExplorerItem item) {
    return _store.delete(item);
  }

  @override
  Future<List<ExplorerItem>> items() async {
    return Future.wait((await _store.trips()).map((trip) async {
      var info = await _store.getInfo(trip);
      return ExplorerItem()
        ..mode = trip.mode
        ..start = trip.start
        ..end = info.end
        ..sizeOnDisk = info.sizeOnDisk
        ..nbSensors = info.nbSensors;
    }).map((fitem) async {
      var item = await fitem;
      assert(item.start != null);
      assert(item.end != null);
      return item;
    }));
  }

  @override
  Future<int> nbEvents(ExplorerItem item, Sensor s) {
    return _store.nbEvents(item, s);
  }
}