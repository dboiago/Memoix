import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoix/core/utils/amount_utils.dart';
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
        
        // Skip plain "water" (assumed pantry staple)
        // But allow specific types: bottled water, tonic water, sparkling water, etc.
        if (canonical == 'water') continue;
        
        // Get or create builder
        final builder = builders.putIfAbsent(canonical, () => _TermBuilder(
          canonical: canonical,
          displayName: TextNormalizer.cleanName(canonical),
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
