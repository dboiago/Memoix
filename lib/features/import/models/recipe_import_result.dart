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
  final String? comments;
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
    this.comments,
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

  /// Fields that need attention (confidence below threshold that triggers review)
  /// Shows fields that are contributing to the overall low confidence score
  List<String> get fieldsNeedingAttention {
    final fields = <String>[];
    // Use 0.7 threshold to match when fields are dragging down the score
    // (since overall < 0.7 triggers review)
    if (nameConfidence < 0.7) fields.add('Name');
    if (ingredientsConfidence < 0.7) fields.add('Ingredients');
    if (directionsConfidence < 0.7) fields.add('Directions');
    if (courseConfidence < 0.7) fields.add('Course');
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
      comments: comments,
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
      notes: comments,
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
  /// 
  /// Uses context-aware detection for smoking-specific fields:
  /// - Wood type: prioritizes contextual matches ("hickory chips" > "hickory")
  /// - Temperature: prefers smoking-range temps (200-300°F / 90-150°C)
  /// - Seasonings: filters out proteins and liquids, keeps rubs/spices
  SmokingRecipe toSmokingRecipe(String uuid) {
    final allText = [
      name ?? '',
      notes ?? '',
      ...directions,
      ...ingredients.map((i) => i.name),
    ].join(' ');
    final lowerText = allText.toLowerCase();
    
    // Wood detection with context awareness
    // Prioritize contextual matches like "hickory wood chips" over plain "hickory"
    String? woodType;
    for (final wood in WoodSuggestions.common) {
      final lowerWood = wood.toLowerCase();
      // Check for contextual match first (higher confidence)
      final woodContext = RegExp(
        '($lowerWood)\\s*(wood|chips?|chunks?|pellets?|smoke)|'
        '(smoke|wood|chips?|chunks?|pellets?)\\s*($lowerWood)',
        caseSensitive: false,
      );
      if (woodContext.hasMatch(lowerText)) {
        woodType = wood;
        break;
      }
    }
    // Fallback: plain wood name match if no contextual match
    if (woodType == null) {
      for (final wood in WoodSuggestions.common) {
        if (lowerText.contains(wood.toLowerCase())) {
          woodType = wood;
          break;
        }
      }
    }
    woodType ??= 'Hickory'; // Default
    
    // Temperature detection tuned for smoking ranges
    // Prefer typical smoking temps: 200-300°F or 90-150°C
    String temperature = '';
    final temps = <String>[];
    
    // Find all temperature mentions
    final tempPatterns = [
      RegExp(r'(\d{3})\s*°\s*F', caseSensitive: false),
      RegExp(r'(\d{3})\s*degrees?\s*F', caseSensitive: false),
      RegExp(r'at\s+(\d{3})\s*°?', caseSensitive: false),
      RegExp(r'(\d{2,3})\s*°\s*C', caseSensitive: false),
    ];
    
    for (final pattern in tempPatterns) {
      for (final match in pattern.allMatches(allText)) {
        final temp = match.group(1);
        if (temp != null) {
          final tempNum = int.tryParse(temp);
          if (tempNum != null) {
            String formatted;
            if (pattern.pattern.contains('C')) {
              formatted = '$temp°C';
            } else if (tempNum >= 200 && tempNum <= 400) {
              formatted = '$temp°F';
            } else if (tempNum >= 90 && tempNum <= 200) {
              formatted = '$temp°C';
            } else {
              continue;
            }
            if (!temps.contains(formatted)) {
              temps.add(formatted);
            }
          }
        }
      }
    }
    
    // Select best temperature (prefer smoking range 200-300°F)
    for (final temp in temps) {
      final numMatch = RegExp(r'(\d+)').firstMatch(temp);
      if (numMatch != null) {
        final num = int.tryParse(numMatch.group(1)!);
        if (num != null) {
          if (temp.contains('F') && num >= 200 && num <= 300) {
            temperature = temp;
            break;
          } else if (temp.contains('C') && num >= 100 && num <= 150) {
            temperature = temp;
            break;
          }
        }
      }
    }
    // Fallback to first found if no ideal match
    if (temperature.isEmpty && temps.isNotEmpty) {
      temperature = temps.first;
    }
    
    // Ingredient classification: separate seasonings from proteins/liquids
    // Seasonings are rubs, spices, dry ingredients - NOT the meat being smoked
    const seasoningKeywords = [
      'salt', 'pepper', 'paprika', 'cayenne', 'chili', 'cumin', 'garlic',
      'onion powder', 'sugar', 'brown sugar', 'mustard', 'rub', 'spice',
      'oregano', 'thyme', 'rosemary', 'sage', 'coriander', 'fennel',
      'powder', 'ground', 'dried', 'smoked paprika', 'ancho', 'chipotle',
    ];
    const proteinKeywords = [
      'brisket', 'pork', 'beef', 'ribs', 'chicken', 'turkey', 'salmon',
      'pork butt', 'pork shoulder', 'chuck', 'tri-tip', 'lamb', 'duck',
    ];
    const liquidKeywords = [
      'broth', 'stock', 'water', 'beer', 'wine', 'vinegar', 'oil',
      'butter', 'sauce', 'marinade', 'juice', 'cider',
    ];
    
    final seasonings = <SmokingSeasoning>[];
    for (final ingredient in ingredients) {
      final lower = ingredient.name.toLowerCase();
      final isSeasoning = seasoningKeywords.any((kw) => lower.contains(kw));
      final isProtein = proteinKeywords.any((kw) => lower.contains(kw));
      final isLiquid = liquidKeywords.any((kw) => lower.contains(kw));
      
      // Include as seasoning if it looks like a seasoning AND is not a protein/liquid
      if (isSeasoning && !isProtein && !isLiquid) {
        seasonings.add(SmokingSeasoning.create(
          name: ingredient.name,
          amount: ingredient.amount,
          unit: ingredient.unit,
        ));
      }
    }
    
    // If no seasonings detected, include all ingredients as before
    // (user can clean up in edit screen)
    final finalSeasonings = seasonings.isNotEmpty
        ? seasonings
        : ingredients.map((i) => SmokingSeasoning.create(
            name: i.name,
            amount: i.amount,
            unit: i.unit,
          )).toList();

    final recipe = SmokingRecipe.create(
      uuid: uuid,
      name: name ?? 'Untitled Recipe',
      type: SmokingType.pitNote, // Converted recipes become Pit Notes
      item: name, // Use recipe name as item being smoked
      temperature: temperature,
      time: time ?? '',
      wood: woodType,
      seasonings: finalSeasonings,
      directions: directions,
      notes: comments,
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

  /// Convert to a SmokingRecipe as a full Recipe type (not Pit Note)
  /// Used for imported BBQ site recipes that have full ingredients/directions
  SmokingRecipe toSmokingRecipeAsFullRecipe(String uuid) {
    // Convert Ingredient objects to SmokingSeasoning for the ingredients list
    final recipeIngredients = ingredients.map((i) => SmokingSeasoning.create(
      name: i.name,
      amount: i.amount,
      unit: i.unit,
    )).toList();
    
    // Detect category from name, URL, and ingredients
    String? detectedCategory = _detectSmokingCategory();
    
    // Detect wood type from text
    final allText = [
      name ?? '',
      notes ?? '',
      ...directions,
      ...ingredients.map((i) => i.name),
    ].join(' ');
    final lowerText = allText.toLowerCase();
    
    String? woodType;
    for (final wood in WoodSuggestions.common) {
      final lowerWood = wood.toLowerCase();
      // Check for contextual match first (higher confidence)
      final woodContext = RegExp(
        '($lowerWood)\\s*(wood|chips?|chunks?|pellets?|smoke)|'
        '(smoke|wood|chips?|chunks?|pellets?)\\s*($lowerWood)',
        caseSensitive: false,
      );
      if (woodContext.hasMatch(lowerText)) {
        woodType = wood;
        break;
      }
    }
    // Fallback: plain wood name match if no contextual match
    if (woodType == null) {
      for (final wood in WoodSuggestions.common) {
        if (lowerText.contains(wood.toLowerCase())) {
          woodType = wood;
          break;
        }
      }
    }
    
    final recipe = SmokingRecipe.create(
      uuid: uuid,
      name: name ?? 'Untitled Recipe',
      type: SmokingType.recipe, // Full recipe, not Pit Note
      category: detectedCategory,
      wood: woodType ?? '',
      serves: serves,
      time: time ?? '',
      ingredients: recipeIngredients,
      directions: directions,
      notes: comments,
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

  /// Detect smoking category from name, URL, and ingredients
  /// Returns category like 'Pork', 'Beef', 'Poultry', etc.
  String? _detectSmokingCategory() {
    // Combine all relevant text
    final allText = [
      name ?? '',
      sourceUrl ?? '',
      comments ?? '',
      ...ingredients.map((i) => i.name),
    ].join(' ').toLowerCase();
    
    // Category keywords map - order matters (more specific first)
    const categoryKeywords = <String, List<String>>{
      'Pork': ['pork', 'pulled pork', 'pork shoulder', 'pork butt', 'spare ribs', 'baby back', 'pork belly', 'ham', 'bacon', 'pork chop', 'pork loin'],
      'Beef': ['brisket', 'beef', 'tri-tip', 'chuck roast', 'prime rib', 'beef ribs', 'beef cheeks', 'burnt ends', 'short ribs', 'pastrami'],
      'Poultry': ['chicken', 'turkey', 'duck', 'cornish hen', 'poultry', 'spatchcock', 'wings', 'thigh', 'breast', 'drumstick'],
      'Lamb': ['lamb', 'lamb shoulder', 'leg of lamb', 'lamb ribs', 'lamb chops', 'rack of lamb', 'mutton'],
      'Game': ['venison', 'elk', 'wild boar', 'rabbit', 'pheasant', 'quail', 'goose', 'buffalo', 'game', 'deer'],
      'Seafood': ['salmon', 'trout', 'fish', 'shrimp', 'oyster', 'scallop', 'lobster', 'swordfish', 'tuna', 'mahi', 'seafood', 'crab'],
      'Vegetables': ['vegetable', 'corn', 'pepper', 'onion', 'tomato', 'cabbage', 'mushroom', 'artichoke', 'potato', 'cauliflower', 'squash', 'eggplant'],
      'Cheese': ['cheese', 'gouda', 'cheddar', 'mozzarella', 'provolone', 'brie', 'cream cheese', 'pepper jack'],
      'Desserts': ['dessert', 'bread pudding', 'brownie', 'cheesecake', 'pie', 'cobbler', 'cinnamon roll'],
      'Fruits': ['fruit', 'peach', 'apple', 'pineapple', 'banana', 'pear', 'plum', 'watermelon'],
      'Dips': ['queso', 'mac', 'baked beans', 'salsa', 'guacamole', 'hummus', 'dip'],
    };
    
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (allText.contains(keyword)) {
          return entry.key;
        }
      }
    }
    
    return null;
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
    
    // Separate cheeses, proteins, and vegetables
    final cheeses = <String>[];
    final proteins = <String>[];
    final vegetables = <String>[];
    const cheeseKeywords = ['mozzarella', 'parmesan', 'cheddar', 'gouda', 'provolone', 
        'ricotta', 'gorgonzola', 'feta', 'goat cheese', 'burrata', 'fontina', 'asiago',
        'pecorino', 'gruyere', 'brie', 'cheese'];
    const proteinKeywords = ['pepperoni', 'sausage', 'bacon', 'ham', 'prosciutto', 
        'salami', 'chicken', 'beef', 'pork', 'anchov', 'shrimp', 'meat', 'turkey',
        'chorizo', 'pancetta', 'nduja', 'capicola', 'egg'];
    
    for (final ingredient in ingredients) {
      final lower = ingredient.name.toLowerCase();
      final isCheese = cheeseKeywords.any((c) => lower.contains(c));
      final isProtein = proteinKeywords.any((p) => lower.contains(p));
      
      if (isCheese) {
        cheeses.add(ingredient.name);
      } else if (isProtein) {
        proteins.add(ingredient.name);
      } else {
        // Skip base sauce ingredients, treat rest as vegetables
        if (!lower.contains('sauce') && !lower.contains('dough') && 
            !lower.contains('flour') && !lower.contains('yeast')) {
          vegetables.add(ingredient.name);
        }
      }
    }

    return Pizza.create(
      uuid: uuid,
      name: name ?? 'Untitled Pizza',
      base: base,
      cheeses: cheeses,
      proteins: proteins,
      vegetables: vegetables,
      notes: comments,
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
    String? comments,
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
      comments: comments ?? this.comments,
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
  
  /// Alternative ingredient (e.g., "or store-bought")
  final String? alternative;

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
    this.alternative,
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
      alternative: alternative,
    );
  }
  
  /// Check if this ingredient entry is valid (not empty/garbage)
  bool get isValid {
    // Section headers are valid if they have a section name
    if (sectionName != null && sectionName!.trim().isNotEmpty) {
      return true;
    }
    // Regular ingredients need a meaningful name with at least one letter/number
    // Remove ALL colons (consistent with display which strips them)
    // Also strip leading/trailing dashes and whitespace
    final cleanName = name
        .replaceAll(':', '')
        .replaceAll(RegExp(r'^[\-–—\s]+|[\-–—\s]+$'), '')
        .trim();
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
    final result = ingredients.where((i) {
      if (!i.isValid) {
        return false;
      }
      
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
    
    return result;
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
