import 'package:memoix/core/utils/amount_utils.dart';
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
  
  /// Detailed breakdown of the source ingredients.
  /// Contains only numeric variants; freeform variants are captured in [freeformNote].
  final List<ShoppingItemVariant> variants;

  /// Deduplicated freeform text from freeform variants (e.g. "to taste").
  /// Null when the group has no freeform amounts.
  final String? freeformNote;

  ShoppingListItem({
    required this.name,
    required this.category,
    required this.totalQuantity,
    this.unit = '',
    this.manualNotes = '',
    required this.references,
    required this.variants,
    this.freeformNote,
  });

  /// Returns a display string for the quantity.
  ///
  /// Examples:
  /// - "300 g"            (single unit, numeric)
  /// - "2¼ C"            (fraction-snapped via AmountUtils.format)
  /// - "2 C, 4 Tbsp"      (mixed units, unconvertible)
  /// - "to taste"         (freeform-only)
  /// - "3 clove (+ to taste)" (numeric + freeform)
  String get quantityDisplay {
    if (unit == 'mixed') {
      // Multiple incompatible numeric units — show each variant.
      final numericPart = variants.map((v) => v.display).join(', ');
      return freeformNote != null ? '$numericPart (+ $freeformNote)' : numericPart;
    }
    if (totalQuantity == 0.0 && unit.isEmpty) {
      // Freeform-only group — no numeric quantity was collected.
      return freeformNote ?? '';
    }
    // Single-unit numeric (or numeric + freeform note).
    final numericPart = '${AmountUtils.format(totalQuantity)} $unit'.trim();
    return freeformNote != null ? '$numericPart (+ $freeformNote)' : numericPart;
  }
}

/// A specific instance of an ingredient from a recipe.
class ShoppingItemVariant {
  final double quantity;
  final String unit;
  final String preparation;
  final String recipeName;

  /// Non-null for freeform amounts (e.g. "to taste", "a pinch").
  /// When set, [display] returns this string directly without any
  /// numeric formatting.
  final String? displayOverride;

  ShoppingItemVariant({
    required this.quantity,
    required this.unit,
    required this.preparation,
    required this.recipeName,
    this.displayOverride,
  });

  String get display {
    if (displayOverride != null) return displayOverride!;
    return '${AmountUtils.format(quantity)} $unit'.trim();
  }
}

// ── Shopping list heading pluralization ──────────────────────────────────────

/// Exceptions map for ingredient name pluralization.
///
/// - A [null] value means the word is uncountable or already plural — return as-is.
/// - A non-null [String] value is the explicit plural form to use.
///
// add entries here as edge cases are found
const Map<String, String?> _pluralExceptions = {
  // Uncountable — return as-is
  'salt': null,
  'flour': null,
  'sugar': null,
  'butter': null,
  'oil': null,
  'water': null,
  'milk': null,
  'cream': null,
  'honey': null,
  'rice': null,
  'garlic': null,
  'ginger': null,
  'vinegar': null,
  'pasta': null,
  'bread': null,
  'cheese': null,
  'bacon': null,
  'ham': null,
  'beef': null,
  'pork': null,
  'lamb': null,
  'veal': null,
  'salmon': null,
  'tuna': null,
  'cod': null,
  'chicken': null,
  'turkey': null,
  'duck': null,
  'quinoa': null,
  'couscous': null,
  'barley': null,
  'oat': null,
  'cornstarch': null,
  'paprika': null,
  'cumin': null,
  'turmeric': null,
  'cinnamon': null,
  'nutmeg': null,
  'oregano': null,
  'thyme': null,
  'rosemary': null,
  'basil': null,
  'parsley': null,
  'cilantro': null,
  'dill': null,
  'sage': null,
  'tarragon': null,
  'coriander': null,
  'saffron': null,
  'cardamom': null,
  // Irregular plurals
  'leaf': 'leaves',
  'loaf': 'loaves',
  'half': 'halves',
  'tomato': 'tomatoes',
  'potato': 'potatoes',
  'avocado': 'avocados',
  'mango': 'mangoes',
  'jalapeños': 'jalapeños',
  // Invariant (same form singular and plural)
  'fish': 'fish',
  'shrimp': 'shrimp',
  'deer': 'deer',
  // Already plural — return as-is
  'oats': null,
  'grits': null,
  'greens': null,
  'sprouts': null,
  // Irregular -y
  'anchovy': 'anchovies',
};

/// Applies the programmatic pluralization rules to a single [word].
String _pluralizeWord(String word) {
  final lower = word.toLowerCase();

  // 1. Exceptions map takes priority (case-insensitive lookup).
  if (_pluralExceptions.containsKey(lower)) {
    final override = _pluralExceptions[lower];
    if (override == null) return word; // uncountable / already plural
    return _matchCase(word, override);
  }

  // 2. Programmatic rules — first match wins.
  // "donkey→donkeys" — vowel-y endings just append 's'.
  if (lower.endsWith('ey') || lower.endsWith('ay') ||
      lower.endsWith('oy') || lower.endsWith('uy')) {
    return '${word}s';
  }
  // "blueberry→blueberries" — consonant-y ending.
  if (lower.endsWith('y')) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  // "knife→knives".
  if (lower.endsWith('fe')) {
    return '${word.substring(0, word.length - 2)}ves';
  }
  // "loaf→loaves" (catches non-exception 'f' words).
  if (lower.endsWith('f')) {
    return '${word.substring(0, word.length - 1)}ves';
  }
  // "peach→peaches", "box→boxes", "buzz→buzzes".
  if (lower.endsWith('s') || lower.endsWith('x') || lower.endsWith('z') ||
      lower.endsWith('ch') || lower.endsWith('sh')) {
    return '${word}es';
  }
  // Default: append 's'.
  return '${word}s';
}

/// Preserves the capitalisation style of [source] when applying [target].
String _matchCase(String source, String target) {
  if (source.isEmpty || target.isEmpty) return target;
  if (source[0] == source[0].toUpperCase()) {
    return target[0].toUpperCase() + target.substring(1);
  }
  return target;
}

/// Returns the plural display form of an ingredient [name] for shopping list
/// headings.
///
/// Multi-word names pluralize the **last word only**:
///   "sesame seed" → "sesame seeds"
///   "bay leaf"    → "bay leaves"
///   "olive oil"   → "olive oil"  (uncountable, unchanged)
///
/// If the name is uncountable or already plural it is returned unchanged.
///
/// **Apply to heading display only — never to stored data.**
String pluralizeIngredient(String name) {
  if (name.trim().isEmpty) return name;
  final words = name.split(' ');
  final pluralLast = _pluralizeWord(words.last);
  if (words.length == 1) return pluralLast;
  return '${words.sublist(0, words.length - 1).join(' ')} $pluralLast';
}
