import 'dart:async';
import 'package:connectivity/connectivity.dart' as plugin;
import 'package:flutter/cupertino.dart';

/// Information about device's network connection status.
enum ConnectivityStatus { mobile, wifi, none, unknown }

/// Provides [ConnectivityStatus] of this device.
class ConnectivityNotifier extends ValueNotifier<ConnectivityStatus> {
  StreamSubscription _subscription;

  ConnectivityNotifier()
      : super(ConnectivityStatus.unknown) {
    // first get current connectivity value
    plugin.Connectivity().checkConnectivity().then((v) {
      if (this.value == ConnectivityStatus.unknown) {
        this.value = _convert(v);
      }
    });
    // then listen for updates
    _subscription = plugin.Connectivity().onConnectivityChanged.listen((v) {
      this.value = _convert(v);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

ConnectivityStatus _convert(plugin.ConnectivityResult event) {
  switch (event) {
    case plugin.ConnectivityResult.none:
      return ConnectivityStatus.none;
    case plugin.ConnectivityResult.wifi:
      return ConnectivityStatus.wifi;
    case plugin.ConnectivityResult.mobile:
      return ConnectivityStatus.mobile;
    default:
      return null;
  }
}
