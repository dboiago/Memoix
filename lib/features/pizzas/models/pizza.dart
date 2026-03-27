

/// Source of the pizza
enum PizzaSource {
  memoix,   // From the official Memoix collection (GitHub)
  personal, // User's own pizzas
  imported, // Shared with the user
}

/// Available pizza base sauces
enum PizzaBase {
  marinara,
  oil,
  pesto,
  cream,
  bbq,
  buffalo,
  alfredo,
  garlic,
  none,
}

extension PizzaBaseExtension on PizzaBase {
  /// Display name for the base
  String get displayName {
    switch (this) {
      case PizzaBase.marinara:
        return 'Marinara';
      case PizzaBase.oil:
        return 'Oil';
      case PizzaBase.pesto:
        return 'Pesto';
      case PizzaBase.cream:
        return 'Cream';
      case PizzaBase.bbq:
        return 'BBQ';
      case PizzaBase.buffalo:
        return 'Buffalo';
      case PizzaBase.alfredo:
        return 'Alfredo';
      case PizzaBase.garlic:
        return 'Garlic Butter';
      case PizzaBase.none:
        return 'No Sauce';
    }
  }

  /// Parse base from string (for JSON import)
  static PizzaBase fromString(String? value) {
    if (value == null || value.isEmpty) return PizzaBase.marinara;
    final lower = value.toLowerCase().trim();
    
    // Handle common variations
    if (lower.contains('marinara') || lower.contains('tomato') || lower == 'red') return PizzaBase.marinara;
    if (lower.contains('oil') || lower == 'evoo' || lower == 'olive') return PizzaBase.oil;
    if (lower.contains('pesto')) return PizzaBase.pesto;
    if (lower.contains('cream') || lower == 'white') return PizzaBase.cream;
    if (lower.contains('bbq') || lower.contains('barbeque') || lower.contains('barbecue')) return PizzaBase.bbq;
    if (lower.contains('buffalo') || lower.contains('hot sauce')) return PizzaBase.buffalo;
    if (lower.contains('alfredo')) return PizzaBase.alfredo;
    if (lower.contains('garlic')) return PizzaBase.garlic;
    if (lower == 'none' || lower == 'no sauce') return PizzaBase.none;
    
    return PizzaBase.marinara; // Default
  }
}


