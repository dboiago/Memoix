import 'package:isar/isar.dart';

part 'recipe.g.dart';

/// Source of the recipe
enum RecipeSource {
  memoix,    // From the official Memoix collection (GitHub)
  personal,  // User's own recipes
  imported,  // Shared with the user / imported
  ocr,       // Scanned from photo
  url,       // Imported from URL
}

@collection
class Recipe {
  Id id = Isar.autoIncrement;

  /// Unique identifier for sharing and syncing
  @Index(unique: true, replace: true)
  late String uuid;

  /// Recipe name (e.g., "Korean Fried Chicken")
  @Index(type: IndexType.value)
  late String name;

  /// Course category (e.g., "Mains", "Soups", "Desserts")
  @Index()
  late String course;

  /// Cuisine style (e.g., "Korean", "French", "Italian")
  @Index()
  String? cuisine;

  /// Subcategory within cuisine (e.g., "French" under "European")
  String? subcategory;

  /// Continent (e.g., "Asian", "European", "American")
  String? continent;

  /// Country/region (e.g., "Korea", "France", "Southern USA")
  String? country;

  /// Number of servings (e.g., "4-5 people", "2")
  String? serves;

  /// Prep/cook time (e.g., "40 min", "2 hr")
  String? time;

  /// What this dish pairs with (e.g., "KFC Sauce")
  List<String> pairsWith = [];

  /// Additional notes
  String? notes;

  /// List of ingredients (embedded)
  List<Ingredient> ingredients = [];

  /// Step-by-step directions
  List<String> directions = [];

  /// Source URL if imported from web
  String? sourceUrl;

  /// Image URL or local path
  String? imageUrl;

  /// Where this recipe came from
  @Enumerated(EnumType.name)
  RecipeSource source = RecipeSource.personal;

  /// Custom color override (stored as hex int)
  int? colorValue;

  /// When the recipe was created
  DateTime createdAt = DateTime.now();

  /// When the recipe was last modified
  DateTime updatedAt = DateTime.now();

  /// Whether this is a favourite
  bool isFavorite = false;

  /// User rating (1-5 stars, 0 = unrated)
  int rating = 0;

  /// Number of times this recipe has been cooked
  int cookCount = 0;

  /// When the recipe was last cooked
  DateTime? lastCookedAt;

  /// Tags for additional categorization
  List<String> tags = [];

  /// Version for sync conflict resolution
  int version = 1;

  /// Convenience constructor
  Recipe();

