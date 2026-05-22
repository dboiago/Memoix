import 'dart:typed_data';

import '../../../recipes/models/recipe.dart';
import '../../../recipes/models/course.dart';
import '../../models/recipe_import_result.dart';

// ---------------------------------------------------------------------------
// Failure model
// ---------------------------------------------------------------------------

/// Represents a single archive entry that could not be fully parsed.
class ExternalParseFailure {
  /// Best-effort name recovered before the crash point.
  /// Null for entries that were fully parsed but rejected for a missing name.
  final String? name;

  /// Human-readable description of the failure reason.
  final String reason;

  /// The decoded UTF-8 string if decoding succeeded before the failure;
  /// null if the failure was at or before the decode step.
  final String? rawText;

  /// Pre-populated import result for entries that parsed fully but were
  /// rejected due to a missing name.  Null for all other failure types
  /// (UTF-8 errors, JSON errors, mid-parse exceptions).
  final RecipeImportResult? partialResult;

  ExternalParseFailure({
    required this.reason,
    this.name,
    this.rawText,
    this.partialResult,
  });
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

/// The result produced by any [ExternalFormatParser].
class ExternalImportSummary {
  final List<Recipe> recipes;
  final int skippedCount;

  /// Detailed records for entries that could not be parsed.
  final List<ExternalParseFailure> failures;

  /// User-visible name of the parser that produced this summary
  /// (e.g. 'Mela', 'Mealie', 'Paprika', 'Tandoor').
  final String? detectedParserName;

  const ExternalImportSummary({
    required this.recipes,
    required this.skippedCount,
    this.failures = const [],
    this.detectedParserName,
  });
}

/// Interface for external recipe format parsers.
///
/// To add support for a new file format, create a class implementing this
/// interface and register it in [ExternalRecipeImporter._registry].
/// No other change to the core service is required.
abstract class ExternalFormatParser {
  /// Maximum number of archive entries (or top-level recipe objects) allowed
  /// per import file before processing is aborted.
  static const int maxEntries = 2000;

  /// Maximum inflated (uncompressed) size in bytes for any single archive
  /// entry, or for the cumulative total of all entries (200 MB).
  static const int maxInflatedBytes = 200 * 1024 * 1024;

  /// Maximum number of recipes processed from a single import file.
  static const int maxRecipesPerFile = 2000;

  /// Maximum number of items processed from any inner list (ingredients,
  /// instructions, steps) per recipe entry.
  static const int maxInnerListItems = 500;

  /// Parses [bytes] (the raw archive file bytes) and returns an
  /// [ExternalImportSummary] containing all successfully parsed recipes and
  /// a count of entries that were skipped due to errors.
  Future<ExternalImportSummary> parse(Uint8List bytes);
}

// ---------------------------------------------------------------------------
// Shared course-detection helper
// ---------------------------------------------------------------------------

/// Maps a list of category strings (from an external app) to a Memoix course
/// slug.  Checks direct slug match, display-name match, then a broad alias
/// table.  Returns null when no match is found; callers should fall back to
/// 'mains'.
String? detectCourseFromCategories(List<String> categories) {
  if (categories.isEmpty) return null;

  // Build lookup maps from Course.defaults so we stay in sync with the model.
  final slugSet = {for (final c in Course.defaults) c.slug};
  final nameToSlug = {
    for (final c in Course.defaults) c.name.toLowerCase(): c.slug,
  };

  // Broad alias table for common external-app category names.
  const aliases = <String, String>{
    'dinner': 'mains',
    'lunch': 'mains',
    'entree': 'mains',
    'entrée': 'mains',
    'main course': 'mains',
    'main dish': 'mains',
    'main dishes': 'mains',
    'cocktail': 'drinks',
    'cocktails': 'drinks',
    'beverage': 'drinks',
    'beverages': 'drinks',
    'smoothie': 'drinks',
    'smoothies': 'drinks',
    'juice': 'drinks',
    'juices': 'drinks',
    'breakfast': 'brunch',
    'brunch': 'brunch',
    'baking': 'breads',
    'baked goods': 'breads',
    'bread': 'breads',
    'pastry': 'desserts',
    'pastries': 'desserts',
    'cake': 'desserts',
    'cakes': 'desserts',
    'cookie': 'desserts',
    'cookies': 'desserts',
    'sweets': 'desserts',
    'salads': 'salad',
    'soup': 'soup',
    'soups': 'soup',
    'stew': 'soup',
    'stews': 'soup',
    'chili': 'soup',
    'chowder': 'soup',
    'starters': 'apps',
    'appetizers': 'apps',
    'starter': 'apps',
    'appetizer': 'apps',
    'tapas': 'apps',
    'snack': 'apps',
    'snacks': 'apps',
    'condiment': 'sauces',
    'condiments': 'sauces',
    'dressings': 'sauces',
    'dressing': 'sauces',
    'dips': 'sauces',
    'dip': 'sauces',
    'fermentation': 'pickles',
    'fermented': 'pickles',
    'preserves': 'pickles',
    'preserved': 'pickles',
    'canning': 'pickles',
    'bbq': 'smoking',
    'barbecue': 'smoking',
    'barbeque': 'smoking',
    'grilling': 'smoking',
    'smoked': 'smoking',
    'smoker': 'smoking',
    'vegan': 'vegn',
    'vegetarian': 'vegn',
    'plant-based': 'vegn',
    'plant based': 'vegn',
    'meatless': 'vegn',
    'sides': 'sides',
    'side dish': 'sides',
    'side dishes': 'sides',
    'accompaniment': 'sides',
    'molecular gastronomy': 'modernist',
    'molecular': 'modernist',
    'seasoning': 'rubs',
    'spice blend': 'rubs',
    'spice mix': 'rubs',
    'dry rub': 'rubs',
    'wine': 'cellar',
    'cellar': 'cellar',
    'cheese': 'cheese',
    'cheesemaking': 'cheese',
    'pizza': 'pizzas',
    'sandwich': 'sandwiches',
    'sandwiches': 'sandwiches',
    'burgers': 'sandwiches',
    'burger': 'sandwiches',
  };

  for (final cat in categories) {
    final lower = cat.trim().toLowerCase();
    if (lower.isEmpty) continue;

    // 1. Direct slug match (e.g. "mains", "soup").
    if (slugSet.contains(lower)) return lower;

    // 2. Display-name match (e.g. "Soups" → "soup", "Veg'n" → "vegn").
    final fromName = nameToSlug[lower];
    if (fromName != null) return fromName;

    // 3. Alias table.
    final fromAlias = aliases[lower];
    if (fromAlias != null) return fromAlias;
  }

  return null;
}
