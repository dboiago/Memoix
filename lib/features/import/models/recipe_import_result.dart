import '../../modernist/models/modernist_recipe.dart';
import '../../pizzas/models/pizza.dart';
import '../../recipes/models/recipe.dart';
import '../../smoking/models/smoking_recipe.dart';

/// Result of importing a recipe from URL or OCR
/// Contains both parsed data and raw extracted data for user review
class RecipeImportResult {
  /// Parsed recipe fields (best guess)
  final String? name;
  final String? course;
  final String? cuisine;
  final String? subcategory;
  final String? serves;
  final String? time;
  final List<Ingredient> ingredients;
  final List<String> directions;
  final String? notes;
  final String? imageUrl;
  final NutritionInfo? nutrition;
  
  /// Special equipment required (for Modernist recipes)
  final List<String> equipment;

  /// Glass type for drinks
  final String? glass;

  /// Garnish list for drinks
  final List<String> garnish;

  /// Raw extracted data for user mapping/review
  final List<RawIngredientData> rawIngredients;
  final List<String> rawDirections;
  final String? rawText; // For OCR - the original extracted text
  final List<String> textBlocks; // For OCR - individual text blocks

  /// Detected options for user selection
  final List<String> detectedCourses;
  final List<String> detectedCuisines;

  /// Confidence scores (0.0 - 1.0)
  final double nameConfidence;
  final double courseConfidence;
  final double cuisineConfidence;
  final double ingredientsConfidence;
  final double directionsConfidence;
  final double servesConfidence;
  final double timeConfidence;

  /// Source information
  final String? sourceUrl;
  final RecipeSource source;

  /// Image paths (for multi-image imports)
  List<String>? imagePaths;

  RecipeImportResult({
    this.name,
    this.course,
    this.cuisine,
    this.subcategory,
    this.serves,
    this.time,
    this.ingredients = const [],
    this.directions = const [],
    this.notes,
    this.imageUrl,
    this.nutrition,
    this.equipment = const [],
    this.glass,
    this.garnish = const [],
    this.rawIngredients = const [],
    this.rawDirections = const [],
    this.rawText,
    this.textBlocks = const [],
    this.detectedCourses = const [],
    this.detectedCuisines = const [],
    this.nameConfidence = 0.0,
    this.courseConfidence = 0.0,
    this.cuisineConfidence = 0.0,
    this.ingredientsConfidence = 0.0,
    this.directionsConfidence = 0.0,
    this.servesConfidence = 0.0,
    this.timeConfidence = 0.0,
    this.sourceUrl,
    this.source = RecipeSource.url,
    this.imagePaths,
  });

  /// Overall confidence score (weighted average of core fields, optional fields can only boost)
  double get overallConfidence {
    // Core required fields - these determine the base confidence
    const coreWeights = {
      'name': 0.25,
      'ingredients': 0.30,
      'directions': 0.30,
      'course': 0.15,
    };

    // Calculate base confidence from core fields
    final double baseConfidence = (nameConfidence * coreWeights['name']!) +
        (ingredientsConfidence * coreWeights['ingredients']!) +
        (directionsConfidence * coreWeights['directions']!) +
        (courseConfidence * coreWeights['course']!);
    
    // Optional fields can only boost confidence (up to 10% bonus)
    // Each optional field found with good confidence adds a small bonus
    double optionalBonus = 0.0;
    if (cuisineConfidence > 0.5) optionalBonus += 0.03;
    if (servesConfidence > 0.5) optionalBonus += 0.03;
    if (timeConfidence > 0.5) optionalBonus += 0.04;
    
    return (baseConfidence + optionalBonus).clamp(0.0, 1.0);
  }

  /// Whether this result needs user review (confidence below threshold)
  bool get needsUserReview => overallConfidence < 0.7;

  /// Whether we have enough data to create a recipe
  bool get hasMinimumData =>
      name != null &&
      name!.isNotEmpty &&
      (ingredients.isNotEmpty || directions.isNotEmpty);

  /// Fields that need attention (low confidence on required/important fields)
  /// Excludes optional fields like cuisine, serves, time
  List<String> get fieldsNeedingAttention {
    final fields = <String>[];
    if (nameConfidence < 0.5) fields.add('name');
    if (ingredientsConfidence < 0.5) fields.add('ingredients');
    if (directionsConfidence < 0.5) fields.add('directions');
    if (courseConfidence < 0.5) fields.add('course');
    // Don't include optional fields: cuisine, serves, time
    return fields;
  }

