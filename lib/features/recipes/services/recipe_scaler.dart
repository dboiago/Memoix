import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../models/recipe.dart';

/// Service for intelligently scaling recipe ingredients
/// 
/// Some ingredients don't scale linearly:
/// - Salt and spices: Scale less than proportionally (use ~0.8x multiplier)
/// - Baking powder/soda: Scale even less (~0.7x multiplier)
/// - Eggs: Round to nearest whole number
/// - Liquids in baking: May need slight adjustment
/// - Cooking oils: Often don't need to scale much for larger batches
class RecipeScaler {
  /// Scale a recipe from original servings to target servings
  ScaledRecipe scale(Recipe recipe, int originalServings, int targetServings) {
    if (originalServings <= 0 || targetServings <= 0) {
      final scaled = recipe.ingredients
          .map((i) => ScaledIngredient(original: i))
          .toList();
      return ScaledRecipe(recipe: recipe, scaleFactor: 1.0, scaledIngredients: scaled);
    }

    final scaleFactor = targetServings / originalServings;
    final scaledIngredients = recipe.ingredients.map((ingredient) {
      return _scaleIngredient(ingredient, scaleFactor);
    }).toList();

    return ScaledRecipe(
      recipe: recipe,
      scaleFactor: scaleFactor,
      scaledIngredients: scaledIngredients,
      originalServings: originalServings,
      targetServings: targetServings,
    );
  }

  /// Scale a single ingredient with smart adjustments
  ScaledIngredient _scaleIngredient(Ingredient ingredient, double scaleFactor) {
    final amount = ingredient.amount;
    if (amount == null || amount.isEmpty) {
      return ScaledIngredient(original: ingredient, scaledAmount: null);
    }

    // Parse the amount
    final parsed = _parseAmount(amount);
    if (parsed == null) {
      return ScaledIngredient(original: ingredient, scaledAmount: amount);
    }

    // Determine the scaling multiplier based on ingredient type
    final adjustedMultiplier = _getAdjustedMultiplier(ingredient.name, scaleFactor);
    
    // Calculate new amount
    var scaledValue = parsed.value * adjustedMultiplier;
    
    // Special handling for certain units/ingredients
    scaledValue = _adjustForUnit(scaledValue, parsed.unit, ingredient.name);
    
    // Format the result
    final scaledAmount = _formatAmount(scaledValue, parsed.unit);
    
    return ScaledIngredient(
      original: ingredient,
      scaledAmount: scaledAmount,
      scaledValue: scaledValue,
      scalingNote: _getScalingNote(ingredient.name, scaleFactor, adjustedMultiplier),
    );
  }

  /// Parse amount string into value and unit
  ParsedAmount? _parseAmount(String amount) {
    // Handle fractions
    amount = _convertFractions(amount);
    
    // Handle ranges (e.g., "1-2 cups" -> take the average)
    final rangeMatch = RegExp(r'^([\d.]+)\s*[-–]\s*([\d.]+)\s*(.*)$').firstMatch(amount);
    if (rangeMatch != null) {
      final low = double.tryParse(rangeMatch.group(1)!) ?? 0;
      final high = double.tryParse(rangeMatch.group(2)!) ?? 0;
      return ParsedAmount(value: (low + high) / 2, unit: rangeMatch.group(3)?.trim() ?? '', isRange: true);
    }
    
    // Standard format: "2 cups", "1.5 tbsp", etc.
    final match = RegExp(r'^([\d.]+)\s*(.*)$').firstMatch(amount.trim());
    if (match != null) {
      final value = double.tryParse(match.group(1)!);
      if (value != null) {
        return ParsedAmount(value: value, unit: match.group(2)?.trim() ?? '');
      }
    }
    
    return null;
  }

  /// Convert unicode fractions to decimals
  String _convertFractions(String s) {
    return s
        .replaceAll('½', '.5')
        .replaceAll('¼', '.25')
        .replaceAll('¾', '.75')
        .replaceAll('⅓', '.333')
        .replaceAll('⅔', '.667')
        .replaceAll('⅛', '.125')
        .replaceAll('⅜', '.375')
        .replaceAll('⅝', '.625')
        .replaceAll('⅞', '.875');
  }

  /// Get adjusted multiplier based on ingredient type
  double _getAdjustedMultiplier(String ingredientName, double scaleFactor) {
    final name = ingredientName.toLowerCase();
    
    // Ingredients that scale less than linearly
    final saltSpices = ['salt', 'pepper', 'cayenne', 'chili', 'paprika', 'cumin', 
                        'coriander', 'turmeric', 'cinnamon', 'nutmeg', 'ginger',
                        'garlic powder', 'onion powder', 'oregano', 'basil', 'thyme',
                        'rosemary', 'sage', 'parsley', 'cilantro', 'dill', 'mint'];
    
    final leavening = ['baking powder', 'baking soda', 'yeast', 'cream of tartar'];
    
    final strongFlavors = ['vanilla', 'extract', 'worcestershire', 'fish sauce',
                           'soy sauce', 'hot sauce', 'tabasco', 'sriracha', 'wasabi',
                           'horseradish', 'mustard', 'anchovy'];
    
    // Scaling up
    if (scaleFactor > 1) {
      for (final ingredient in saltSpices) {
        if (name.contains(ingredient)) {
          // Scale at 80% of linear for doubling, less for larger multiples
          return 1 + (scaleFactor - 1) * 0.8;
        }
      }
      
      for (final ingredient in leavening) {
        if (name.contains(ingredient)) {
          // Leavening agents scale even less - about 70%
          return 1 + (scaleFactor - 1) * 0.7;
        }
      }
      
      for (final ingredient in strongFlavors) {
        if (name.contains(ingredient)) {
          // Strong flavors scale at 75%
          return 1 + (scaleFactor - 1) * 0.75;
        }
      }
    }
    
    // Scaling down - use linear scaling but note the adjustment
    return scaleFactor;
  }

