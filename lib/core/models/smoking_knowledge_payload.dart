import 'dart:convert';

import '../../features/smoking/models/smoking_recipe.dart';
import '../database/app_database.dart' show SmokingRecipe;

/// RAG telemetry payload for a [SmokingRecipe].
///
/// Carries all smoking-specific fields: item, category, temperature, time,
/// wood, seasonings, and ingredients. UUID and timestamps are excluded.
class SmokingKnowledgePayload {
  final SmokingRecipe recipe;
  final String? rawSource;
  final Map<String, String> metadata;
  final String lineageHash;
  final String contentHash;
  final List<Map<String, String>> pairedRecipes;

  const SmokingKnowledgePayload({
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
      'domainType': 'smoking',
      'recipe': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': recipe.name,
        'course': recipe.course,
        'type': recipe.type,
        'item': recipe.item,
        'category': recipe.category,
        'temperature': recipe.temperature,
        'time': recipe.time,
        'wood': recipe.wood,
        'seasonings': jsonDecode(recipe.seasoningsJson),
        'ingredients': jsonDecode(recipe.ingredientsJson),
        'serves': recipe.serves,
        'directions': jsonDecode(recipe.directions),
        'notes': recipe.notes,
        'source': recipe.source,
        'isFavourite': recipe.isFavourite,
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
