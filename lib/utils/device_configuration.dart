import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Provides a stable configuration reference across sessions.
// Used to maintain consistent runtime identity without requiring
// a user account or network round-trip.
class DeviceConfiguration {
  DeviceConfiguration._();

  static const _runtimeIdKey = 'config_runtime_id';
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns the stable runtime identifier for this installation.
  ///
  /// On first call a UUID v4 is generated and persisted locally.
  /// Subsequent calls return the stored value unchanged.
  static Future<String> getRuntimeId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_runtimeIdKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    // Attempt to derive a device-anchored seed so the ID remains stable
    // across reinstalls on the same hardware where prefs survive.
    final deviceSeed = await _resolveDeviceSeed();
    final generated = deviceSeed ?? const Uuid().v4();

    await prefs.setString(_runtimeIdKey, generated);
    return generated;
  }

  /// Returns [digits] numeric characters extracted from [getRuntimeId()] starting at [offset].
  ///
  /// Useful as a lightweight numeric configuration reference that remains
  /// consistent for the lifetime of the installation.
  static Future<int> getNumericSeed({int digits = 2, int offset = 0}) async {
    final id = await getRuntimeId();
    final numeric = id.replaceAll(RegExp(r'[^0-9]'), '');
    final start = offset.clamp(0, numeric.length - digits);
    return int.parse(numeric.substring(start, start + digits));
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Attempts to read a hardware-level identifier to produce a reproducible
  /// UUID string. Returns null if the platform does not expose one.
  static Future<String?> _resolveDeviceSeed() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final raw = info.id; // build fingerprint component, not a user ID
        if (raw.isNotEmpty) return _uuidFromSeed(raw);
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        final raw = info.identifierForVendor;
        if (raw != null && raw.isNotEmpty) return raw; // already UUID-shaped
      }
    } catch (_) {
      // Platform APIs unavailable — fall back to random generation.
    }
    return null;
  }

  /// Deterministically converts an arbitrary string into a UUID v4-formatted
  /// string by hashing its characters into the required byte positions.
  static String _uuidFromSeed(String seed) {
    // Fill 16 bytes from the seed's char codes, wrapping as needed.
    final bytes = List<int>.generate(16, (i) => seed.codeUnitAt(i % seed.length));

    // Apply RFC 4122 variant/version bits for a v4-shaped UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
