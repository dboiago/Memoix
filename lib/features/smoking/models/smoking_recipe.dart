import 'package:isar/isar.dart';

part 'smoking_recipe.g.dart';

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
@embedded
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

/// A smoking recipe entity
@collection
class SmokingRecipe {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String name;

  /// Type of entry: Pit Note (quick reference) or Recipe (full recipe)
  @Enumerated(EnumType.name)
  SmokingType type = SmokingType.pitNote;

  /// The main item being smoked (e.g., "Brisket", "Pork Shoulder", "Mac & Cheese")
  @Index()
  String? item;

  /// Category of the item being smoked (e.g., "Beef", "Pork", "Desserts")
  /// Used for filtering and color-coded display
  @Index()
  String? category;

  /// Temperature for smoking (e.g., "275°F", "135°C")
  /// Required for Pit Notes, optional for Recipes
  String temperature = '';

  /// Smoking duration (e.g., "3 hrs", "6-8 hours")
  /// For Recipes, this is the total time field
  String time = '';

  /// Type of wood used (free-form text)
  /// Displayed as chips for Pit Notes
  @Index()
  String wood = '';

  /// Seasonings/rub ingredients (for Pit Notes - displayed as chips)
  List<SmokingSeasoning> seasonings = [];

  /// Full ingredients list (for Recipes - displayed like normal recipes)
  List<SmokingSeasoning> ingredients = [];

  /// Serving size (for Recipes)
  String? serves;

  /// Cooking directions
  List<String> directions = [];

  /// Optional notes
  String? notes;

  /// Main header image (shown in app bar)
  String? headerImage;

  /// Gallery images for steps (shown at bottom)
  List<String> stepImages = [];

  /// Map of step index to image index in stepImages
  /// Stored as "stepIndex:imageIndex" strings for Isar compatibility
  List<String> stepImageMap = [];

  /// Legacy: Optional image
  String? imageUrl;

  /// Whether this is a favorite
  bool isFavorite = false;

  /// How many times this has been cooked
  int cookCount = 0;

  /// Source of the recipe
  @Enumerated(EnumType.name)
  SmokingSource source = SmokingSource.personal;

  /// Timestamps
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  SmokingRecipe();

  /// Get all images (handles new structure and legacy fields)
  List<String> getAllImages() {
    final images = <String>[];
    if (headerImage != null && headerImage!.isNotEmpty) {
      images.add(headerImage!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      images.add(imageUrl!);
    }
    if (stepImages.isNotEmpty) {
      images.addAll(stepImages);
    }
    return images;
  }

  /// Get first image if available
  String? getFirstImage() {
    if (headerImage != null && headerImage!.isNotEmpty) return headerImage;
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    return null;
  }

  /// Get image index for a specific step (0-based)
  int? getStepImageIndex(int stepIndex) {
    for (final mapping in stepImageMap) {
      final parts = mapping.split(':');
      if (parts.length == 2) {
        final sIdx = int.tryParse(parts[0]);
        final iIdx = int.tryParse(parts[1]);
        if (sIdx == stepIndex && iIdx != null) {
          return iIdx;
        }
      }
    }
    return null;
  }

  /// Get the image path for a specific step
  String? getStepImage(int stepIndex) {
    final imageIndex = getStepImageIndex(stepIndex);
    if (imageIndex != null && imageIndex < stepImages.length) {
      return stepImages[imageIndex];
    }
    return null;
  }

  /// Set image association for a step
  void setStepImage(int stepIndex, int imageIndex) {
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
    stepImageMap.add('$stepIndex:$imageIndex');
  }

  /// Remove image association for a step
  void removeStepImage(int stepIndex) {
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
  }

  /// Factory constructor for creating with required fields
  static SmokingRecipe create({
    required String uuid,
    required String name,
    SmokingType type = SmokingType.pitNote,
    String? item,
    String? category,
    String temperature = '',
    String time = '',
    String wood = '',
    List<SmokingSeasoning>? seasonings,
    List<SmokingSeasoning>? ingredients,
    String? serves,
    List<String>? directions,
    String? notes,
    String? headerImage,
    List<String>? stepImages,
    List<String>? stepImageMap,
    String? imageUrl,
    bool isFavorite = false,
    int cookCount = 0,
    SmokingSource source = SmokingSource.personal,
  }) {
    return SmokingRecipe()
      ..uuid = uuid
      ..name = name
      ..type = type
      ..item = item
      ..category = category
      ..temperature = temperature
      ..time = time
      ..wood = wood
      ..seasonings = seasonings ?? []
      ..ingredients = ingredients ?? []
      ..serves = serves
      ..directions = directions ?? []
      ..notes = notes
      ..headerImage = headerImage
      ..stepImages = stepImages ?? []
      ..stepImageMap = stepImageMap ?? []
      ..imageUrl = imageUrl
      ..isFavorite = isFavorite
      ..cookCount = cookCount
      ..source = source
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'type': type.name,
      'item': item,
      'category': category,
      'temperature': temperature,
      'time': time,
      'wood': wood,
      'seasonings': seasonings.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'unit': s.unit,
      },).toList(),
      'ingredients': ingredients.map((i) => {
        'name': i.name,
        'amount': i.amount,
        'unit': i.unit,
      },).toList(),
      'serves': serves,
      'directions': directions,
      'notes': notes,
      'headerImage': headerImage,
      'stepImages': stepImages,
      'stepImageMap': stepImageMap,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
      'cookCount': cookCount,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SmokingRecipe.fromJson(Map<String, dynamic> json) {
    return SmokingRecipe()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..type = SmokingType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SmokingType.pitNote,
      )
      ..item = json['item'] as String?
      ..category = json['category'] as String?
      ..temperature = json['temperature'] as String? ?? ''
      ..time = json['time'] as String? ?? ''
      ..wood = json['wood'] as String? ?? ''
      ..seasonings = (json['seasonings'] as List<dynamic>?)
          ?.map((s) => SmokingSeasoning()
            ..name = s['name'] as String? ?? ''
            ..amount = s['amount'] as String?
            ..unit = s['unit'] as String?)
          .toList() ?? []
      ..ingredients = (json['ingredients'] as List<dynamic>?)
          ?.map((i) => SmokingSeasoning()
            ..name = i['name'] as String? ?? ''
            ..amount = i['amount'] as String?
            ..unit = i['unit'] as String?)
          .toList() ?? []
      ..serves = json['serves'] as String?
      ..directions = (json['directions'] as List<dynamic>?)
          ?.map((d) => d as String)
          .toList() ?? []
      ..notes = json['notes'] as String?
      ..headerImage = json['headerImage'] as String?
      ..stepImages = (json['stepImages'] as List<dynamic>?)
          ?.map((s) => s as String)
          .toList() ?? []
      ..stepImageMap = (json['stepImageMap'] as List<dynamic>?)
          ?.map((s) => s as String)
          .toList() ?? []
      ..imageUrl = json['imageUrl'] as String?
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..cookCount = json['cookCount'] as int? ?? 0
      ..source = SmokingSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => SmokingSource.personal,
      );
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'type': type.name,
      'item': item,
      'category': category,
      'temperature': temperature,
      'time': time,
      'wood': wood,
      'seasonings': seasonings.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'unit': s.unit,
      },).toList(),
      'ingredients': ingredients.map((i) => {
        'name': i.name,
        'amount': i.amount,
        'unit': i.unit,
      },).toList(),
      'serves': serves,
      'directions': directions,
      'notes': notes,
    };
  }
}
