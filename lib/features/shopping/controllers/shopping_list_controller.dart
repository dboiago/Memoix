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
      List<Recipe> recipes,) async {
    
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
        ),);

        // Fix S2-A: recover units embedded in the amount string when the unit
        // field is empty — a common import artifact (e.g. { amount: "1 C", unit: "" }).
        String rawAmount = ingredient.amount ?? '';
        String rawUnit   = ingredient.unit ?? '';
        if (rawUnit.isEmpty && rawAmount.isNotEmpty) {
          final extracted = _extractEmbeddedUnit(rawAmount);
          if (extracted != null) {
            rawAmount = extracted.amount;
            rawUnit   = extracted.unit;
          }
        }

        // Fix R3-2: if unit is non-empty but not a recognized measurement unit,
        // it may be part of a freeform phrase split across amount/unit fields
        // (e.g. amount: "to", unit: "taste" → reconstruct as "to taste").
        if (rawUnit.isNotEmpty && !UnitNormalizer.isRecognizedUnit(rawUnit)) {
          final reconstructed = '$rawAmount $rawUnit'.trim();
          if (_isFreeformAmount(reconstructed)) {
            rawAmount = reconstructed;
            rawUnit = '';
          }
        }

        // Fix B: detect freeform amounts ("to taste", "a pinch", "as needed").
        // Mirrors AmountScaler's freeform gate: AmountUtils.parseMax returns 0.0
        // for non-numeric strings, so we preserve the original text verbatim.
        var isFreeform = _isFreeformAmount(rawAmount);
        String? displayOverride = isFreeform ? rawAmount.trim() : null;

        // Fix R3-3: freeform phrases moved to preparation by the parser
        // (e.g. "salt, to taste" → amount: null, preparation: "to taste").
        // Surface them as a freeform note on the shopping list.
        if (!isFreeform && ingredient.preparation != null) {
          final prep = ingredient.preparation!.toLowerCase().trim();
          if (_freeformPreparations.any((p) => prep.contains(p))) {
            isFreeform = true;
            displayOverride = ingredient.preparation!.trim();
          }
        }

        final qty = isFreeform ? 0.0 : _parseQuantity(rawAmount);
        final unit = isFreeform ? '' : UnitNormalizer.normalize(rawUnit);

        // Add variant
        builder.addVariant(
          quantity: qty,
          unit: unit,
          preparation: ingredient.preparation ?? '',
          recipeName: recipe.name,
          displayOverride: displayOverride,
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

  /// Freeform preparation phrases that should surface as shopping list notes.
  ///
  /// When the import pipeline moves a phrase like `"to taste"` from the amount
  /// field into `ingredient.preparation`, the shopping list controller checks
  /// this set to recover it as a freeform display note.
  ///
  /// This is the **single source of truth** for freeform prep detection.
  static const _freeformPreparations = {
    'to taste',
    'as needed',
    'as required',
    'to preference',
    'a pinch',
    'for frying',
    'for garnish',
    'for serving',
    'to serve',
  };

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

  /// Attempts to recover a unit that was embedded in the amount string.
  ///
  /// A common import artifact stores `{ amount: "1 C", unit: "" }` instead
  /// of the canonical `{ amount: "1", unit: "C" }`. When `ingredient.unit`
  /// is empty this helper splits the last space-delimited token off the
  /// amount string and checks whether it is a recognised unit via
  /// [UnitNormalizer.isRecognizedUnit]. Returns a named record on success,
  /// `null` if no parseable unit tail is found.
  ///
  /// Multi-word units (`fl oz`, `fluid ounce`) are detected before the
  /// single-token split to prevent `"oz"` being extracted from `"2 fl oz"`.
  static ({String amount, String unit})? _extractEmbeddedUnit(String rawAmount) {
    final trimmed = rawAmount.trim();
    if (trimmed.isEmpty) return null;

    // Phase 1: check for known multi-word units at the tail of the string.
    const multiWordUnits = ['fl oz', 'fluid ounces', 'fluid ounce'];
    for (final mu in multiWordUnits) {
      final lower = trimmed.toLowerCase();
      if (lower.endsWith(mu) && trimmed.length > mu.length) {
        final numPart = trimmed.substring(0, trimmed.length - mu.length).trim();
        if (numPart.isNotEmpty) {
          return (amount: numPart, unit: mu);
        }
      }
    }

    // Phase 2: split on the last space; check if the right-hand token is a
    // recognised unit.  E.g. "1 C", "2.5 Tbsp", "1½ tsp", "200 g".
    final lastSpace = trimmed.lastIndexOf(' ');
    if (lastSpace == -1) return null; // no space → no embedded unit

    final numPart  = trimmed.substring(0, lastSpace).trim();
    final unitPart = trimmed.substring(lastSpace + 1).trim();

    if (numPart.isEmpty || unitPart.isEmpty) return null;
    if (!UnitNormalizer.isRecognizedUnit(unitPart)) return null;

    return (amount: numPart, unit: unitPart);
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
      Map<String, double> unitSums,) {
    if (unitSums.length <= 1) return null;

    // Remove empty-string key before unit reduction — unitless quantities
    // are countable items (e.g. "3 eggs") and must never be absorbed into
    // measurement-unit buckets (tbsp, C, etc.).
    Map<String, double> effectiveSums = Map<String, double>.of(unitSums);
    effectiveSums.remove('');
    if (effectiveSums.isEmpty) return null;

    final units = effectiveSums.keys.toSet();

    // Metric volume: convert everything to ml, optionally escalate to L.
    if (units.every((u) => _metricVol.contains(u))) {
      double total = 0.0;
      for (final entry in effectiveSums.entries) {
        final converted =
            MeasurementConverter.convertVolume(entry.value, entry.key, 'ml');
        if (converted == null) return null;
        total += converted;
      }
      double qty = total;
      String u = 'ml';
      if (total >= 1000) { qty = total / 1000.0; u = 'l'; }
      final formatted = AmountUtils.format(qty);
      if (formatted.contains('.')) return null;
      return (unit: u, qty: qty);
    }

    // Imperial volume: prefer the largest unit present.
    if (units.every((u) => _imperialVol.contains(u))) {
      const volOrder = ['c', 'qt', 'pt', 'fl oz', 'tbsp', 'tsp'];
      final targetUnit =
          volOrder.firstWhere((u) => units.contains(u), orElse: () => units.first);
      double total = 0.0;
      for (final entry in effectiveSums.entries) {
        final converted = MeasurementConverter.convertVolume(
            entry.value, entry.key, targetUnit,);
        if (converted == null) return null;
        total += converted;
      }
      // Snappability gate: if the reduced total formats as a decimal (e.g.
      // 1.0833 C), the result is not useful — return null so `build()` falls
      // through to the per-unit variant display ("1 C, 4 tsp").
      final formatted = AmountUtils.format(total);
      if (formatted.contains('.')) return null;
      return (unit: targetUnit, qty: total);
    }

    // Metric weight: convert to g, optionally escalate to kg.
    if (units.every((u) => _metricWeight.contains(u))) {
      double total = 0.0;
      for (final entry in effectiveSums.entries) {
        final converted =
            MeasurementConverter.convertWeight(entry.value, entry.key, 'g');
        if (converted == null) return null;
        total += converted;
      }
      double qty = total;
      String u = 'g';
      if (total >= 1000) { qty = total / 1000.0; u = 'kg'; }
      final formatted = AmountUtils.format(qty);
      if (formatted.contains('.')) return null;
      return (unit: u, qty: qty);
    }

    // Imperial weight: prefer lb if present.
    if (units.every((u) => _imperialWeight.contains(u))) {
      final targetUnit = units.contains('lb') ? 'lb' : 'oz';
      double total = 0.0;
      for (final entry in effectiveSums.entries) {
        final converted = MeasurementConverter.convertWeight(
            entry.value, entry.key, targetUnit,);
        if (converted == null) return null;
        total += converted;
      }
      final formatted = AmountUtils.format(total);
      if (formatted.contains('.')) return null;
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

  /// Stores the first-seen display form for each unit bucket key.
  ///
  /// [UnitNormalizer.normalizeUnit] lowercases units for bucketing
  /// (e.g. `"C"` → `"c"`, `"Tbsp"` → `"tbsp"`). This map preserves the
  /// original casing of the first variant so the shopping list displays
  /// `"4¾ C"` instead of `"4¾ c"`.
  final Map<String, String> _unitDisplayForms = {};

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
    ),);
    references.add(recipeName);
    // Fix S1-B: record first-seen display unit per bucket so that the original
    // casing (e.g. "C" not "c") is restored when building the final item.
    if (displayOverride == null) {
      final bucketKey = UnitNormalizer.normalizeUnit(unit.toLowerCase());
      _unitDisplayForms.putIfAbsent(bucketKey, () => unit);
    }
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
      // Fix S1-B: restore original display casing from the first-seen unit.
      final bucketKey = unitSums.keys.first;
      finalUnit = _unitDisplayForms[bucketKey] ?? bucketKey;
      finalQty = unitSums.values.first;
    } else {
      // Fix D: attempt unit conversion before declaring 'mixed'.
      final unified = ShoppingListController._tryReduceUnits(unitSums);
      if (unified != null) {
        // Fix S1-B: restore original display casing for the resolved unit.
        finalUnit = _unitDisplayForms[unified.unit] ?? unified.unit;
        finalQty = unified.qty;
      } else {
        finalUnit = 'mixed';
        finalQty = 0.0;
      }
    }

    // Fix S2-B: when falling through to 'mixed', exclude bare-number (no-unit)
    // variants from the display list — a lone "1" alongside "2½ C" is not
    // useful information; its quantity was already absorbed by _tryReduceUnits.
    final displayVariants = (finalUnit == 'mixed')
        ? numericVariants.where((v) => v.unit.isNotEmpty).toList()
        : numericVariants;

    return ShoppingListItem(
      name: displayName,
      category: category,
      totalQuantity: finalQty,
      unit: finalUnit,
      references: references.toList()..sort(),
      variants: displayVariants,
      freeformNote: freeformNote,
      manualNotes: '',
    );
  }
}