  /// Convert to a Recipe (for high-confidence imports)
  Recipe toRecipe(String uuid) {
    final recipe = Recipe.create(
      uuid: uuid,
      name: name ?? 'Untitled Recipe',
      course: course ?? 'Mains',
      cuisine: cuisine,
      subcategory: subcategory,
      serves: serves,
      time: time,
      ingredients: ingredients,
      directions: directions,
      notes: notes,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      source: source,
      nutrition: nutrition,
      glass: glass,
      garnish: garnish,
    );
    
    // Set multiple images if available
    // First image becomes the header, rest go to step images gallery
    if (imagePaths != null && imagePaths!.isNotEmpty) {
      recipe.headerImage = imagePaths!.first;
      if (imagePaths!.length > 1) {
        recipe.stepImages = imagePaths!.sublist(1);
      }
    }
    
    return recipe;
  }

  /// Convert to a ModernistRecipe (for high-confidence Modernist imports)
  ModernistRecipe toModernistRecipe(String uuid) {
    // Convert regular ingredients to ModernistIngredients, preserving sections
    final modernistIngredients = ingredients.map((i) => ModernistIngredient.create(
      name: i.name,
      amount: i.amount,
      unit: i.unit,
      notes: i.preparation,
      section: i.section,
    )).toList();

    final recipe = ModernistRecipe.create(
      uuid: uuid,
      name: name ?? 'Untitled Recipe',
      type: ModernistType.concept, // Default to concept
      serves: serves,
      time: time,
      equipment: equipment,
      ingredients: modernistIngredients,
      directions: directions,
      notes: notes,
      sourceUrl: sourceUrl,
      headerImage: imageUrl,
      source: ModernistSource.imported,
    );
    
    // Set multiple images if available
    if (imagePaths != null && imagePaths!.isNotEmpty) {
      recipe.headerImage = imagePaths!.first;
      if (imagePaths!.length > 1) {
        recipe.stepImages = imagePaths!.sublist(1);
      }
    }
    
    return recipe;
  }

  /// Convert to a SmokingRecipe (for high-confidence Smoking imports)
  SmokingRecipe toSmokingRecipe(String uuid) {
    // Try to detect wood type from ingredients or notes
    String woodType = 'Hickory'; // Default
    final allText = [...directions, notes ?? '', ...ingredients.map((i) => i.name)].join(' ').toLowerCase();
    for (final wood in WoodSuggestions.common) {
      if (allText.contains(wood.toLowerCase())) {
        woodType = wood;
        break;
      }
    }
    
    // Try to detect temperature from directions or notes
    String temperature = '';
    final tempMatch = RegExp(r'(\d{2,3})\s*[°]?\s*[FCfc]').firstMatch(allText);
    if (tempMatch != null) {
      temperature = tempMatch.group(0) ?? '';
    }
    
    // Convert ingredients to seasonings
    final seasonings = ingredients.map((i) => SmokingSeasoning.create(
      name: i.name,
      amount: i.amount,
      unit: i.unit,
    )).toList();

    final recipe = SmokingRecipe.create(
      uuid: uuid,
      name: name ?? 'Untitled Recipe',
      item: name, // Use recipe name as item being smoked
      temperature: temperature,
      time: time ?? '',
      wood: woodType,
      seasonings: seasonings,
      directions: directions,
      notes: notes,
      headerImage: imageUrl,
      source: SmokingSource.imported,
    );
    
    // Set multiple images if available
    if (imagePaths != null && imagePaths!.isNotEmpty) {
      recipe.headerImage = imagePaths!.first;
      if (imagePaths!.length > 1) {
        recipe.stepImages = imagePaths!.sublist(1);
      }
    }
    
    return recipe;
  }

