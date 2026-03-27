

/// Type of smoking entry
enum SmokingType {
  pitNote,  // Quick reference cards (temp, wood, seasonings)
  recipe,   // Full recipes with ingredients and directions
}

extension SmokingTypeExtension on SmokingType {
  String get displayName {
    switch (this) {
      case SmokingType.pitNote:
        return 'Pit Note';
      case SmokingType.recipe:
        return 'Recipe';
    }
  }

  /// Parse from string
  static SmokingType fromString(String? value) {
    if (value == null || value.isEmpty) return SmokingType.pitNote;
    final lower = value.toLowerCase().trim();
    if (lower == 'recipe') return SmokingType.recipe;
    return SmokingType.pitNote;
  }
}

/// Categories for smoked items (what's being smoked)
/// Each category has its own color dot for visual identification
class SmokingCategory {
  SmokingCategory._();

  static const String beef = 'Beef';
  static const String pork = 'Pork';
  static const String poultry = 'Poultry';
  static const String lamb = 'Lamb';
  static const String game = 'Game';
  static const String seafood = 'Seafood';
  static const String vegetables = 'Vegetables';
  static const String cheese = 'Cheese';
  static const String desserts = 'Desserts';
  static const String fruits = 'Fruits';
  static const String dips = 'Dips';
  static const String other = 'Other';

  /// All available categories
  static const List<String> all = [
    beef,
    pork,
    poultry,
    lamb,
    game,
    seafood,
    vegetables,
    cheese,
    desserts,
    fruits,
    dips,
    other,
  ];

  /// Common items for each category (for autocomplete)
  static const Map<String, List<String>> items = {
    beef: ['Brisket', 'Beef Ribs', 'Tri-Tip', 'Prime Rib', 'Chuck Roast', 'Beef Cheeks', 'Burnt Ends'],
    pork: ['Pork Shoulder', 'Pork Butt', 'Spare Ribs', 'Baby Back Ribs', 'Pork Belly', 'Pork Loin', 'Ham', 'Pork Chops', 'Pulled Pork'],
    poultry: ['Whole Chicken', 'Chicken Wings', 'Chicken Thighs', 'Turkey', 'Turkey Breast', 'Duck', 'Cornish Hen', 'Spatchcock Chicken'],
    lamb: ['Leg of Lamb', 'Lamb Shoulder', 'Lamb Ribs', 'Lamb Chops', 'Rack of Lamb'],
    game: ['Venison', 'Elk', 'Wild Boar', 'Rabbit', 'Pheasant', 'Quail', 'Goose', 'Buffalo'],
    seafood: ['Salmon', 'Trout', 'Shrimp', 'Oysters', 'Scallops', 'Lobster Tails', 'Swordfish', 'Tuna', 'Mahi Mahi'],
    vegetables: ['Corn', 'Peppers', 'Onions', 'Tomatoes', 'Cabbage', 'Mushrooms', 'Artichokes', 'Potatoes', 'Cauliflower'],
    cheese: ['Gouda', 'Cheddar', 'Mozzarella', 'Provolone', 'Brie', 'Cream Cheese', 'Pepper Jack'],
    desserts: ['Bread Pudding', 'Brownies', 'Cheesecake', 'Pie', 'Peach Cobbler', 'Cinnamon Rolls'],
    fruits: ['Peaches', 'Apples', 'Pineapple', 'Bananas', 'Pears', 'Plums', 'Watermelon'],
    dips: ['Queso', 'Mac & Cheese', 'Baked Beans', 'Salsa', 'Guacamole', 'Hummus'],
    other: ['Nuts', 'Jerky', 'Sausage', 'Bologna', 'Meatloaf', 'Fatties', 'Bacon'],
  };

  /// Get all item suggestions for autocomplete
  static List<String> getAllItems() {
    final all = <String>[];
    for (final list in items.values) {
      all.addAll(list);
    }
    return all..sort();
  }

  /// Get suggestions matching a query
  static List<String> getSuggestions(String query) {
    final allItems = getAllItems();
    if (query.isEmpty) return allItems.take(10).toList();
    final lower = query.toLowerCase();
    return allItems.where((i) => i.toLowerCase().contains(lower)).toList();
  }

  /// Get category for an item (if known)
  static String? getCategoryForItem(String item) {
    final lower = item.toLowerCase();
    for (final entry in items.entries) {
      if (entry.value.any((i) => i.toLowerCase() == lower)) {
        return entry.key;
      }
    }
    return null;
  }
}

/// Common wood suggestions for autocomplete
/// Users can enter any wood type they want
class WoodSuggestions {
  WoodSuggestions._();

  static const List<String> common = [
    'Hickory',
    'Mesquite',
    'Apple',
    'Cherry',
    'Pecan',
    'Oak',
    'Maple',
    'Alder',
    'Peach',
    'Pear',
    'Walnut',
    'Mulberry',
    'Olive',
    'Grapevine',
    'Beech',
    'Ash',
    'Birch',
    'Chestnut',
    'Citrus',
    'Fig',
    'Lemon',
    'Nectarine',
    'Plum',
    'Apricot',
  ];

  /// Get suggestions matching a query
  static List<String> getSuggestions(String query) {
    if (query.isEmpty) return common;
    final lower = query.toLowerCase();
    return common.where((w) => w.toLowerCase().contains(lower)).toList();
  }
}

/// Source of the smoking recipe
enum SmokingSource {
  memoix,    // From official collection
  personal,  // User created
  imported,  // Shared from others
}

/// Seasoning/rub ingredient for smoking
class SmokingSeasoning {
  String name = '';
  String? amount;
  String? unit;
  
  SmokingSeasoning();
  
  SmokingSeasoning.create({
    required this.name,
    this.amount,
    this.unit,
  });

  /// Display string like "2 Tbsp Sugar" or just "Salt"
  String get displayText {
    final parts = <String>[];
    if (amount != null && amount!.isNotEmpty) {
      parts.add(amount!);
    }
    if (unit != null && unit!.isNotEmpty) {
      parts.add(unit!);
    }
    parts.add(name);
    return parts.join(' ');
  }
}

