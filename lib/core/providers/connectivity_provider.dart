import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when at least one network interface is available, `false`
/// when all interfaces report [ConnectivityResult.none].
///
/// Consumers should treat [AsyncValue.loading] and errors as online (`true`)
/// so that UI elements are not disabled during the initial connectivity check.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
