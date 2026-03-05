import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoix/core/utils/amount_utils.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';
import 'package:memoix/core/utils/text_normalizer.dart';
import 'package:memoix/core/utils/unit_normalizer.dart';
import 'package:memoix/features/recipes/models/recipe.dart';
import 'package:memoix/features/shopping/models/shopping_list_item.dart';
import 'package:memoix/features/tools/measurement_converter.dart';

/// Controller for generating and managing the shopping list.
/// 
/// Handles aggregation, categorization, and sorting of ingredients.
class ShoppingListController {
  final IngredientService _ingredientService;

  ShoppingListController([IngredientService? ingredientService]) 
      : _ingredientService = ingredientService ?? IngredientService();

  /// Generates a categorized shopping list from a list of recipes.
  /// 
  /// Returns a Map where keys are categories (sorted by store flow)
  /// and values are the list of items in that category (sorted alphabetically).
  Future<Map<IngredientCategory, List<ShoppingListItem>>> generateShoppingList(
      List<Recipe> recipes) async {
    
    // Intermediate storage for aggregation
    // Key: Canonical Name (e.g., "yellow onion")
    final Map<String, _TermBuilder> builders = {};

    // 1. Aggregation Phase
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.name.isEmpty) continue;

        // "Specificity Rule": Normalize to Canonical Identity
        // "Diced Yellow Onions" -> "yellow onion"
        // "Heavy Cream" -> "heavy cream"
        final canonical = _ingredientService.normalize(ingredient.name);
        
        // Skip plain "water" (assumed pantry staple)
        // But allow specific types: bottled water, tonic water, sparkling water, etc.
        if (canonical == 'water') continue;
        
        // Get or create builder
        final builder = builders.putIfAbsent(canonical, () => _TermBuilder(
          canonical: canonical,
          displayName: TextNormalizer.cleanName(canonical),
          category: _ingredientService.classify(ingredient.name),
        ));

        // Fix B: detect freeform amounts ("to taste", "a pinch", "as needed").
        // Mirrors AmountScaler's freeform gate: AmountUtils.parseMax returns 0.0
        // for non-numeric strings, so we preserve the original text verbatim.
        final isFreeform = _isFreeformAmount(ingredient.amount);
        final qty = isFreeform ? 0.0 : _parseQuantity(ingredient.amount);
        final unit = isFreeform ? '' : UnitNormalizer.normalize(ingredient.unit);

