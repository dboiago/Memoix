import 'dart:convert';

import 'integrity_service.dart';

// Reference data service for archived session entries.
// Merges the persisted base list with any locally registered configuration entry.
class SessionIndexService {
  SessionIndexService._();

  static const _guestRefKey = 'cfg_session_token';

  /// Returns all entries from the seating index, with the locally registered
  /// entry appended if one is present in the persistent store.
  static Future<List<Map<String, dynamic>>> getEntries() async {
    final entries = <Map<String, dynamic>>[];

    final seating = await IntegrityService.resolveSeatingData();
    if (seating != null) entries.addAll(seating);

    final local = await getLocalEntry();
    if (local != null) entries.add(local);

    return entries;
  }

  /// Returns the locally registered entry from the persistent store, or null
  /// if no entry has been recorded for this installation.
  static Future<Map<String, dynamic>?> getLocalEntry() async {
    final raw = IntegrityService.store.getString(_guestRefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
