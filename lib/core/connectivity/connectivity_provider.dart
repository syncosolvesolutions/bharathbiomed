import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current connectivity state immediately, then again whenever it
/// changes. Purely informational — the app never gates functionality on
/// this (see [features/catalog/catalog_controller.dart] for why: catalog
/// data always comes from the local cache, network is only used on demand).
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  debugPrint('connectivityProvider: checking current connectivity');
  final initial = await Connectivity().checkConnectivity();
  debugPrint('connectivityProvider: initial connectivity=$initial');
  yield initial;
  debugPrint('connectivityProvider: subscribing to connectivity change stream');
  yield* Connectivity().onConnectivityChanged;
});

/// Human-readable helpers for a [ConnectivityResult] list, grouped here so
/// call sites (e.g. the login screen's status label) don't repeat the
/// same result-list matching logic.
class NetworkStatus {
  NetworkStatus._();

  static bool isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.contains(ConnectivityResult.none);

  static String describe(List<ConnectivityResult> results) {
    if (isOffline(results)) return 'No available network types';
    if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi available';
    if (results.contains(ConnectivityResult.mobile)) return 'Mobile network available';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet connection available';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN connection active';
    if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth connection available';
    if (results.contains(ConnectivityResult.other)) return 'Connected to an unknown network';
    return 'Unknown network status';
  }
}
