import 'dart:convert';

import '../../features/cellar/models/cellar_entry.dart';
import '../database/app_database.dart' show CellarEntry;

/// RAG telemetry payload for a [CellarEntry].
///
/// Cellar is a beverage log (wines, spirits, beers), not a recipe — it has no
/// ingredients, directions, or pairings. The payload captures the descriptive
/// and sensory fields that are useful for the Culinary Intelligence pipeline.
///
/// UUID and timestamps are excluded. Personal-only fields (isFavourite, buy,
/// imageUrl) are excluded.
class CellarKnowledgePayload {
  final CellarEntry entry;
  final String? rawSource;
  final Map<String, String> metadata;

  /// Stable identity hash: SHA-256 of name + producer + category.
  /// Set on first transmission and frozen thereafter.
  final String lineageHash;

  /// Full-content hash: SHA-256 of all descriptive fields.
  /// Recomputed on every transmission for deduplication.
  final String contentHash;

  const CellarKnowledgePayload({
    required this.entry,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'cellar',
      'entry': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': entry.name,
        'producer': entry.producer,
        'category': entry.category,
        'tastingNotes': entry.tastingNotes,
        'abv': entry.abv,
        'ageVintage': entry.ageVintage,
        'priceRange': entry.priceRange,
        'source': entry.source,
        'isFavourite': entry.isFavourite,
      },
      'rawSource': rawSource,
      'metadata': metadata,
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
