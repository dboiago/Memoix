import '../../recipes/models/recipe.dart';

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

  /// Overall confidence score (weighted average)
  double get overallConfidence {
    // Weight the most important fields higher
    const weights = {
      'name': 0.20,
      'ingredients': 0.25,
      'directions': 0.25,
      'course': 0.10,
      'cuisine': 0.05,
      'serves': 0.05,
      'time': 0.10,
    };

    return (nameConfidence * weights['name']!) +
        (ingredientsConfidence * weights['ingredients']!) +
        (directionsConfidence * weights['directions']!) +
        (courseConfidence * weights['course']!) +
        (cuisineConfidence * weights['cuisine']!) +
        (servesConfidence * weights['serves']!) +
        (timeConfidence * weights['time']!);
  }

  /// Whether this result needs user review (confidence below threshold)
  bool get needsUserReview => overallConfidence < 0.7;

  /// Whether we have enough data to create a recipe
  bool get hasMinimumData =>
      name != null &&
      name!.isNotEmpty &&
      (ingredients.isNotEmpty || directions.isNotEmpty);

  /// Fields that need attention (low confidence)
  List<String> get fieldsNeedingAttention {
    final fields = <String>[];
    if (nameConfidence < 0.5) fields.add('name');
    if (ingredientsConfidence < 0.5) fields.add('ingredients');
    if (directionsConfidence < 0.5) fields.add('directions');
    if (courseConfidence < 0.5) fields.add('course');
    if (cuisineConfidence < 0.5) fields.add('cuisine');
    if (servesConfidence < 0.5) fields.add('serves');
    if (timeConfidence < 0.5) fields.add('time');
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
    );
    
    // Set multiple images if available
    if (imagePaths != null && imagePaths!.isNotEmpty) {
      recipe.imageUrls = imagePaths!;
    }
    
    return recipe;
  }

  /// Create a copy with updated fields
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
      section: section ?? sectionName,
    );
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
