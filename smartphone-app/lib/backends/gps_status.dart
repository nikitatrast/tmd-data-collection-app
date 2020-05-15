import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foreground_service/foreground_service.dart';
import '../backends/gps_pref_result.dart';
import '../boundaries/location_permission.dart';
import '../backends/message_handler.dart';

enum GpsStatus {
  systemDisabled, systemForbidden, userDisabled, available
}

extension GpsStatusValue on GpsStatus {
  String get value => this.toString().split('.')[1];
  static fromValue(String value) => GpsStatus.values.firstWhere((v) => v.value == value);
}

class GpsStatusProvider implements MessageHandler {
  GPSPrefResult _userPref;
  LocationPermission _systemPref;
  var status = ValueNotifier<GpsStatus>(GpsStatus.systemDisabled);

  GpsStatusProvider(this._userPref, this._systemPref) {
    _systemPref.status.addListener(() => _update(_systemPref.status.value));
    _userPref.addListener(() => _update(null));
    forceUpdate();
  }

  Future<void> forceUpdate() {
    return _update(null);
  }

  Future<void> _update(LocationSystemStatus systemValue) async {
    if (systemValue != null) {
      switch (_systemPref.status.value) {
        case LocationSystemStatus.disabled:
          status.value = GpsStatus.systemDisabled;
          break;
        case LocationSystemStatus.denied:
          status.value = GpsStatus.systemForbidden;
          break;
        case LocationSystemStatus.allowed:
          if (_userPref.value == true) {
            status.value = GpsStatus.available;
          } else {
            status.value = GpsStatus.userDisabled;
          }
          break;
      }
    }
    else {
      if (_userPref.value == true) {
        var sysValue = await _systemPref.request();
        print('GpsStatus._update => sysValue = $sysValue, userPref = ${_userPref.value}');
        await _update(sysValue);
      } else {
        status.value = GpsStatus.userDisabled;
      }
    }
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['method'] == 'GpsStatusProvider.forceUpdate') {
      print('[GpsStatus] forceUpdate() received');
      await this.forceUpdate();
      print('[GpsStatus] forceUpdate() completed');
      ForegroundService.sendToPort({
        'methodResult': 'GpsStatusProvider.forceUpdate',
        'key': message['key'],
      });
      return true;

    } else if (message['method'] == 'GpsStatusProvider.status') {
      ForegroundService.sendToPort({
        'methodResult': 'GpsStatusProvider.status',
        'result': this.status.value.value,
        'key': message['key'],
      });
      return true;
    //} else if (message['method'] == 'GpsStatusProvider.requestAuth') {
    //  print('[GpsStatus] requestAuth() received');
    //  await this.requestAuth();
    //  print('[GpsStatus] requestAuth() completed');
    //  ForegroundService.sendToPort({
    //    'methodResult': 'GpsStatusProvider.requestAuth',
    //    'key': message['key'],
    //  });
    //  return true;
    }
    return false;
  }

  void sendValueToPort() {
      ForegroundService.sendToPort({
        'methodResult': 'GpsStatusProvider.status',
        'result': this.status.value.value,
        'key': null,
      });
  }
}

class IsolateGpsStatusProvider implements GpsStatusProvider, MessageHandler{
  @override
  LocationPermission _systemPref;

  @override
  GPSPrefResult _userPref;

  @override
  var status = ValueNotifier<GpsStatus>(GpsStatus.systemDisabled);

  @override
  Future<void> _update(LocationSystemStatus systemValue) {
    throw UnimplementedError();
  }

  Map<int, Completer> _responses = {};

  @override
  Future<void> forceUpdate() async {
    int key = DateTime.now().millisecondsSinceEpoch;
    _responses[key] = Completer();
    ForegroundService.sendToPort({
      'method': 'GpsStatusProvider.forceUpdate',
      'key': key,
    });
    await _responses[key].future;
  }

  @override
  Future<bool> handleMessage(Map message) async {
    if (message['methodResult'] == 'GpsStatusProvider.status') {
      status.value = GpsStatusValue.fromValue(message['result']);
      _responses[message['key']]?.complete();
      return true;

    } else if (message['methodResult'] == 'GpsStatusProvider.forceUpdate') {
      _responses[message['key']]?.complete();
      return true;

    } else if (message['methodResult'] == 'GpsStatusProvider.requestAuth') {
      _responses[message['key']]?.complete();
      return true;
    }
    return false;
  }

  @override
  void sendValueToPort() {
    // TODO: implement sendValueToPort
  }
}