        // Add variant
        builder.addVariant(
          quantity: qty,
          unit: unit,
          preparation: ingredient.preparation ?? '',
          recipeName: recipe.name,
          displayOverride: isFreeform ? ingredient.amount?.trim() : null,
        );
      }
    }

    // 2. Build & Sort Phase
    final List<ShoppingListItem> allItems = builders.values
        .map((b) => b.build())
        .toList();

    // Group by category
    final Map<IngredientCategory, List<ShoppingListItem>> grouped = {};
    for (final item in allItems) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Sort items within categories alphabetically
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return grouped;
  }

  /// Maps granular IngredientCategory to a store aisle name.
  /// Used by the shopping list for grouping; the rest of the app
  /// continues to use the fine-grained enum.
  static const Map<IngredientCategory, String> storeAisle = {
    IngredientCategory.produce:   'Produce',
    IngredientCategory.meat:      'Meat & Seafood',
    IngredientCategory.poultry:   'Meat & Seafood',
    IngredientCategory.seafood:   'Meat & Seafood',
    IngredientCategory.egg:       'Dairy & Eggs',
    IngredientCategory.cheese:    'Dairy & Eggs',
    IngredientCategory.dairy:     'Dairy & Eggs',
    IngredientCategory.grain:     'Grains & Pasta',
    IngredientCategory.pasta:     'Grains & Pasta',
    IngredientCategory.legume:    'Pantry',
    IngredientCategory.pantry:    'Pantry',
    IngredientCategory.condiment: 'Condiments & Sauces',
    IngredientCategory.spice:     'Spices & Seasonings',
    IngredientCategory.oil:       'Oils & Vinegars',
    IngredientCategory.vinegar:   'Oils & Vinegars',
    IngredientCategory.flour:     'Baking',
    IngredientCategory.sugar:     'Baking',
    IngredientCategory.leavening: 'Baking',
    IngredientCategory.nut:       'Baking',
    IngredientCategory.juice:     'Beverages',
    IngredientCategory.beverage:  'Beverages',
    IngredientCategory.alcohol:   'Beverages',
    IngredientCategory.pop:       'Beverages',
    IngredientCategory.unknown:   'Other',
  };

  /// Store aisle order — the sequence a shopper would walk.
  static const List<String> storeAisleFlow = [
    'Produce',
    'Meat & Seafood',
    'Dairy & Eggs',
    'Grains & Pasta',
    'Pantry',
    'Baking',
    'Spices & Seasonings',
    'Condiments & Sauces',
    'Oils & Vinegars',
    'Beverages',
    'Other',
  ];

  /// Resolve a category enum to a store aisle name.
  static String aisleFor(IngredientCategory cat) =>
      storeAisle[cat] ?? 'Other';

  /// Parse an ingredient amount string into a [double].
  ///
  /// Delegates to [AmountUtils.parseMax], which handles all recognised
  /// formats (integers, decimals, fractions, mixed numbers, ranges).
  /// For range strings the maximum value is returned, consistent with the
  /// previous behaviour of taking a conservative/worst-case purchase quantity.
  double _parseQuantity(String? amount) => AmountUtils.parseMax(amount);

  /// Returns true when [amount] is non-numeric freeform text.
  ///
  /// Mirrors AmountScaler's freeform gate: if [AmountUtils.parseMax] returns
  /// 0.0 for a non-empty string the amount is deliberate authoring text
  /// (e.g. "to taste", "a pinch") and must be preserved verbatim.
  bool _isFreeformAmount(String? amount) {
    if (amount == null || amount.trim().isEmpty) return false;
    return AmountUtils.parseMax(amount) == 0.0;
  }

  // ── Unit-system membership sets (after UnitNormalizer + normalizeUnit, lowercase) ──

  /// Metric volume units.
  static const _metricVol = {'ml', 'l'};

  /// Imperial volume units.
  static const _imperialVol = {'tsp', 'tbsp', 'fl oz', 'c', 'pt', 'qt', 'gal'};

  /// Metric weight units.
  static const _metricWeight = {'g', 'kg'};

  /// Imperial weight units.
  static const _imperialWeight = {'oz', 'lb'};

  /// Attempts to convert all entries in [unitSums] to a single common unit,
  /// operating within the same measurement system only (metric-only or
  /// imperial-only per dimension).
  ///
  /// Returns a named record `(unit, qty)` on success, null when units are
  /// cross-system, cross-dimension, or unrecognised (e.g. grams + tablespoons).
  ///
  /// Metric targets escalate g → kg and ml → L at 1 000 units.
  /// Imperial volume prefers the largest unit present to avoid tiny fractions.
  static ({String unit, double qty})? _tryReduceUnits(
      Map<String, double> unitSums) {
    if (unitSums.length <= 1) return null;

    final units = unitSums.keys.toSet();

    // Metric volume: convert everything to ml, optionally escalate to L.
    if (units.every((u) => _metricVol.contains(u))) {
      double total = 0.0;
      for (final entry in unitSums.entries) {
        final converted =
            MeasurementConverter.convertVolume(entry.value, entry.key, 'ml');
        if (converted == null) return null;
        total += converted;
      }
      if (total >= 1000) return (unit: 'l', qty: total / 1000.0);
      return (unit: 'ml', qty: total);
    }

    // Imperial volume: prefer the largest unit present.
    if (units.every((u) => _imperialVol.contains(u))) {
      const volOrder = ['c', 'qt', 'pt', 'fl oz', 'tbsp', 'tsp'];
      final targetUnit =
          volOrder.firstWhere((u) => units.contains(u), orElse: () => units.first);
      double total = 0.0;
      for (final entry in unitSums.entries) {
        final converted = MeasurementConverter.convertVolume(
            entry.value, entry.key, targetUnit);
        if (converted == null) return null;
        total += converted;
      }
      return (unit: targetUnit, qty: total);
    }

    // Metric weight: convert to g, optionally escalate to kg.
    if (units.every((u) => _metricWeight.contains(u))) {
      double total = 0.0;
      for (final entry in unitSums.entries) {
        final converted =
            MeasurementConverter.convertWeight(entry.value, entry.key, 'g');
        if (converted == null) return null;
        total += converted;
      }
      if (total >= 1000) return (unit: 'kg', qty: total / 1000.0);
      return (unit: 'g', qty: total);
    }

    // Imperial weight: prefer lb if present.
    if (units.every((u) => _imperialWeight.contains(u))) {
      final targetUnit = units.contains('lb') ? 'lb' : 'oz';
      double total = 0.0;
      for (final entry in unitSums.entries) {
        final converted = MeasurementConverter.convertWeight(
            entry.value, entry.key, targetUnit);
        if (converted == null) return null;
        total += converted;
      }
      return (unit: targetUnit, qty: total);
    }

    return null; // Cross-system or unrecognised units.
  }
}

