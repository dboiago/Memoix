import 'dart:convert';

import '../../features/recipes/models/recipe.dart';
import '../privacy/pii_scrubber.dart';

/// Represents a single data point for the future Culinary Intelligence pipeline.
///
/// A [KnowledgePayload] captures a complete [Recipe] — including personal notes,
/// ingredient-level details, and quality signals such as [Recipe.isFavourite] —
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

  /// Stable identity hash — frozen on first transmission.
  final String lineageHash;

  /// Full-content hash — recomputed on every transmission for deduplication.
  final String contentHash;

  /// Resolved paired recipes. Each entry has 'name', 'course', and 'hash'
  /// (SHA-256 of name+course). Populated by [RagTelemetryService] before
  /// payload construction; empty when no pairings exist or resolution fails.
  final List<Map<String, String>> pairedRecipes;

  const KnowledgePayload({
    required this.recipe,
    this.rawSource,
    required this.metadata,
    required this.lineageHash,
    required this.contentHash,
    required this.pairedRecipes,
  });

  /// Serialises the payload for transmission.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'domainType': 'recipe',
      'recipe': {
        'lineage_hash': lineageHash,
        'content_hash': contentHash,
        'name': recipe.name,
        'course': recipe.course,
        'cuisine': recipe.cuisine,
        'serves': recipe.serves,
        'time': recipe.time,
        'isFavourite': recipe.isFavourite,
        'rating': recipe.rating,
        'cookCount': recipe.cookCount,
        'source': recipe.source.name,
        'tags': recipe.tags,
        'comments': recipe.comments != null ? PiiScrubber.scrub(recipe.comments!) : null,
        'directions': recipe.directions,
        'ingredients': recipe.ingredients
            .map((i) => {
                  'name': i.name,
                  'amount': i.amount,
                  'unit': i.unit,
                  'notes': i.preparation != null ? PiiScrubber.scrub(i.preparation!) : null,
                  'isOptional': i.isOptional,
                  'section': i.section,
                })
            .toList(),
        'nutrition': recipe.nutrition?.toJson(),
        'pairedRecipes': pairedRecipes,
        'recipeType': recipe.recipeType,
        'modernistType': recipe.modernistType,
        'smokingType': recipe.smokingType,
        if (recipe.glass != null) 'glass': recipe.glass,
        if (recipe.garnish.isNotEmpty) 'garnish': recipe.garnish,
        if (recipe.pickleMethod != null) 'pickleMethod': recipe.pickleMethod,
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

