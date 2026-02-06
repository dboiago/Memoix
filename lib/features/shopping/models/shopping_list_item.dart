import 'package:memoix/core/utils/ingredient_categorizer.dart';

/// Represents a consolidated item on the shopping list.
/// 
/// Aggegated from multiple recipes based on "Canonical Identity".
class ShoppingListItem {
  /// Canonical name of the ingredient (e.g., "Yellow Onions")
  final String name;
  
  /// Categorization for grouping (e.g., Produce, Meat)
  final IngredientCategory category;
  
  /// Total aggregated quantity (if units are compatible)
  final double totalQuantity;
  
  /// Common unit (if units are compatible, otherwise "mixed" or empty)
  final String unit;
  
  /// User-added notes for this specific list item
  final String manualNotes;
  
  /// List of recipe names that contributed to this item
  final List<String> references;
  
  /// Detailed breakdown of the source ingredients
  /// Useful for "Separate Sub-Entries" when units differ
  final List<ShoppingItemVariant> variants;

  ShoppingListItem({
    required this.name,
    required this.category,
    required this.totalQuantity,
    this.unit = '',
    this.manualNotes = '',
    required this.references,
    required this.variants,
  });

  /// Returns a display string for the quantity.
  /// 
  /// Examples:
  /// - "300 g" (if merged)
  /// - "2 cups, 100 g" (if mixed)
  String get quantityDisplay {
    if (unit == 'mixed' || unit.isEmpty && variants.length > 1) {
      // Return a comma-separated list of variants
      return variants.map((v) => v.display).join(', ');
    }
    // Remove trailing .0 for cleaner display
    final qty = totalQuantity % 1 == 0 
        ? totalQuantity.toInt().toString() 
        : totalQuantity.toStringAsFixed(1);
    
    return '$qty $unit'.trim();
  }
}

/// A specific instance of an ingredient from a recipe
class ShoppingItemVariant {
  final double quantity;
  final String unit;
  final String preparation;
  final String recipeName; // Reference

  ShoppingItemVariant({
    required this.quantity,
    required this.unit,
    required this.preparation,
    required this.recipeName,
  });

  String get display {
     final qty = quantity % 1 == 0 
        ? quantity.toInt().toString() 
        : quantity.toStringAsFixed(1);
     return '$qty $unit'.trim();
  }
}
