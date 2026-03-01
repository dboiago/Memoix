import 'dart:convert';

import 'package:flutter/services.dart';

import 'integrity_service.dart';

// Reference data service for archived reservations.
// Merges the persisted base list with any locally registered configuration entry.
class ReservationService {
  ReservationService._();

  static const _guestRefKey = 'cfg_session_token';

  /// Returns all entries from the base asset list, with the locally registered
  /// entry appended if one is present in the persistent store.
  static Future<List<Map<String, dynamic>>> getReservations() async {
    final entries = <Map<String, dynamic>>[];

    try {
      final raw = await rootBundle.loadString('assets/reservations.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        entries.addAll(
          decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {
      // Asset unavailable or unparseable — continue with local entry only.
    }

    final local = await getGuestEntry();
    if (local != null) entries.add(local);

    return entries;
  }

  /// Returns the locally registered entry from the persistent store, or null
  /// if no entry has been recorded for this installation.
  static Future<Map<String, dynamic>?> getGuestEntry() async {
    final raw = IntegrityService.store.getString(_guestRefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
