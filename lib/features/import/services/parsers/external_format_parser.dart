import 'dart:typed_data';

import '../../../recipes/models/recipe.dart';
import '../../../recipes/models/course.dart';

/// The result produced by any [ExternalFormatParser].
class ExternalImportSummary {
  final List<Recipe> recipes;
  final int skippedCount;

  const ExternalImportSummary({
    required this.recipes,
    required this.skippedCount,
  });
}

/// Interface for external recipe format parsers.
///
/// To add support for a new file format, create a class implementing this
/// interface and register it in [ExternalRecipeImporter._registry].
/// No other change to the core service is required.
abstract class ExternalFormatParser {
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
