import 'dart:convert';

import '../../features/pizzas/models/pizza.dart';
import '../database/app_database.dart' show Pizza;

/// RAG telemetry payload for a [Pizza].
///
/// Carries base sauce, cheeses, proteins, vegetables, and tags.
/// UUID and timestamps are excluded.
class PizzaKnowledgePayload {
  final Pizza pizza;
  final String? rawSource;
  final Map<String, String> metadata;
  final String lineageHash;
  final String contentHash;

  const PizzaKnowledgePayload({
    required this.pizza,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'pizza',
      'recipe': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': pizza.name,
        'base': pizza.base,
        'cheeses': jsonDecode(pizza.cheeses),
        'proteins': jsonDecode(pizza.proteins),
        'vegetables': jsonDecode(pizza.vegetables),
        'notes': pizza.notes,
        'tags': jsonDecode(pizza.tags),
        'source': pizza.source,
        'isFavourite': pizza.isFavourite,
        'cookCount': pizza.cookCount,
        'rating': pizza.rating,
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
