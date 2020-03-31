import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';

import '../models.dart' show Trip;
import '../backends/upload_manager.dart' show UploadStatus;

const UPLOAD_URL = 'http://192.168.1.143:8080/upload';

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

class Uploader {
  var status = ValueNotifier(UploaderStatus.offline);
  Dio _dio = Dio();

  Uploader() {
    _dio.options.connectTimeout = 3 * 60 * 1000; /* ms */
  }

  Future<void> start() async {
    print('[Uploader] Sending connection request to server');
    await _dio.get(UPLOAD_URL, options: Options(
      sendTimeout: 3000,
      receiveTimeout: 3000,
    )).then((r) {
      print('[Uploader] Connection request success, back online.');
      status.value = UploaderStatus.ready;
    }).catchError((e) {
      print('[Uploader] Connection request failed, Uploader offline.');
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
        CancelToken token = CancelToken();
        data.notifier.addListener(token.cancel);
        await _post(
            itemData, token, () => cancelled = true, () => error = true);
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
      data.notifier.value = UploadStatus.pending;
      status.value = UploaderStatus.offline;
    } else {
      print('[Uploader] Success: Upload of ${data.t}');
      data.notifier.value = UploadStatus.uploaded;
      status.value = UploaderStatus.ready;
    }

    return !cancelled && !error;
  }

  Future<Response> _post(UploadData itemData, CancelToken token, Function onCancel, Function onError) {
    return _dio.post(
      UPLOAD_URL,
      data: itemData.content,
      options: Options(
        headers: {
          Headers.contentLengthHeader: itemData.contentLength,
        },
      ),
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
}