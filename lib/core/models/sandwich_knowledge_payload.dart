import 'dart:convert';

import '../../features/sandwiches/models/sandwich.dart';
import '../database/app_database.dart' show Sandwich;

/// RAG telemetry payload for a [Sandwich].
///
/// Carries bread, proteins, vegetables, cheeses, condiments, and tags.
/// UUID and timestamps are excluded.
class SandwichKnowledgePayload {
  final Sandwich sandwich;
  final String? rawSource;
  final Map<String, String> metadata;
  final String lineageHash;
  final String contentHash;

  const SandwichKnowledgePayload({
    required this.sandwich,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'sandwich',
      'recipe': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': sandwich.name,
        'bread': sandwich.bread,
        'proteins': jsonDecode(sandwich.proteins),
        'vegetables': jsonDecode(sandwich.vegetables),
        'cheeses': jsonDecode(sandwich.cheeses),
        'condiments': jsonDecode(sandwich.condiments),
        'notes': sandwich.notes,
        'tags': jsonDecode(sandwich.tags),
        'source': sandwich.source,
        'isFavourite': sandwich.isFavorite,
        'cookCount': sandwich.cookCount,
        'rating': sandwich.rating,
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
