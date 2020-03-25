import 'dart:async';
import 'package:connectivity/connectivity.dart' as plugin;
import 'package:flutter/cupertino.dart';
import '../models.dart' show Connectivity;

class ConnectivityProvider {
  ValueNotifier<Connectivity> get notifier => _ConnectivityAdaptor(_source);

  var _source = plugin.Connectivity();
}

class _ConnectivityAdaptor extends ValueNotifier<Connectivity> {
  StreamSubscription _subscription;

  _ConnectivityAdaptor(plugin.Connectivity source)
      : super(Connectivity.unknown) {
    // first get current connectivity value
    source.checkConnectivity().then((v) {
      if (this.value == Connectivity.unknown) {
        this.value = _convert(v);
      }
    });
    // then listen for updates
    _subscription = source.onConnectivityChanged.listen((v) {
      this.value = _convert(v);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

Connectivity _convert(plugin.ConnectivityResult event) {
  switch (event) {
    case plugin.ConnectivityResult.none:
      return Connectivity.none;
    case plugin.ConnectivityResult.wifi:
      return Connectivity.wifi;
    case plugin.ConnectivityResult.mobile:
      return Connectivity.mobile;
    default:
      return null;
  }
}
