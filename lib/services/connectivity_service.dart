import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Tracks whether the device has any network connection.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  bool _online = true;

  bool get isOnline => _online;

  static bool _hasNetwork(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  /// Emits the current state, then every change.
  Stream<bool> watch() async* {
    try {
      _online = _hasNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      _online = true;
    }
    yield _online;
    await for (final r in _connectivity.onConnectivityChanged) {
      final next = _hasNetwork(r);
      if (next != _online) {
        _online = next;
        yield next;
      }
    }
  }
}
