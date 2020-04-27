import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show ByteBuffer, Uint8List;
import 'dart:convert';

import 'package:dio/adapter.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:device_info/device_info.dart';

import '../models.dart' show GeoFence, ModeValue, Trip;
import '../backends/upload_manager.dart' show UploadStatus;
import '../boundaries/preferences_provider.dart' show UidStore;

/// Status of the Uploader.
enum UploaderStatus {
  offline, ready, uploading
}

typedef UploadDataBuilder = Future<UploadData> Function();

/// Information about a new trip to upload.
class Upload {
  /// Trip being uploaded.
  Trip t;

  /// End of [t].
  DateTime tripEnd;

  /// Notifier used to communicate the status of this upload.
  ValueNotifier<UploadStatus> notifier;

  /// Items to upload for trip [t].
  List<UploadDataBuilder> items;

  Upload(this.t, this.tripEnd, this.notifier) : items = [];
}

/// Data to be uploaded (usually sensor's data).
class UploadData {
  String tag;
  int contentLength;
  Stream<List<int>> content;

  UploadData(this.tag, this.contentLength, this.content);
}

/// Container for server and client SSL certificates.
class Certificates {
  Uint8List serverCA;
  Uint8List clientKey;
  Uint8List clientCA;
  List<String> allowedPem;

  static Future<Certificates> get() async {
    var serverCA = await rootBundle.load('assets/certificates/server-ca.pem');
    var clientKey = await rootBundle.load('assets/certificates/client.key');
    var clientCA = await rootBundle.load('assets/certificates/client.pem');

    var pemText = await rootBundle.loadString('assets/certificates/public-keys.txt');
    var pemList = pemText.split('\n').where((line) => line.trim().isNotEmpty);
    var pemsFuture = pemList.map((path) {
      var assetPath = 'assets/certificates/public-keys/$path';
      return rootBundle.loadString(assetPath);
    });
    var pems = await Future.wait(pemsFuture);

    var c = Certificates();
    c.serverCA = _convert(serverCA);
    c.clientKey = _convert(clientKey);
    c.clientCA = _convert(clientCA);
    c.allowedPem = pems;
    return c;
  }

