import 'dart:convert';

import '../../features/modernist/models/modernist_recipe.dart';

/// RAG telemetry payload for a [ModernistRecipe].
///
/// Carries the full modernist-specific schema including technique, difficulty,
/// equipment list, and science notes. UUID and timestamps are excluded.
class ModernistKnowledgePayload {
  final ModernistRecipe recipe;
  final String? rawSource;
  final Map<String, String> metadata;
  final String lineageHash;
  final String contentHash;
  final List<Map<String, String>> pairedRecipes;

  const ModernistKnowledgePayload({
    required this.recipe,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
    required this.pairedRecipes,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'modernist',
      'recipe': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': recipe.name,
        'course': recipe.course,
        'type': recipe.type.name,
        'technique': recipe.technique,
        'serves': recipe.serves,
        'time': recipe.time,
        'difficulty': recipe.difficulty,
        'equipment': recipe.equipment,
        'ingredients': recipe.ingredients
            .map((i) => {
                  'name': i.name,
                  'amount': i.amount,
                  'unit': i.unit,
                  'notes': i.notes,
                  'section': i.section,
                })
            .toList(),
        'directions': recipe.directions,
        'notes': recipe.notes,
        'scienceNotes': recipe.scienceNotes,
        'source': recipe.source.name,
        'isFavourite': recipe.isFavorite,
        'cookCount': recipe.cookCount,
        'pairedRecipes': pairedRecipes,
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