/// Helper to aggregate variants before building final item
class _TermBuilder {
  final String canonical;
  final String displayName;
  final IngredientCategory category;
  final List<ShoppingItemVariant> variants = [];
  final Set<String> references = {};

  _TermBuilder({
    required this.canonical,
    required this.displayName,
    required this.category,
  });

  void addVariant({
    required double quantity,
    required String unit,
    required String preparation,
    required String recipeName,
    String? displayOverride,
  }) {
    variants.add(ShoppingItemVariant(
      quantity: quantity,
      unit: unit,
      preparation: preparation,
      recipeName: recipeName,
      displayOverride: displayOverride,
    ));
    references.add(recipeName);
  }

  ShoppingListItem build() {
    // Fix B: separate freeform variants (e.g. "to taste") from numeric variants.
    // Freeform variants carry a displayOverride and must not contribute to unit
    // sums — they are preserved verbatim as a note appended to the final display.
    final numericVariants =
        variants.where((v) => v.displayOverride == null).toList();
    final freeformTexts = variants
        .where((v) => v.displayOverride != null)
        .map((v) => v.displayOverride!)
        .toSet()
        .toList()
      ..sort();
    final freeformNote =
        freeformTexts.isEmpty ? null : freeformTexts.join(', ');

    // Fix C: group by normalised unit key (de-pluralized, lowercase) so that
    // "cloves" and "clove" resolve to the same bucket.
    final Map<String, double> unitSums = {};
    for (final v in numericVariants) {
      final u = UnitNormalizer.normalizeUnit(v.unit.toLowerCase());
      unitSums[u] = (unitSums[u] ?? 0.0) + v.quantity;
    }

    String finalUnit = '';
    double finalQty = 0.0;

    if (unitSums.isEmpty) {
      finalUnit = '';
      finalQty = 0.0;
    } else if (unitSums.length == 1) {
      finalUnit = unitSums.keys.first;
      finalQty = unitSums.values.first;
    } else {
      // Fix D: attempt unit conversion before declaring 'mixed'.
      final unified = ShoppingListController._tryReduceUnits(unitSums);
      if (unified != null) {
        finalUnit = unified.unit;
        finalQty = unified.qty;
      } else {
        finalUnit = 'mixed';
        finalQty = 0.0;
      }
    }

    return ShoppingListItem(
      name: displayName,
      category: category,
      totalQuantity: finalQty,
      unit: finalUnit,
      references: references.toList()..sort(),
      variants: numericVariants,
      freeformNote: freeformNote,
      manualNotes: '',
    );
  }
}
