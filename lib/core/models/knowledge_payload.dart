import 'dart:convert';

import '../../features/recipes/models/recipe.dart';

/// Represents a single data point for the future Culinary Intelligence pipeline.
///
/// A [KnowledgePayload] captures a complete [Recipe] \u2014 including personal notes,
/// ingredient-level details, and quality signals such as [Recipe.isFavorite] \u2014
/// alongside the raw source text that produced it and contextual metadata.
///
/// Payloads are only ever constructed after both the master privacy switch and
/// the individual [Recipe.isShared] flag are confirmed to be enabled.
class KnowledgePayload {
  /// The fully hydrated recipe object.
  final Recipe recipe;

  /// The original raw text that was parsed to produce [recipe].
  /// May be OCR output, URL-scraped HTML, a deep-link string, or typed text.
  /// Null when the recipe was created or edited manually without an import source.
  final String? rawSource;

  /// Contextual metadata added at export time.
  /// Includes at minimum: 'deviceLocale' and 'appVersion'.
  final Map<String, String> metadata;

  const KnowledgePayload({
    required this.recipe,
    this.rawSource,
    required this.metadata,
  });

  /// Serialises the payload for inspection via [debugPrint].
  ///
  /// NOTE: No network call is made here. This method only produces a JSON
  /// string so the structure can be validated in the console before a
  /// backend is wired up.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'recipe': {
        'uuid': recipe.uuid,
        'name': recipe.name,
        'course': recipe.course,
        'cuisine': recipe.cuisine,
        'serves': recipe.serves,
        'time': recipe.time,
        'isFavourite': recipe.isFavorite,
        'rating': recipe.rating,
        'cookCount': recipe.cookCount,
        'source': recipe.source.name,
        'tags': recipe.tags,
        'comments': recipe.comments,
        'directions': recipe.directions,
        'ingredients': recipe.ingredients
            .map((i) => {
                  'name': i.name,
                  'amount': i.amount,
                  'unit': i.unit,
                  'notes': i.preparation,
                  'isOptional': i.isOptional,
                  'section': i.section,
                })
            .toList(),
        'nutrition': recipe.nutrition?.toJson(),
        'pairedRecipeIds': recipe.pairedRecipeIds,
        'recipeType': recipe.recipeType,
        'modernistType': recipe.modernistType,
        'smokingType': recipe.smokingType,
        'isShared': recipe.isShared,
        'createdAt': recipe.createdAt.toUtc().toIso8601String(),
        'updatedAt': recipe.updatedAt.toUtc().toIso8601String(),
      },
      'rawSource': rawSource,
      'metadata': metadata,
    };
  }

  /// Returns a pretty-printed JSON string suitable for [debugPrint].
  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
