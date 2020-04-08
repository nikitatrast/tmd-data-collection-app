import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show ByteBuffer, Uint8List;
import 'dart:convert';

import 'package:dio/adapter.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:slugify/slugify.dart';
import 'package:device_info/device_info.dart';

import '../models.dart' show Trip, ModeValue;
import '../backends/upload_manager.dart' show UploadStatus;
import '../boundaries/preferences_provider.dart' show UidStore;

const HOST = 'https://192.168.1.143:4430';
const UPLOAD_URL = '$HOST/upload';
const HELLO_URL = '$HOST/hello';
const REGISTER_URL = '$HOST/register';

enum UploaderStatus {
  offline, ready, uploading
}

typedef UploadDataBuilder = Future<UploadData> Function();

class Upload {
  Trip t;
  DateTime tripEnd;
  ValueNotifier<UploadStatus> notifier;
  List<UploadDataBuilder> items;

  Upload(this.t, this.tripEnd, this.notifier) : items = [];
}

class UploadData {
  String tag;
  int contentLength;
  Stream<List<int>> content;

  UploadData(this.tag, this.contentLength, this.content);
}

class Certificates {
  Uint8List serverCA;
  Uint8List clientKey;
  Uint8List clientCA;

  static Future<Certificates> get() async {
    var serverCA = await ((Platform.isAndroid)
        ? rootBundle.load('assets/certificates/CA.pem')
        : rootBundle.load('assets/certificates/CA.der'));
    var clientKey = await rootBundle.load('assets/certificates/client.key');
    var clientCA = await rootBundle.load('assets/certificates/client.pem');

    var c = Certificates();
    c.serverCA = _convert(serverCA);
    c.clientKey = _convert(clientKey);
    c.clientCA = _convert(clientCA);
    return c;
  }

  static Uint8List _convert(ByteData data) {
    ByteBuffer buffer = data.buffer;
    return buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

class Uploader {
  UidStore uidStore;
  var status = ValueNotifier(UploaderStatus.offline);
  Future<Dio> _dio;


  Uploader(this.uidStore) {
    var context = Certificates.get().then((certs) {
      var context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(certs.serverCA);
      context.usePrivateKeyBytes(certs.clientKey);
      context.useCertificateChainBytes(certs.clientCA);
      return context;
    });

    _dio = context.then((context) {
      var dio = Dio();
      var adapter = dio.httpClientAdapter as DefaultHttpClientAdapter;
      adapter.onHttpClientCreate = (HttpClient client) {
        var client = HttpClient(context: context);
        return client;
      };
      dio.httpClientAdapter = adapter;
      return dio;
    });
  }

  Future<void> start() async {
    print('[Uploader] Sending connection request to server');
    var dio = await _dio;
    var uid = await uidStore.getUid();

    if (uid == null) {
      await register();
    } else {
      await dio.get(HELLO_URL, options: Options(
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
  }

  Future<void> register() async {
    var dio = await _dio;
    var deviceInfo = await _deviceInfo;
    var localUid = await uidStore.getLocalUid();

    if (localUid == null) {
      print('[Uploader] local uid is null, using empty string');
      localUid = '';
    }

    await dio.post(REGISTER_URL,
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
      UPLOAD_URL,
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

}