import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Domains tracked by the tombstone store.
/// Must match the keys used in [RecipeBundle] JSON.
class TombstoneDomain {
  static const recipes = 'recipes';
  static const pizzas = 'pizzas';
  static const sandwiches = 'sandwiches';
  static const cheeses = 'cheeses';
  static const cellar = 'cellar';
  static const smoking = 'smoking';
  static const modernist = 'modernist';

  static const all = [
    recipes,
    pizzas,
    sandwiches,
    cheeses,
    cellar,
    smoking,
    modernist,
  ];
}

/// A single tombstone record.
class _TombstoneEntry {
  final String uuid;
  final DateTime deletedAt;

  _TombstoneEntry({required this.uuid, required this.deletedAt});

  factory _TombstoneEntry.fromJson(Map<String, dynamic> json) {
    return _TombstoneEntry(
      uuid: json['uuid'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'deletedAt': deletedAt.toUtc().toIso8601String(),
      };
}

/// Persists deleted-item UUIDs so they can be propagated to other devices on
/// the next push.  Entries expire after [_maxAge] to prevent unbounded growth.
///
/// Storage layout (SharedPreferences):
///   Key: `tombstones_<domain>`
///   Value: JSON array of `{ "uuid": "...", "deletedAt": "..." }`
class TombstoneStore {
  static const _prefixKey = 'tombstones_';
  static const _maxAge = Duration(days: 30);

  /// Record a deletion for the given [domain] and [uuid].
  static Future<void> add(String domain, String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _load(prefs, domain);
    // Replace any existing entry for this uuid (idempotent)
    entries.removeWhere((e) => e.uuid == uuid);
    entries.add(_TombstoneEntry(uuid: uuid, deletedAt: DateTime.now().toUtc()));
    await _save(prefs, domain, entries);
  }

  /// Return the live (non-expired) UUIDs for [domain].
  static Future<List<String>> getUuids(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _load(prefs, domain);
    return entries.map((e) => e.uuid).toList();
  }

  /// Return all live tombstones as a map keyed by domain.
  static Future<Map<String, List<String>>> getAll() async {
    final result = <String, List<String>>{};
    for (final domain in TombstoneDomain.all) {
      final uuids = await getUuids(domain);
      if (uuids.isNotEmpty) result[domain] = uuids;
    }
    return result;
  }

  /// Remove tombstones for [uuids] in [domain] after they have been applied on
  /// a pull (so they are not redundantly re-sent on the next push).
  static Future<void> clear(String domain, List<String> uuids) async {
    if (uuids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final entries = await _load(prefs, domain);
    final removing = uuids.toSet();
    entries.removeWhere((e) => removing.contains(e.uuid));
    await _save(prefs, domain, entries);
  }

  // ── private helpers ────────────────────────────────────────────────────────

  static Future<List<_TombstoneEntry>> _load(
      SharedPreferences prefs, String domain) async {
    final raw = prefs.getString('$_prefixKey$domain');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final cutoff = DateTime.now().toUtc().subtract(_maxAge);
      return list
          .map((e) => _TombstoneEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.deletedAt.isAfter(cutoff))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(SharedPreferences prefs, String domain,
      List<_TombstoneEntry> entries) async {
    await prefs.setString(
      '$_prefixKey$domain',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
