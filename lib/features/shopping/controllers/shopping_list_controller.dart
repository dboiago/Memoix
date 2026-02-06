import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';
import 'package:memoix/core/utils/text_normalizer.dart';
import 'package:memoix/core/utils/unit_normalizer.dart';
import 'package:memoix/features/recipes/models/recipe.dart';
import 'package:memoix/features/shopping/models/shopping_list_item.dart';

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
        
        // Get or create builder
        final builder = builders.putIfAbsent(canonical, () => _TermBuilder(
          canonical: canonical,
          // Use Title Case for display (e.g., "Yellow Onion")
          displayName: TextNormalizer.toTitleCase(canonical),
          category: _ingredientService.classify(ingredient.name),
        ));

        // Parse quantity
        final qty = _parseQuantity(ingredient.amount);
        final unit = UnitNormalizer.normalize(ingredient.unit);

        // Add variant
        builder.addVariant(
          quantity: qty,
          unit: unit,
          preparation: ingredient.preparation ?? '',
          recipeName: recipe.name,
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

    // 3. Category Sorting (Grocery Store Flow)
    final sortedMap = <IngredientCategory, List<ShoppingListItem>>{};
    
    // Define logical store flow
    const storeFlow = [
      IngredientCategory.produce,
      IngredientCategory.meat,
      IngredientCategory.poultry,
      IngredientCategory.seafood,
      IngredientCategory.egg,
      IngredientCategory.dairy,
      IngredientCategory.cheese,
      IngredientCategory.grain,
      IngredientCategory.pasta,
      IngredientCategory.legume,
      IngredientCategory.leavening,
      IngredientCategory.sugar,
      IngredientCategory.flour,
      IngredientCategory.spice,
      IngredientCategory.condiment,
      IngredientCategory.oil,
      IngredientCategory.vinegar,
      IngredientCategory.nut,
      IngredientCategory.juice,
      IngredientCategory.beverage,
      IngredientCategory.alcohol,
      IngredientCategory.pop,
      IngredientCategory.unknown,
    ];

    for (final category in storeFlow) {
      if (grouped.containsKey(category)) {
        sortedMap[category] = grouped[category]!;
      }
    }

    // Catch any missing categories safely
    for (final category in grouped.keys) {
      if (!sortedMap.containsKey(category)) {
        sortedMap[category] = grouped[category]!;
      }
    }

    return sortedMap;
  }

  /// Parses diverse quantity strings into a double.
  /// 
  /// Handles:
  /// - Integers: "1" -> 1.0
  /// - Decimals: "1.5" -> 1.5
  /// - Unicode Fractions: "½" -> 0.5
  /// - Ranges: "1-2" -> 2.0 (Conservative/Max)
  /// - Text Fractions: "1/2" -> 0.5 (via normalizeFractions)
  double _parseQuantity(String? amount) {
    if (amount == null || amount.isEmpty) return 0.0;

    // 1. Normalize fractions (1/2 -> ½)
    String cleaned = TextNormalizer.normalizeFractions(amount);
    
    // 2. Handle ranges (take max)
    if (cleaned.contains('-') || cleaned.contains('–')) {
       final parts = cleaned.split(RegExp(r'[-–]'));
       // Usually last part is max (1-2)
       if (parts.length > 1) {
         return _parseQuantity(parts.last);
       }
    }

    double total = 0.0;
    
    // 3. Unicode Fraction Map
    const fractionMap = {
      '½': 0.5, '¼': 0.25, '¾': 0.75,
      '⅓': 0.333, '⅔': 0.666,
      '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 0.166, '⅚': 0.833,
    };

    // 4. Sum up numbers and fractions
    // "1 ½" -> 1.0 + 0.5
    final regex = RegExp(r'(\d+(?:\.\d+)?)|([' + fractionMap.keys.join() + r'])');
    final matches = regex.allMatches(cleaned);
    
    for (final match in matches) {
      final numStr = match.group(1);
      final fracStr = match.group(2);
      
      if (numStr != null) {
        total += double.tryParse(numStr) ?? 0.0;
      } else if (fracStr != null) {
        total += fractionMap[fracStr] ?? 0.0;
      }
    }

    return total;
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
  }) {
    variants.add(ShoppingItemVariant(
      quantity: quantity,
      unit: unit,
      preparation: preparation,
      recipeName: recipeName,
    ));
    references.add(recipeName);
  }

  ShoppingListItem build() {
    // Attempt unit merging
    // 1. Group by unit
    final Map<String, double> unitSums = {};
    
    for (final v in variants) {
      // Normalize 'cloves' -> 'clove' done by UnitNormalizer already?
      // Assuming UnitNormalizer.normalize runs before this.
      // Treat empty unit as "pcs" or empty
      final u = v.unit.toLowerCase();
      unitSums[u] = (unitSums[u] ?? 0.0) + v.quantity;
    }

    // 2. Identify primary unit
    // If only one unit exists (e.g. 'g'), that's it.
    // If multiple (e.g. 'g' and 'cup'), we have a conflict.
    
    String finalUnit = '';
    double finalQty = 0.0;

    if (unitSums.isEmpty) {
      // No quantities found
      finalUnit = '';
      finalQty = 0.0;
    } else if (unitSums.length == 1) {
      // Perfect match
      finalUnit = unitSums.keys.first;
      finalQty = unitSums.values.first;
    } else {
      // Mixed units
      // Strategy: Check if there's a dominant unit? 
      // For now, per requirements: "keep them as separate ... entries"
      // We set finalUnit to 'mixed' to trigger the detailed display logic
      finalUnit = 'mixed';
      finalQty = 0.0; 
    }

    return ShoppingListItem(
      name: displayName,
      category: category,
      totalQuantity: finalQty,
      unit: finalUnit, // If 'mixed', UI should look at variants
      references: references.toList()..sort(),
      variants: variants,
      manualNotes: '',
    );
  }
}
