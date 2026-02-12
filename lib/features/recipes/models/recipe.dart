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
  /// @deprecated Use pairedRecipeIds instead for proper linking
  List<String> pairsWith = [];

  /// Linked recipe UUIDs for bi-directional pairing
  /// Stores IDs of recipes this recipe pairs with (e.g., a Main links to a Sauce)
  List<String> pairedRecipeIds = [];

  /// Additional comments (author notes, tips, etc.)
  String? comments;

  /// List of ingredients (embedded)
  List<Ingredient> ingredients = [];

  /// Step-by-step directions
  List<String> directions = [];

  /// Source URL if imported from web
  String? sourceUrl;

  /// Image URLs or local paths (supports multiple images)
  List<String> imageUrls = [];

  /// Deprecated: single image URL (kept for backwards compatibility)
  /// Use imageUrls instead
  String? imageUrl;

  /// Main header image (shown in app bar)
  String? headerImage;

  /// Gallery images for steps (shown at bottom)
  List<String> stepImages = [];

  /// Map of step index to image index in stepImages
  /// Stored as "stepIndex:imageIndex" strings for Isar compatibility
  List<String> stepImageMap = [];

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

  /// Number of times this recipe has been re-saved after initial creation
  int editCount = 0;

  /// When the first edit (re-save) occurred
  DateTime? firstEditAt;

  /// When the most recent edit (re-save) occurred
  DateTime? lastEditAt;

  /// When the recipe was last cooked
  DateTime? lastCookedAt;

  /// Tags for additional categorization
  List<String> tags = [];

  /// Version for sync conflict resolution
  int version = 1;

  /// Nutrition information (optional, imported from URL or user-added)
  NutritionInfo? nutrition;


  /// Modernist type (e.g., "Concept", "Technique")
  String? modernistType;

  /// Smoking type (e.g., "Recipe", "Pit Note")
  String? smokingType;

  /// Glass type for drinks (e.g., "Coupe", "Highball", "Rocks")
  String? glass;

  /// Garnish list for drinks (e.g., ["Lemon twist", "Cherry"])
  List<String> garnish = [];

  /// Pickle method for pickles (e.g., "Pickle", "Brine", "Fermentation")
  String? pickleMethod;

  /// Whether this recipe type supports pairing with other recipes.
  /// Excluded: Pizzas, Sandwiches, Cellar, Cheese (component assemblies or non-recipes)
  @ignore
  bool get supportsPairing {
    const excludedCourses = {'pizzas', 'sandwiches', 'cellar', 'cheese'};
    return !excludedCourses.contains(course.toLowerCase());
  }

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
    this.comments,
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
    this.nutrition,
    this.glass,
    this.garnish = const [],
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
      'not meat': 'vegn',
      'not-meat': 'vegn',
      'vegetarian': 'vegn',
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
      ..pairedRecipeIds = (json['pairedRecipeIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .where((e) => e.isNotEmpty)
              .toList() ??
          []
      ..comments = (json['comments'] ?? json['notes']) as String?  // Backwards compatible with 'notes'
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
      ..imageUrls = (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
      ..headerImage = json['headerImage'] as String?
      ..stepImages = (json['stepImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
      ..stepImageMap = (json['stepImageMap'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
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
      ..version = json['version'] as int? ?? 1
      ..nutrition = json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null
      ..glass = json['glass'] as String?
      ..garnish = (json['garnish'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          []
      ..pickleMethod = json['pickleMethod'] as String?;

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
      'pairedRecipeIds': pairedRecipeIds,
      'notes': comments,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'directions': directions,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'headerImage': headerImage,
      'stepImages': stepImages,
      'stepImageMap': stepImageMap,
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
      if (nutrition != null) 'nutrition': nutrition!.toJson(),
      if (glass != null) 'glass': glass,
      if (garnish.isNotEmpty) 'garnish': garnish,
      if (pickleMethod != null) 'pickleMethod': pickleMethod,
    };
  }

  /// Get all images (handles both new imageUrls and legacy imageUrl fields)
  List<String> getAllImages() {
    final images = <String>[];
    if (headerImage != null && headerImage!.isNotEmpty) {
      images.add(headerImage!);
    } else if (imageUrls.isNotEmpty) {
      images.addAll(imageUrls);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      images.add(imageUrl!);
    }
    if (stepImages.isNotEmpty) {
      images.addAll(stepImages);
    }
    return images;
  }

  /// Check if recipe has any images
  bool hasImages() => getAllImages().isNotEmpty;

  /// Get first image if available
  String? getFirstImage() {
    if (headerImage != null && headerImage!.isNotEmpty) return headerImage;
    final images = getAllImages();
    return images.isNotEmpty ? images.first : null;
  }

  /// Get image index for a specific step (0-based)
  /// Returns null if no image is associated with this step
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
    // Remove existing mapping for this step
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
    // Add new mapping
    stepImageMap.add('$stepIndex:$imageIndex');
  }

  /// Remove image association for a step
  void removeStepImage(int stepIndex) {
    stepImageMap.removeWhere((m) => m.startsWith('$stepIndex:'));
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
      'pairedRecipeIds': pairedRecipeIds,
      'notes': comments,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'directions': directions,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'tags': tags,
      'version': version,
      if (nutrition != null) 'nutrition': nutrition!.toJson(),
      if (glass != null) 'glass': glass,
      if (garnish.isNotEmpty) 'garnish': garnish,
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

  /// Baker's percentage (e.g., "100%", "75%") - for bread/dough recipes
  String? bakerPercent;

  Ingredient();

  Ingredient.create({
    required this.name,
    this.amount,
    this.unit,
    this.preparation,
    this.alternative,
    this.isOptional = false,
    this.section,
    this.bakerPercent,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient()
      ..name = json['name'] as String
      ..amount = json['amount'] as String?
      ..unit = json['unit'] as String?
      ..preparation = json['preparation'] as String?
      ..alternative = json['alternative'] as String?
      ..isOptional = json['isOptional'] as bool? ?? false
      ..section = json['section'] as String?
      ..bakerPercent = json['bakerPercent'] as String?;
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
      'bakerPercent': bakerPercent,
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

/// Embedded nutrition information model
/// Based on schema.org NutritionInformation
@embedded
class NutritionInfo {
  /// Serving size description (e.g., "1 serving", "100g")
  String? servingSize;
  
  /// Calories per serving
  int? calories;
  
  /// Total fat in grams
  double? fatContent;
  
  /// Saturated fat in grams
  double? saturatedFatContent;
  
  /// Trans fat in grams
  double? transFatContent;
  
  /// Cholesterol in milligrams
  double? cholesterolContent;
  
  /// Sodium in milligrams
  double? sodiumContent;
  
  /// Total carbohydrates in grams
  double? carbohydrateContent;
  
  /// Dietary fiber in grams
  double? fiberContent;
  
  /// Sugars in grams
  double? sugarContent;
  
  /// Protein in grams
  double? proteinContent;

  NutritionInfo();

  NutritionInfo.create({
    this.servingSize,
    this.calories,
    this.fatContent,
    this.saturatedFatContent,
    this.transFatContent,
    this.cholesterolContent,
    this.sodiumContent,
    this.carbohydrateContent,
    this.fiberContent,
    this.sugarContent,
    this.proteinContent,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo()
      ..servingSize = json['servingSize'] as String?
      ..calories = _parseNumber(json['calories'])?.round()
      ..fatContent = _parseNumber(json['fatContent'])
      ..saturatedFatContent = _parseNumber(json['saturatedFatContent'])
      ..transFatContent = _parseNumber(json['transFatContent'])
      ..cholesterolContent = _parseNumber(json['cholesterolContent'])
      ..sodiumContent = _parseNumber(json['sodiumContent'])
      ..carbohydrateContent = _parseNumber(json['carbohydrateContent'])
      ..fiberContent = _parseNumber(json['fiberContent'])
      ..sugarContent = _parseNumber(json['sugarContent'])
      ..proteinContent = _parseNumber(json['proteinContent']);
  }

  /// Parse a nutrition value that might be a number or string like "20 g"
  static double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Extract number from strings like "20 g", "150 kcal", etc.
      final match = RegExp(r'([\d.]+)').firstMatch(value);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (servingSize != null) 'servingSize': servingSize,
      if (calories != null) 'calories': calories,
      if (fatContent != null) 'fatContent': fatContent,
      if (saturatedFatContent != null) 'saturatedFatContent': saturatedFatContent,
      if (transFatContent != null) 'transFatContent': transFatContent,
      if (cholesterolContent != null) 'cholesterolContent': cholesterolContent,
      if (sodiumContent != null) 'sodiumContent': sodiumContent,
      if (carbohydrateContent != null) 'carbohydrateContent': carbohydrateContent,
      if (fiberContent != null) 'fiberContent': fiberContent,
      if (sugarContent != null) 'sugarContent': sugarContent,
      if (proteinContent != null) 'proteinContent': proteinContent,
    };
  }

  /// Check if any nutrition data is available
  bool get hasData =>
      calories != null ||
      fatContent != null ||
      carbohydrateContent != null ||
      proteinContent != null;

  /// Format for compact display (e.g., "150 cal")
  String? get compactDisplay {
    if (calories != null) return '$calories cal';
    return null;
  }
}