  /// Adjust values for specific units (rounding eggs, etc.)
  double _adjustForUnit(double value, String unit, String ingredientName) {
    final name = ingredientName.toLowerCase();
    final u = unit.toLowerCase();
    
    // Round eggs to nearest whole number
    if (name.contains('egg') || u == 'egg' || u == 'eggs') {
      return value.roundToDouble();
    }
    
    // Round cans/packages to nearest whole or half
    if (u == 'can' || u == 'cans' || u == 'package' || u == 'packages') {
      return (value * 2).round() / 2; // Round to nearest 0.5
    }
    
    // For very small amounts, don't go below a minimum
    if (value < 0.1 && (u.contains('tsp') || u.contains('tbsp'))) {
      return 0.125; // ⅛ tsp minimum
    }
    
    return value;
  }

  /// Format amount back to readable string
  String _formatAmount(double value, String unit) {
    // Convert back to fractions for common values
    String valueStr;
    
    if (value == value.roundToDouble() && value < 100) {
      valueStr = value.toInt().toString();
    } else if ((value * 2) == (value * 2).roundToDouble()) {
      // Halves
      final whole = value.floor();
      final frac = value - whole;
      if (frac >= 0.4 && frac <= 0.6) {
        valueStr = whole > 0 ? '$whole ½' : '½';
      } else {
        valueStr = _formatDecimal(value);
      }
    } else if ((value * 4) == (value * 4).roundToDouble()) {
      // Quarters
      final whole = value.floor();
      final frac = value - whole;
      if (frac >= 0.2 && frac <= 0.3) {
        valueStr = whole > 0 ? '$whole ¼' : '¼';
      } else if (frac >= 0.7 && frac <= 0.8) {
        valueStr = whole > 0 ? '$whole ¾' : '¾';
      } else {
        valueStr = _formatDecimal(value);
      }
    } else if ((value * 3) == (value * 3).roundToDouble()) {
      // Thirds
      final whole = value.floor();
      final frac = value - whole;
      if (frac >= 0.3 && frac <= 0.35) {
        valueStr = whole > 0 ? '$whole ⅓' : '⅓';
      } else if (frac >= 0.65 && frac <= 0.7) {
        valueStr = whole > 0 ? '$whole ⅔' : '⅔';
      } else {
        valueStr = _formatDecimal(value);
      }
    } else {
      valueStr = _formatDecimal(value);
    }
    
    return unit.isNotEmpty ? '$valueStr $unit' : valueStr;
  }

  String _formatDecimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Round to 2 decimal places and remove trailing zeros
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Get a note explaining the scaling adjustment
  String? _getScalingNote(String ingredientName, double requestedFactor, double actualFactor) {
    if ((requestedFactor - actualFactor).abs() < 0.01) {
      return null;
    }
    
    final name = ingredientName.toLowerCase();
    
    if (name.contains('salt') || name.contains('pepper')) {
      return 'Adjusted - taste and add more if needed';
    }
    if (name.contains('baking powder') || name.contains('baking soda')) {
      return 'Adjusted - leavening doesn\'t scale linearly';
    }
    if (name.contains('yeast')) {
      return 'Adjusted - may need longer rise time';
    }
    if (name.contains('vanilla') || name.contains('extract')) {
      return 'Adjusted - strong flavors intensify';
    }
    
    return 'Adjusted for better results';
  }
}

/// Result of scaling a recipe
class ScaledRecipe {
  final Recipe recipe;
  final double scaleFactor;
  final List<ScaledIngredient> scaledIngredients;
  final int? originalServings;
  final int? targetServings;

  ScaledRecipe({
    required this.recipe,
    required this.scaleFactor,
    required this.scaledIngredients,
    this.originalServings,
    this.targetServings,
  });

  String get scaleDescription {
    if (scaleFactor == 1.0) return 'Original';
    if (scaleFactor == 0.5) return 'Half';
    if (scaleFactor == 2.0) return 'Double';
    if (scaleFactor == 3.0) return 'Triple';
    return '${scaleFactor.toStringAsFixed(1)}x';
  }
}

/// A scaled ingredient with optional notes
class ScaledIngredient {
  final Ingredient original;
  final String? scaledAmount;
  final double? scaledValue;
  final String? scalingNote;

  ScaledIngredient({
    required this.original,
    this.scaledAmount,
    this.scaledValue,
    this.scalingNote,
  });

  /// Get display text with scaled amount
  String get displayText {
    final buffer = StringBuffer();
    
    if (scaledAmount != null && scaledAmount!.isNotEmpty) {
      buffer.write(scaledAmount);
      buffer.write(' ');
    }
    
    buffer.write(original.name);
    
    if (original.preparation != null && original.preparation!.isNotEmpty) {
      buffer.write(', ');
      buffer.write(original.preparation);
    }
    
    if (original.isOptional) {
      buffer.write(' (optional)');
    }
    
    return buffer.toString();
  }
}

/// Parsed amount with value and unit
class ParsedAmount {
  final double value;
  final String unit;
  final bool isRange;

  ParsedAmount({required this.value, required this.unit, this.isRange = false});
}

// Provider
final recipeScalerProvider = Provider<RecipeScaler>((ref) {
  return RecipeScaler();
});
