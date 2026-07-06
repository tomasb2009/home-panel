import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Tracks live internet reachability while the app runs.
///
/// Rather than only checking for a network interface, it resolves a few
/// well-known hosts on an interval, so it reflects *actual* connectivity
/// (e.g. Wi‑Fi connected but no internet still reads as offline).
class ConnectivityModel extends ChangeNotifier {
  ConnectivityModel();

  static const List<String> _hosts = [
    'one.one.one.one',
    'google.com',
    'cloudflare.com',
  ];
  static const Duration _interval = Duration(seconds: 6);
  static const Duration _lookupTimeout = Duration(seconds: 4);

  bool? _online;

  /// Whether the last check found internet. `false` until the first result.
  bool get online => _online ?? false;

  /// Whether at least one check has completed.
  bool get checked => _online != null;

  Timer? _timer;
  bool _checking = false;

  void start() {
    _check();
    _timer ??= Timer.periodic(_interval, (_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    var result = false;
    for (final host in _hosts) {
      try {
        final records =
            await InternetAddress.lookup(host).timeout(_lookupTimeout);
        if (records.isNotEmpty && records.first.rawAddress.isNotEmpty) {
          result = true;
          break;
        }
      } catch (_) {
        // Try the next host.
      }
    }

    _checking = false;
    if (_online != result) {
      _online = result;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
