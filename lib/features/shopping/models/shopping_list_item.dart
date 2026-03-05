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

/// Categories for which ingredient names are countable and should be
/// pluralized in shopping list headings.
///
/// Uncountable categories (spices, dairy, oils, grains, etc.) are excluded.
/// The category gate replaces the need for an uncountables exceptions list.
const _countableCategories = {
  IngredientCategory.produce,
  IngredientCategory.egg,
  IngredientCategory.nut,
  IngredientCategory.meat,
  IngredientCategory.poultry,
  IngredientCategory.seafood,
};

/// Exceptions map for irregular plurals and invariant countables.
///
/// - A [null] value means the ingredient is invariant (singular = plural).
/// - A non-null [String] value is the explicit irregular plural form.
///
/// Uncountable ingredients are **not** listed here — the category gate in
/// [pluralizeIngredient] handles them before this map is consulted.
///
// add entries here as edge cases are found
const Map<String, String?> _pluralExceptions = {
  // Irregular plurals
  'leaf': 'leaves',
  'loaf': 'loaves',
  'half': 'halves',
  'tomato': 'tomatoes',
  'potato': 'potatoes',
  'mango': 'mangoes',
  'avocado': 'avocados',
  // Invariant countables (singular = plural)
  'fish': null,
  'zest': null,
  'celery': null,
  'kimchi': null,
  'spinach': null,
  'rosemary': null,
  'basil': null,
  'parsley': null,
  'thyme': null,
  'shrimp': null,
  'salmon': null,
  'cod': null,
  'tuna': null,
  'deer': null,
  'garlic': null, // produce but uncountable in practice
  'ginger': null,
  // add entries here as edge cases are found
};

/// Applies programmatic pluralization rules to a single [word].
///
/// Checks [_pluralExceptions] first; falls through to suffix rules.
/// Only called within the countable-category gate — uncountables never reach here.
String _pluralizeWord(String word) {
  final lower = word.toLowerCase();

  // Exceptions map: irregular plurals and invariants.
  if (_pluralExceptions.containsKey(lower)) {
    final override = _pluralExceptions[lower];
    if (override == null) return word; // invariant — return unchanged
    return _matchCase(word, override);
  }

  // Programmatic rules — first match wins.
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

/// Applies [_pluralizeWord] to the **last word only** of a multi-word name.
///
/// "sesame seed" → "sesame seeds"
/// "bay leaf"    → "bay leaves"
String _pluralizeLastWord(String name) {
  final words = name.split(' ');
  final pluralLast = _pluralizeWord(words.last);
  if (words.length == 1) return pluralLast;
  return '${words.sublist(0, words.length - 1).join(' ')} $pluralLast';
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
/// Returns [name] unchanged when [category] is not in [_countableCategories].
/// For countable categories, checks [_pluralExceptions] on the full name first,
/// then applies [_pluralizeLastWord] for general programmatic pluralization.
///
/// **Apply to heading display only — never to stored data.**
String pluralizeIngredient(String name, IngredientCategory category) {
  if (name.trim().isEmpty) return name;

  // Category gate: uncountable categories (spices, dairy, flour, oils, etc.)
  // are returned unchanged without consulting any rules or exceptions.
  if (!_countableCategories.contains(category)) return name;

  // Full-name exception check — handles invariant countables (e.g. "shrimp",
  // "garlic") and irregular multi-word names if ever added.
  final lower = name.toLowerCase();
  if (_pluralExceptions.containsKey(lower)) {
    final override = _pluralExceptions[lower];
    return override == null ? name : _matchCase(name, override);
  }

  // Apply programmatic rules to the last word only.
  return _pluralizeLastWord(name);
}
