import 'dart:async';

import 'package:tmd/boundaries/uploader.dart';
import 'package:tmd/pages/uploaded_trips_page.dart';

import '../models.dart';

class UploadedTripsBackendImpl extends UploadedTripsBackend {
  Uploader _uploader;

  UploadedTripsBackendImpl(this._uploader);

  Stream<UploadedTripsPageData> get data {
    return _uploader.uploadedTripsInfo().map((GetResponse event) {
      var result = UploadedTripsPageData();
      switch (event.status) {
        case GetRequestStatus.loading:
          result.status = UploadedTripsBackendStatus.loading;
          return result;
        case GetRequestStatus.error:
          result.status = UploadedTripsBackendStatus.error;
          return result;
        case GetRequestStatus.loaded:
          result.trips = event.data as List<SavedTrip>;
          result.status = UploadedTripsBackendStatus.loaded;
          return result;
        default:
          throw Exception('Not implemented');
      }
    });
  }
}