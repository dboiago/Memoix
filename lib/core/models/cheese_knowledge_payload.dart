import 'dart:convert';

import '../../features/cheese/models/cheese_entry.dart';
import '../database/app_database.dart' show CheeseEntry;

/// RAG telemetry payload for a [CheeseEntry].
///
/// Cheese is a reference catalogue (not a recipe) — it has no ingredients,
/// directions, or pairings. The payload captures the classification and
/// sensory fields that are useful for the Culinary Intelligence pipeline.
///
/// UUID and timestamps are excluded. Personal-only fields (isFavourite, buy,
/// imageUrl) are excluded.
class CheeseKnowledgePayload {
  final CheeseEntry entry;
  final String? rawSource;
  final Map<String, String> metadata;

  /// Stable identity hash: SHA-256 of name + country + milk + type.
  /// Set on first transmission and frozen thereafter.
  final String lineageHash;

  /// Full-content hash: SHA-256 of all descriptive fields.
  /// Recomputed on every transmission for deduplication.
  final String contentHash;

  const CheeseKnowledgePayload({
    required this.entry,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'cheese',
      'entry': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': entry.name,
        'country': entry.country,
        'milk': entry.milk,
        'texture': entry.texture,
        'type': entry.type,
        'flavour': entry.flavour,
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