  /// Create a new recipe with required fields
  Recipe.create({
    required this.uuid,
    required this.name,
    required this.course,
    this.cuisine,
    this.subcategory,
    this.serves,
    this.time,
    this.pairsWith = const [],
    this.notes,
    this.ingredients = const [],
    this.directions = const [],
    this.sourceUrl,
    this.imageUrl,
    this.source = RecipeSource.personal,
    this.colorValue,
    this.isFavorite = false,
    this.rating = 0,
    this.cookCount = 0,
    this.lastCookedAt,
    this.tags = const [],
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Create from JSON (for GitHub import)
  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Clean up course field - remove "recipes" prefix if present
    String course = json['course'] as String;
    if (course.toLowerCase().contains('recipes')) {
      // Extract actual course name (e.g., "recipes   mains" -> "mains")
      course = course.replaceAll(RegExp(r'recipes\s*', caseSensitive: false), '').trim();
    }
    // Normalize course name to lowercase for consistency
    course = course.toLowerCase();
    
    // Normalize course names to match category slugs
    const courseMapping = {
      'soups': 'soup',
      'salads': 'salad',
      'not meat': 'vegan',
      'not-meat': 'vegan',
      'vegetarian': 'vegan',
      'drinks': 'drinks',
    };
    course = courseMapping[course] ?? course;

    final recipe = Recipe()
      ..uuid = json['uuid'] as String
      ..name = json['name'] as String
      ..course = course
      ..cuisine = json['cuisine'] as String?
      ..subcategory = json['subcategory'] as String?
      ..serves = json['serves'] as String?
      ..time = json['time'] as String?
      ..pairsWith = (json['pairsWith'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty && e != 'Pairs With')
              .toList() ??
          []
      ..notes = json['notes'] as String?
      ..ingredients = (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          []
      ..directions = (json['directions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty && e != 'Directions')
              .toList() ??
          []
      ..sourceUrl = json['sourceUrl'] as String?
      ..imageUrl = json['imageUrl'] as String?
      ..source = RecipeSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => RecipeSource.memoix,
      )
      ..colorValue = json['colorValue'] as int?
      ..isFavorite = json['isFavorite'] as bool? ?? false
      ..rating = json['rating'] as int? ?? 0
      ..cookCount = json['cookCount'] as int? ?? 0
      ..tags =
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              []
      ..version = json['version'] as int? ?? 1;

    if (json['createdAt'] != null) {
      recipe.createdAt = DateTime.parse(json['createdAt'] as String);
    }
    if (json['updatedAt'] != null) {
      recipe.updatedAt = DateTime.parse(json['updatedAt'] as String);
    }
    if (json['lastCookedAt'] != null) {
      recipe.lastCookedAt = DateTime.parse(json['lastCookedAt'] as String);
    }

    return recipe;
  }

  /// Convert to JSON (for sharing/export)
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'course': course,
      'cuisine': cuisine,
      'subcategory': subcategory,
      'serves': serves,
      'time': time,
      'pairsWith': pairsWith,
      'notes': notes,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'directions': directions,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'source': source.name,
      'colorValue': colorValue,
      'isFavorite': isFavorite,
      'rating': rating,
      'cookCount': cookCount,
      'lastCookedAt': lastCookedAt?.toIso8601String(),
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  /// Create a shareable copy (removes personal metadata)
  Map<String, dynamic> toShareableJson() {
    return {
      'uuid': uuid,
      'name': name,
      'course': course,
      'cuisine': cuisine,
      'subcategory': subcategory,
      'serves': serves,
      'time': time,
      'pairsWith': pairsWith,
      'notes': notes,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'directions': directions,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'tags': tags,
      'version': version,
    };
  }
}

/// Embedded ingredient model
@embedded
class Ingredient {
  /// Ingredient name (e.g., "White Beans")
  String name = '';

  /// Amount (e.g., "1", "2", "4-6")
  String? amount;

  /// Unit of measurement (e.g., "cup", "tbsp", "can")
  String? unit;

  /// Preparation notes (e.g., "diced", "minced", "cubed")
  String? preparation;

  /// Alternative/substitution (e.g., "alt: Olive oil", "alt: 1 C tomatoes")
  String? alternative;

  /// Whether this ingredient is optional
  bool isOptional = false;

  /// Section/group header (e.g., for grouping ingredients)
  String? section;

  Ingredient();

  Ingredient.create({
    required this.name,
    this.amount,
    this.unit,
    this.preparation,
    this.alternative,
    this.isOptional = false,
    this.section,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient()
      ..name = json['name'] as String
      ..amount = json['amount'] as String?
      ..unit = json['unit'] as String?
      ..preparation = json['preparation'] as String?
      ..alternative = json['alternative'] as String?
      ..isOptional = json['isOptional'] as bool? ?? false
      ..section = json['section'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'preparation': preparation,
      'alternative': alternative,
      'isOptional': isOptional,
      'section': section,
    };
  }

  /// Format ingredient for display (amount + name only)
  /// Preparation notes and alternatives are shown separately in the UI
  String get displayText {
    final buffer = StringBuffer();
    
    if (amount != null && amount!.isNotEmpty) {
      buffer.write(amount);
      if (unit != null && unit!.isNotEmpty) {
        buffer.write(' ');
        buffer.write(unit);
      }
      buffer.write(' ');
    }
    
    buffer.write(name);
    
    // Note: preparation, alternatives, and isOptional are displayed separately in the UI
    
    return buffer.toString();
  }

  /// Format amount with unit for display (e.g., "2 tbsp", "1 cup")
  String get displayAmount {
    final buffer = StringBuffer();
    
    if (amount != null && amount!.isNotEmpty) {
      buffer.write(amount);
      if (unit != null && unit!.isNotEmpty) {
        buffer.write(' ');
        buffer.write(unit);
      }
    }
    
    return buffer.toString();
  }
}