  /// Convert to a Pizza (for high-confidence Pizza imports)
  Pizza toPizzaRecipe(String uuid) {
    // Try to detect base sauce from ingredients
    PizzaBase base = PizzaBase.marinara; // Default
    final allIngredients = ingredients.map((i) => i.name.toLowerCase()).join(' ');
    if (allIngredients.contains('pesto')) {
      base = PizzaBase.pesto;
    } else if (allIngredients.contains('cream') || allIngredients.contains('alfredo')) {
      base = PizzaBase.cream;
    } else if (allIngredients.contains('bbq') || allIngredients.contains('barbecue')) {
      base = PizzaBase.bbq;
    } else if (allIngredients.contains('buffalo')) {
      base = PizzaBase.buffalo;
    } else if (allIngredients.contains('garlic') && allIngredients.contains('butter')) {
      base = PizzaBase.garlic;
    } else if (allIngredients.contains('oil') || allIngredients.contains('olive')) {
      base = PizzaBase.oil;
    }
    
    // Separate cheeses from other toppings
    final cheeses = <String>[];
    final toppings = <String>[];
    const cheeseKeywords = ['mozzarella', 'parmesan', 'cheddar', 'gouda', 'provolone', 
        'ricotta', 'gorgonzola', 'feta', 'goat cheese', 'burrata', 'fontina', 'asiago',
        'pecorino', 'gruyere', 'brie', 'cheese'];
    
    for (final ingredient in ingredients) {
      final lower = ingredient.name.toLowerCase();
      final isCheese = cheeseKeywords.any((c) => lower.contains(c));
      if (isCheese) {
        cheeses.add(ingredient.name);
      } else {
        // Skip base sauce ingredients
        if (!lower.contains('sauce') && !lower.contains('dough') && 
            !lower.contains('flour') && !lower.contains('yeast')) {
          toppings.add(ingredient.name);
        }
      }
    }

    return Pizza.create(
      uuid: uuid,
      name: name ?? 'Untitled Pizza',
      base: base,
      cheeses: cheeses,
      toppings: toppings,
      notes: notes,
      imageUrl: imageUrl,
      source: PizzaSource.imported,
    );
  }
  RecipeImportResult copyWith({
    String? name,
    String? course,
    String? cuisine,
    String? subcategory,
    String? serves,
    String? time,
    List<Ingredient>? ingredients,
    List<String>? directions,
    String? notes,
    String? imageUrl,
    NutritionInfo? nutrition,
    List<String>? equipment,
    String? glass,
    List<String>? garnish,
    List<RawIngredientData>? rawIngredients,
    List<String>? rawDirections,
    String? rawText,
    List<String>? textBlocks,
    List<String>? detectedCourses,
    List<String>? detectedCuisines,
    double? nameConfidence,
    double? courseConfidence,
    double? cuisineConfidence,
    double? ingredientsConfidence,
    double? directionsConfidence,
    double? servesConfidence,
    double? timeConfidence,
    String? sourceUrl,
    RecipeSource? source,
    List<String>? imagePaths,
  }) {
    return RecipeImportResult(
      name: name ?? this.name,
      course: course ?? this.course,
      cuisine: cuisine ?? this.cuisine,
      subcategory: subcategory ?? this.subcategory,
      serves: serves ?? this.serves,
      time: time ?? this.time,
      ingredients: ingredients ?? this.ingredients,
      directions: directions ?? this.directions,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      nutrition: nutrition ?? this.nutrition,
      equipment: equipment ?? this.equipment,
      glass: glass ?? this.glass,
      garnish: garnish ?? this.garnish,
      rawIngredients: rawIngredients ?? this.rawIngredients,
      rawDirections: rawDirections ?? this.rawDirections,
      rawText: rawText ?? this.rawText,
      textBlocks: textBlocks ?? this.textBlocks,
      detectedCourses: detectedCourses ?? this.detectedCourses,
      detectedCuisines: detectedCuisines ?? this.detectedCuisines,
      nameConfidence: nameConfidence ?? this.nameConfidence,
      courseConfidence: courseConfidence ?? this.courseConfidence,
      cuisineConfidence: cuisineConfidence ?? this.cuisineConfidence,
      ingredientsConfidence: ingredientsConfidence ?? this.ingredientsConfidence,
      directionsConfidence: directionsConfidence ?? this.directionsConfidence,
      servesConfidence: servesConfidence ?? this.servesConfidence,
      timeConfidence: timeConfidence ?? this.timeConfidence,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      source: source ?? this.source,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}

/// A raw ingredient from import, before classification
class RawIngredientData {
  /// Original text as extracted
  final String original;

  /// Parsed amount (if detected)
  final String? amount;

  /// Parsed unit (if detected)
  final String? unit;

  /// Preparation notes (e.g., "diced", "room temperature", or imperial conversion)
  final String? preparation;

  /// Baker's percentage (e.g., "100%", "75%", "3.3%") - for bread recipes
  final String? bakerPercent;

  /// Ingredient name
  final String name;

  /// Whether this looks like an ingredient (vs section header, note, etc.)
  final bool looksLikeIngredient;

  /// Whether this looks like a section header
  final bool isSection;

  /// Detected section name if this is a header
  final String? sectionName;

  /// Whether user has marked this as an ingredient to include
  bool isSelected;

  RawIngredientData({
    required this.original,
    this.amount,
    this.unit,
    this.preparation,
    this.bakerPercent,
    required this.name,
    this.looksLikeIngredient = true,
    this.isSection = false,
    this.sectionName,
    this.isSelected = true,
  });

  /// Convert to Ingredient
  Ingredient toIngredient({String? section}) {
    return Ingredient.create(
      name: name,
      amount: amount,
      unit: unit,
      preparation: preparation,
      section: section ?? sectionName,
      bakerPercent: bakerPercent,
    );
  }
  
  /// Check if this ingredient entry is valid (not empty/garbage)
  bool get isValid {
    // Section headers are valid if they have a section name
    if (sectionName != null && sectionName!.trim().isNotEmpty) {
      return true;
    }
    // Regular ingredients need a meaningful name with at least one letter/number
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(cleanName)) return false;
    return true;
  }
  
  /// Sanitize a list of raw ingredients, removing invalid and duplicate entries
  static List<RawIngredientData> sanitize(List<RawIngredientData> ingredients) {
    // First, collect all section names
    final sectionNames = ingredients
        .where((i) => i.sectionName != null && i.sectionName!.trim().isNotEmpty)
        .map((i) => i.sectionName!.toLowerCase().trim())
        .toSet();
    
    // Filter out invalid entries AND entries whose name duplicates a section header
    return ingredients.where((i) {
      if (!i.isValid) return false;
      
      // If this is a section header, keep it
      if (i.sectionName != null && i.sectionName!.trim().isNotEmpty) {
        return true;
      }
      
      // If this ingredient's name matches any section header, it's a duplicate - remove it
      final cleanName = i.name.trim().toLowerCase();
      if (sectionNames.contains(cleanName)) {
        return false;
      }
      
      // Also check if it looks like a section header that wasn't properly detected
      // (no amount, no unit, name doesn't look like an ingredient)
      if (i.amount == null && i.unit == null && i.preparation == null) {
        // If it's a short name with no measurements and matches common header patterns, skip it
        if (cleanName.length < 50 && !_looksLikeIngredientName(cleanName)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }
  
  /// Check if a name looks like an actual ingredient (vs a section header)
  static bool _looksLikeIngredientName(String name) {
    final lower = name.toLowerCase();
    
    // Common ingredient words/patterns
    final ingredientPatterns = [
      'salt', 'pepper', 'sugar', 'flour', 'oil', 'butter', 'egg', 'milk', 'cream',
      'water', 'stock', 'broth', 'garlic', 'onion', 'tomato', 'cheese', 'chicken',
      'beef', 'pork', 'fish', 'rice', 'pasta', 'bread', 'sauce', 'vinegar', 'lemon',
      'lime', 'orange', 'vanilla', 'chocolate', 'honey', 'yeast', 'powder', 'extract',
    ];
    
    for (final pattern in ingredientPatterns) {
      if (lower.contains(pattern)) return true;
    }
    
    // If it contains numbers or measurement-like text, it's likely an ingredient
    if (RegExp(r'\d').hasMatch(name)) return true;
    if (RegExp(r'\b(cup|tbsp|tsp|oz|lb|g|kg|ml|l)\b', caseSensitive: false).hasMatch(name)) return true;
    
    return false;
  }
}

/// A raw direction from import
class RawDirectionData {
  /// Original text as extracted
  final String original;

  /// Whether this looks like a direction step
  final bool looksLikeStep;

  /// Whether this looks like a section header
  final bool isSection;

  /// Step number if detected
  final int? stepNumber;

  /// Whether user has marked this to include
  bool isSelected;

  RawDirectionData({
    required this.original,
    this.looksLikeStep = true,
    this.isSection = false,
    this.stepNumber,
    this.isSelected = true,
  });
}