  static Uint8List _convert(ByteData data) {
    ByteBuffer buffer = data.buffer;
    return buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Uploader object used to synchronize data with the server.
class Uploader {
  /// Store where to fetch/persist application's UID.
  UidStore uidStore;

  /// [UploaderStatus] of this Uploader.
  var status = ValueNotifier(UploaderStatus.offline);

  /// [Dio] instance used for http requests.
  Future<Dio> _dio;

  Uploader(this.uidStore) {
    _dio = Certificates.get().then((certs) {
      var context = SecurityContext(withTrustedRoots: false);
      context.usePrivateKeyBytes(certs.clientKey);
      context.useCertificateChainBytes(certs.clientCA);

      // Prefer to use trusted CA
      // but on iOS self-signed CA not working
      // so, also use badCertificateCallback with server's public key pinning
      context.setTrustedCertificatesBytes(certs.serverCA);

      var dio = Dio();
      var adapter = dio.httpClientAdapter as DefaultHttpClientAdapter;
      adapter.onHttpClientCreate = (HttpClient client) {
        var client = HttpClient(context: context);

        // Public key pinning if the CA was rejected (because of bug on iOS)
        client.badCertificateCallback = (X509Certificate cert, host, int port) {
          final ok = certs.allowedPem.any((pem) => pem == cert.pem);
          print('[Uploader] request triggered badCertificateCallback'
                ', certificate accepted: $ok'
          );
          return ok;
        };
        return client;
      };
      dio.httpClientAdapter = adapter;
      return dio;
    });
  }

  /// Starts this [Uploader], establishes connection to server.
  Future<void> start() async {
    var localUid = await uidStore.getLocalUid();
    if (localUid == null) {
      status.value = UploaderStatus.offline;
      return;
    }

    var uid = await uidStore.getUid();
    if (uid == null) {
      await register();
      return;
    }

    var dio = await _dio;
    print('[Uploader] Sending connection request to server');
    await dio.get(await _helloUrl, options: Options(
      sendTimeout: 300,
      receiveTimeout: 300,
    )).then((r) {
      print('[Uploader] Connection request success, back online.');
      status.value = UploaderStatus.ready;
    }).catchError((e) {
      print('[Uploader] Connection request failed, Uploader offline.');
      print(e);
      status.value = UploaderStatus.offline;
    });
  }

  /// Register this application to get the app's UID.
  Future<void> register() async {
    var dio = await _dio;
    var deviceInfo = await _deviceInfo;
    var localUid = await uidStore.getLocalUid();

    if (localUid == null) {
      print('[Uploader] local uid is null, using empty string');
      localUid = '';
    }

    await dio.post(await _registerUrl,
      data: FormData.fromMap({
        'uid': localUid,
        'info': deviceInfo
      }),
      options: Options(
        sendTimeout: 300,
        receiveTimeout: 300,
      )).then((r) async {
        var uid = r.data['uid'];
        if (uid != null) {
          print('[Uploader] Register request success, uid is: $uid');
          uidStore.setUid(uid);
          status.value = UploaderStatus.ready;
        } else
          throw Exception('Register failed.');
      }).catchError((e) {
        print('[Uploader] Register request failed, Uploader offline.');
        print(e);
        status.value = UploaderStatus.offline;
      });
  }

  /// Uploads [geoFences].
  Future<bool> uploadGeoFences(List<GeoFence> geoFences) async {
    status.value = UploaderStatus.uploading;

    var dio = await _dio;
    var uid = await uidStore.getUid();

    var data = {
      "uid": uid,
      "data": geoFences.map((fence) => {
          'latitude': fence.latitude,
          'longitude': fence.longitude,
          'radiusInMeters': fence.radiusInMeters,
      }).toList(),
    };

    try {
      var r = await dio.post(await _geofencesUrl, data: data,);
      status.value = UploaderStatus.ready;
      return true;
    } on Exception catch (e) {
        print(e);
        status.value = UploaderStatus.offline;
        return false;
    }
  }

  /// Uploads the trip and data contained in [data].
  Future<bool> upload(Upload data) async {
    status.value = UploaderStatus.uploading;
    data.notifier.value = UploadStatus.uploading;
    print('[Uploader] Starting upload of ${data.t}');

    var cancelled = false;
    var error = false;

    if (!error) {
      for (var item in data.items) {
        UploadData itemData = await item();
        if (itemData == null)
          continue;
        CancelToken token = CancelToken();
        data.notifier.addListener(token.cancel);
        await _post(
            data, itemData, token, () => cancelled = true, () => error = true);
        data.notifier.removeListener(token.cancel);
        if (cancelled || error)
          break;
      }
    }

    if (cancelled) {
      print('[Uploader] Cancelled: Upload of ${data.t}');
      status.value = UploaderStatus.ready;
    } else if (error) {
      print('[Uploader] Error: Upload of ${data.t}');
      data.notifier.value = UploadStatus.error;
      status.value = UploaderStatus.offline;
    } else {
      print('[Uploader] Success: Upload of ${data.t}');
      data.notifier.value = UploadStatus.uploaded;
      status.value = UploaderStatus.ready;
    }

    return !cancelled && !error;
  }

  /// Helper function for a POST request.
  Future<Response> _post(Upload item, UploadData itemData, CancelToken token, Function onCancel, Function onError) async {
    var dio = await _dio;
    var uid = await uidStore.getUid();
    var formData = FormData.fromMap({
      "mode": item.t.mode.value,
      "start": item.t.start.millisecondsSinceEpoch,
      "end": item.tripEnd.millisecondsSinceEpoch,
      "uid": uid,
      "data": MultipartFile(itemData.content, itemData.contentLength, filename:itemData.tag),
    });
    return dio.post(
      await _uploadUrl,
      data: formData,
      cancelToken: token,
    ).catchError((e) {
      if (e is DioError) {
        switch (e.type) {
          case DioErrorType.CANCEL:
            onCancel();
            break;
          case DioErrorType.RESPONSE:
          case DioErrorType.CONNECT_TIMEOUT:
          default:
            print(e);
            onError();
            break;
        }
      }
    });
  }

  /// Platform-specific information about the smartphone.
  Future<String> get _deviceInfo async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo info = await deviceInfo.androidInfo;
      return jsonEncode({
        'platform':'android',
        'androidId':info.androidId,
        'board':info.board,
        'brand':info.brand,
        'device':info.device,
        'host':info.host,
        'physical': info.isPhysicalDevice,
        'manufacturer': info.manufacturer,
        'model': info.model,
        'tags': info.tags,
        'version': info.version.release,
        'sdk': info.version.sdkInt,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo info = await deviceInfo.iosInfo;
      return jsonEncode({
        'platform':'ios',
        'uuid': info.identifierForVendor,
        'physical': info.isPhysicalDevice,
        'model': info.model,
        'name': info.name,
        'system': info.systemName,
        'systemVersion': info.systemVersion,
        'machine': info.utsname.machine,
        'release': info.utsname.release,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return jsonEncode({
      'platform': 'unknown',
      'time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Server's hostname
  Future<String> _host = () async {
    var encoded = await rootBundle.loadString('assets/server-info.json');
    var info = json.decode(encoded);
    return 'https://${info["domain"]}:${info["port"]}';
  }();

  Future<String> get _geofencesUrl async => '${await _host}/geofences';
  Future<String> get _uploadUrl async => '${await _host}/upload';
  Future<String> get _helloUrl async => '${await _host}/hello';
  Future<String> get _registerUrl async => '${await _host}/register';
}