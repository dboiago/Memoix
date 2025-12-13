import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/spirit.dart';
import '../models/recipe_import_result.dart';

/// Service to import recipes from URLs
class UrlRecipeImporter {
  static const _uuid = Uuid();

  /// Known cocktail recipe sites
  static const _cocktailSites = [
    'diffordsguide.com',
    'liquor.com',
    'thecocktailproject.com',
    'imbibemagazine.com',
    'cocktailsandshots.com',
    'cocktails.lovetoknow.com',
    'thespruceats.com/cocktails',
    'punchdrink.com',
    'makedrinks.com',
    'drinksmixer.com',
    'cocktail.uk',
    'absolutdrinks.com',
    'drinkflow.com',
    'drinkify.co',
  ];

  /// HTML entity decode map for common entities
  static final _htmlEntities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#34;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
    '&#160;': ' ',
    '&ndash;': '–',
    '&#8211;': '–',
    '&mdash;': '—',
    '&#8212;': '—',
    '&frac12;': '½',
    '&#189;': '½',
    '&frac14;': '¼',
    '&#188;': '¼',
    '&frac34;': '¾',
    '&#190;': '¾',
    '&frac13;': '⅓',
    '&frac23;': '⅔',
    '&deg;': '°',
    '&#176;': '°',
  };

  /// Fraction conversion map (decimal strings to unicode)
  static final _fractionMap = {
    '1/2': '½',
    '1/4': '¼',
    '3/4': '¾',
    '1/3': '⅓',
    '2/3': '⅔',
    '1/8': '⅛',
    '3/8': '⅜',
    '5/8': '⅝',
    '7/8': '⅞',
    '1/5': '⅕',
    '2/5': '⅖',
    '3/5': '⅗',
    '4/5': '⅘',
    '1/6': '⅙',
    '5/6': '⅚',
  };

  /// Measurement abbreviation normalisation
  static final _measurementNormalisation = {
    RegExp(r'\btbsp\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbs\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btablespoon[s]?\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btsp\b', caseSensitive: false): 'tsp',
    RegExp(r'\bteaspoon[s]?\b', caseSensitive: false): 'tsp',
    RegExp(r'\bcup[s]?\b', caseSensitive: false): 'cup',
    RegExp(r'\boz\b', caseSensitive: false): 'oz',
    RegExp(r'\bounce[s]?\b', caseSensitive: false): 'oz',
    RegExp(r'\blb[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bpound[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bkg\b', caseSensitive: false): 'kg',
    RegExp(r'\bkilogram[s]?\b', caseSensitive: false): 'kg',
    RegExp(r'\bg\b', caseSensitive: false): 'g',
    RegExp(r'\bgram[s]?\b', caseSensitive: false): 'g',
    RegExp(r'\bml\b', caseSensitive: false): 'ml',
    RegExp(r'\bmillilitre[s]?\b', caseSensitive: false): 'ml',
    RegExp(r'\bl\b', caseSensitive: false): 'L',
    RegExp(r'\blitre[s]?\b', caseSensitive: false): 'L',
  };

  /// Import a recipe from a URL
  /// Supports JSON-LD schema.org Recipe format and common recipe sites
  /// Returns RecipeImportResult with confidence scores for user review
  Future<RecipeImportResult> importFromUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Memoix Recipe App/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch URL: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      
      for (final script in jsonLdScripts) {
        try {
          final data = jsonDecode(script.text);
          final result = _parseJsonLdWithConfidence(data, url);
          if (result != null) return result;
        } catch (_) {
          continue;
        }
      }

      // Fallback: try to parse from HTML structure
      final result = _parseFromHtmlWithConfidence(document, url);
      if (result != null) return result;
      
      throw Exception('Could not find recipe data on this page');
    } catch (e) {
      throw Exception('Failed to import recipe from URL: $e');
    }
  }

  /// Legacy method for backwards compatibility - returns Recipe directly
  Future<Recipe?> importRecipeFromUrl(String url) async {
    final result = await importFromUrl(url);
    return result.toRecipe(_uuid.v4());
  }

  /// Decode HTML entities and normalise text
  String _decodeHtml(String text) {
    var result = text;
    
    // Decode HTML entities
    _htmlEntities.forEach((entity, char) {
      result = result.replaceAll(entity, char);
    });
    
    // Handle numeric entities
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );
    
    // Handle hex entities
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );
    
    // Convert fractions
    _fractionMap.forEach((fraction, unicode) {
      result = result.replaceAll(fraction, unicode);
    });
    
    // Normalise measurements
    _measurementNormalisation.forEach((pattern, replacement) {
      result = result.replaceAllMapped(pattern, (_) => replacement);
    });
    
    // Clean up extra whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return result;
  }

  /// Clean recipe name - remove "Recipe" suffix and clean up
  String _cleanRecipeName(String name) {
    var cleaned = _decodeHtml(name);
    
    // Remove common suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-–—]\s*Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^Recipe\s*[-–—:]\s*', caseSensitive: false), '');
    
    return cleaned.trim();
  }

  /// Parse JSON-LD structured data
  Recipe? _parseJsonLd(dynamic data, String sourceUrl) {
    // Handle @graph structure
    if (data is Map && data['@graph'] != null) {
      final graph = data['@graph'] as List;
      for (final item in graph) {
        final recipe = _parseJsonLd(item, sourceUrl);
        if (recipe != null) return recipe;
      }
      return null;
    }

    // Handle array of items
    if (data is List) {
      for (final item in data) {
        final recipe = _parseJsonLd(item, sourceUrl);
        if (recipe != null) return recipe;
      }
      return null;
    }

    // Check if this is a Recipe type
    if (data is! Map) return null;
    
    final type = data['@type'];
    final isRecipe = type == 'Recipe' || 
                     (type is List && type.contains('Recipe'));
    
    if (!isRecipe) return null;

    // Parse ingredients and sort by quantity
    var ingredients = _parseIngredients(data['recipeIngredient']);
    ingredients = _sortIngredientsByQuantity(ingredients);

    // Parse nutrition information if available
    final nutrition = _parseNutrition(data['nutrition']);

    // Determine course with drink detection
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    
    // For drinks, detect the base spirit and set as subcategory
    String? subcategory;
    if (course == 'drinks') {
      subcategory = _detectSpirit(ingredients);
      // Convert code to display name
      if (subcategory != null) {
        subcategory = Spirit.toDisplayName(subcategory);
      }
    }

    // Parse the recipe data
    return Recipe.create(
      uuid: _uuid.v4(),
      name: _cleanRecipeName(_parseString(data['name']) ?? 'Untitled Recipe'),
      course: course,
      cuisine: _parseCuisine(data['recipeCuisine']),
      subcategory: subcategory,
      serves: _parseYield(data['recipeYield']),
      time: _parseTime(data),
      ingredients: ingredients,
      directions: _parseInstructions(data['recipeInstructions']),
      notes: _decodeHtml(_parseString(data['description']) ?? ''),
      imageUrl: _parseImage(data['image']),
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
      nutrition: nutrition,
    );
  }

  /// Parse JSON-LD with confidence scoring for review flow
  RecipeImportResult? _parseJsonLdWithConfidence(dynamic data, String sourceUrl) {
    // Handle @graph structure
    if (data is Map && data['@graph'] != null) {
      final graph = data['@graph'] as List;
      for (final item in graph) {
        final result = _parseJsonLdWithConfidence(item, sourceUrl);
        if (result != null) return result;
      }
      return null;
    }

    // Handle array of items
    if (data is List) {
      for (final item in data) {
        final result = _parseJsonLdWithConfidence(item, sourceUrl);
        if (result != null) return result;
      }
      return null;
    }

    // Check if this is a Recipe type
    if (data is! Map) return null;
    
    final type = data['@type'];
    final isRecipe = type == 'Recipe' || 
                     (type is List && type.contains('Recipe'));
    
    if (!isRecipe) return null;

    // Parse with confidence scoring
    final name = _cleanRecipeName(_parseString(data['name']) ?? '');
    final nameConfidence = name.isNotEmpty ? 0.9 : 0.0;

    // Parse ingredients and collect raw data
    final rawIngredientStrings = _extractRawIngredients(data['recipeIngredient']);
    var ingredients = _parseIngredients(data['recipeIngredient']);
    ingredients = _sortIngredientsByQuantity(ingredients);
    
    // Calculate ingredients confidence based on how many we successfully parsed
    double ingredientsConfidence = 0.0;
    if (rawIngredientStrings.isNotEmpty) {
      ingredientsConfidence = ingredients.length / rawIngredientStrings.length;
      // Boost if ingredients have amounts
      final withAmounts = ingredients.where((i) => i.amount != null && i.amount!.isNotEmpty).length;
      if (ingredients.isNotEmpty) {
        ingredientsConfidence = (ingredientsConfidence + (withAmounts / ingredients.length)) / 2;
      }
    }

    // Parse directions with confidence
    final directions = _parseInstructions(data['recipeInstructions']);
    final rawDirections = _extractRawDirections(data['recipeInstructions']);
    double directionsConfidence = directions.isNotEmpty ? 0.8 : 0.0;
    // Boost if directions are detailed (more than a few words each)
    if (directions.isNotEmpty) {
      final avgWords = directions.map((d) => d.split(' ').length).reduce((a, b) => a + b) / directions.length;
      if (avgWords > 10) directionsConfidence = 0.9;
    }

    // Parse nutrition
    final nutrition = _parseNutrition(data['nutrition']);

    // Detect course with confidence
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    final courseConfidence = _getCourseConfidence(data, sourceUrl);
    
    // Parse cuisine
    final cuisine = _parseCuisine(data['recipeCuisine']);
    final cuisineConfidence = cuisine != null ? 0.8 : 0.3;
    
    // Detect all possible courses and cuisines
    final detectedCourses = _detectAllCourses(data);
    final detectedCuisines = _detectAllCuisines(data);

    // Parse other fields
    final serves = _parseYield(data['recipeYield']);
    final servesConfidence = serves != null ? 0.9 : 0.0;
    
    final time = _parseTime(data);
    final timeConfidence = time != null ? 0.9 : 0.0;

    // For drinks, detect the base spirit
    String? subcategory;
    if (course == 'drinks') {
      subcategory = _detectSpirit(ingredients);
      if (subcategory != null) {
        subcategory = Spirit.toDisplayName(subcategory);
      }
    }

    // Create raw ingredient data
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        name: parsed.name.isNotEmpty ? parsed.name : raw,
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    }).toList();

    return RecipeImportResult(
      name: name.isNotEmpty ? name : null,
      course: course,
      cuisine: cuisine,
      subcategory: subcategory,
      serves: serves,
      time: time,
      ingredients: ingredients,
      directions: directions,
      notes: _decodeHtml(_parseString(data['description']) ?? ''),
      imageUrl: _parseImage(data['image']),
      nutrition: nutrition,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: detectedCourses,
      detectedCuisines: detectedCuisines,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      cuisineConfidence: cuisineConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      servesConfidence: servesConfidence,
      timeConfidence: timeConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }

  /// Extract raw ingredient strings without parsing
  List<String> _extractRawIngredients(dynamic value) {
    if (value == null) return [];
    if (value is String) return [_decodeHtml(value)];
    if (value is List) {
      return value
          .map((e) => _decodeHtml(e.toString().trim()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Extract raw direction strings
  List<String> _extractRawDirections(dynamic value) {
    if (value == null) return [];
    if (value is String) return [_decodeHtml(value)];
    if (value is List) {
      return value.map((item) {
        if (item is String) return _decodeHtml(item.trim());
        if (item is Map) {
          return _decodeHtml(_parseString(item['text']) ?? _parseString(item['name']) ?? item.toString());
        }
        return _decodeHtml(item.toString().trim());
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Get confidence score for course detection
  double _getCourseConfidence(Map data, String? sourceUrl) {
    final category = _parseString(data['recipeCategory'])?.toLowerCase();
    
    // High confidence if category is explicitly set
    if (category != null && category.isNotEmpty) {
      if (_isCocktailSite(sourceUrl ?? '')) return 0.95;
      if (category.contains('dessert') || category.contains('soup') || 
          category.contains('salad') || category.contains('main')) {
        return 0.85;
      }
      return 0.7;
    }
    
    // Medium confidence if we can infer from keywords
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    if (keywords.contains('dessert') || keywords.contains('main') || 
        keywords.contains('appetizer')) {
      return 0.6;
    }
    
    // Low confidence - just guessing
    return 0.4;
  }

  /// Detect all possible course categories from recipe data
  List<String> _detectAllCourses(Map data) {
    final courses = <String>{};
    final category = _parseString(data['recipeCategory'])?.toLowerCase() ?? '';
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final allText = '$category $keywords';
    
    if (allText.contains('dessert') || allText.contains('sweet')) courses.add('Desserts');
    if (allText.contains('appetizer') || allText.contains('starter')) courses.add('Apps');
    if (allText.contains('soup')) courses.add('Soups');
    if (allText.contains('salad') || allText.contains('side')) courses.add('Sides');
    if (allText.contains('bread')) courses.add('Breads');
    if (allText.contains('breakfast') || allText.contains('brunch')) courses.add('Brunch');
    if (allText.contains('main') || allText.contains('dinner') || allText.contains('entrée')) courses.add('Mains');
    if (allText.contains('sauce') || allText.contains('dressing')) courses.add('Sauces');
    if (allText.contains('drink') || allText.contains('cocktail') || allText.contains('beverage')) courses.add('drinks');
    if (allText.contains('vegetarian') || allText.contains('vegan')) courses.add("Veg'n");
    
    // Always include Mains as default option
    if (courses.isEmpty) courses.add('Mains');
    
    return courses.toList()..sort();
  }

  /// Detect all possible cuisines from recipe data
  List<String> _detectAllCuisines(Map data) {
    final cuisines = <String>{};
    final cuisine = _parseString(data['recipeCuisine'])?.toLowerCase() ?? '';
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final allText = '$cuisine $keywords $name';
    
    // Check for cuisine indicators
    final cuisineIndicators = {
      'american': 'USA', 'southern': 'USA', 'cajun': 'USA',
      'french': 'France', 'italian': 'Italy', 'spanish': 'Spain',
      'mexican': 'Mexico', 'chinese': 'China', 'japanese': 'Japan',
      'korean': 'Korea', 'thai': 'Thailand', 'vietnamese': 'Vietnam',
      'indian': 'India', 'greek': 'Greece', 'mediterranean': 'Mediterranean',
      'middle eastern': 'Middle East', 'moroccan': 'Morocco',
      'caribbean': 'Caribbean', 'brazilian': 'Brazil',
    };
    
    cuisineIndicators.forEach((indicator, cuisineName) {
      if (allText.contains(indicator)) {
        cuisines.add(cuisineName);
      }
    });
    
    return cuisines.toList()..sort();
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return _decodeHtml(value.trim());
    if (value is List && value.isNotEmpty) return _decodeHtml(value.first.toString().trim());
    return _decodeHtml(value.toString().trim());
  }

  String? _parseYield(dynamic value) {
    if (value == null) return null;
    if (value is String) return _decodeHtml(value);
    if (value is num) return value.toString();
    if (value is List && value.isNotEmpty) return _decodeHtml(value.first.toString());
    return null;
  }

  /// Parse cuisine - convert region names to country names
  String? _parseCuisine(dynamic value) {
    if (value == null) return null;
    
    var cuisine = _parseString(value);
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Map regions to countries
    final regionToCountry = {
      'american': 'USA',
      'southern': 'USA',
      'cajun': 'USA',
      'tex-mex': 'Mexican',
      'french': 'France',
      'italian': 'Italy',
      'spanish': 'Spain',
      'german': 'Germany',
      'british': 'UK',
      'english': 'UK',
      'scottish': 'UK',
      'irish': 'Ireland',
      'greek': 'Greece',
      'turkish': 'Turkey',
      'lebanese': 'Lebanon',
      'moroccan': 'Morocco',
      'ethiopian': 'Ethiopia',
      'indian': 'India',
      'thai': 'Thailand',
      'vietnamese': 'Vietnam',
      'chinese': 'China',
      'japanese': 'Japan',
      'korean': 'Korea',
      'filipino': 'Philippines',
      'indonesian': 'Indonesia',
      'malaysian': 'Malaysia',
      'mexican': 'Mexico',
      'brazilian': 'Brazil',
      'peruvian': 'Peru',
      'argentine': 'Argentina',
      'colombian': 'Colombia',
      'caribbean': 'Caribbean',
      'cuban': 'Cuba',
      'jamaican': 'Jamaica',
      'australian': 'Australia',
      'middle eastern': 'Middle East',
      'mediterranean': 'Mediterranean',
      'asian': 'Asian',
      'african': 'African',
      'european': 'European',
      'latin american': 'Latin America',
      'south american': 'Latin America',
      'north american': 'USA',
      'scandinavian': 'Nordic',
      'nordic': 'Nordic',
      'portuguese': 'Portugal',
      'polish': 'Poland',
      'russian': 'Russia',
      'ukrainian': 'Ukraine',
      'hungarian': 'Hungary',
      'austrian': 'Austria',
      'swiss': 'Switzerland',
      'dutch': 'Netherlands',
      'belgian': 'Belgium',
      'canadian': 'Canada',
    };
    
    final lowered = cuisine.toLowerCase().trim();
    return regionToCountry[lowered] ?? _capitalise(cuisine);
  }

  String _capitalise(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Parse nutrition information from schema.org NutritionInformation
  NutritionInfo? _parseNutrition(dynamic data) {
    if (data == null) return null;
    if (data is! Map) return null;
    
    // Parse nutrition values - they may be strings like "150 calories" or numbers
    final nutrition = NutritionInfo.create(
      servingSize: _parseString(data['servingSize']),
      calories: _parseNutritionValue(data['calories'])?.round(),
      fatContent: _parseNutritionValue(data['fatContent']),
      saturatedFatContent: _parseNutritionValue(data['saturatedFatContent']),
      transFatContent: _parseNutritionValue(data['transFatContent']),
      cholesterolContent: _parseNutritionValue(data['cholesterolContent']),
      sodiumContent: _parseNutritionValue(data['sodiumContent']),
      carbohydrateContent: _parseNutritionValue(data['carbohydrateContent']),
      fiberContent: _parseNutritionValue(data['fiberContent']),
      sugarContent: _parseNutritionValue(data['sugarContent']),
      proteinContent: _parseNutritionValue(data['proteinContent']),
    );
    
    return nutrition.hasData ? nutrition : null;
  }

  /// Parse a nutrition value that might be a number or string like "20 g"
  double? _parseNutritionValue(dynamic value) {
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

  String? _parseTime(Map data) {
    // Prefer totalTime if available
    if (data['totalTime'] != null) {
      final total = _parseDuration(data['totalTime']);
      if (total != null) return total;
    }
    
    // Otherwise calculate from prep + cook
    int totalMinutes = 0;
    
    if (data['prepTime'] != null) {
      totalMinutes += _parseDurationMinutes(data['prepTime']);
    }
    
    if (data['cookTime'] != null) {
      totalMinutes += _parseDurationMinutes(data['cookTime']);
    }
    
    if (totalMinutes > 0) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (hours > 0 && mins > 0) {
        return '$hours hr $mins min';
      } else if (hours > 0) {
        return '$hours hr';
      } else {
        return '$mins min';
      }
    }
    
    return null;
  }

  int _parseDurationMinutes(dynamic value) {
    if (value == null) return 0;
    final str = value.toString();
    
    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);
    
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      return hours * 60 + minutes;
    }
    
    return 0;
  }

  String? _parseDuration(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    
    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);
    
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      
      if (hours > 0 && minutes > 0) {
        return '$hours hr $minutes min';
      } else if (hours > 0) {
        return '$hours hr';
      } else if (minutes > 0) {
        return '$minutes min';
      }
    }
    
    return str;
  }

  List<Ingredient> _parseIngredients(dynamic value) {
    if (value == null) return [];
    
    List<String> items;
    if (value is String) {
      items = [value];
    } else if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else {
      return [];
    }

    // Detect sections - some sites prefix ingredients with section headers
    // Common patterns: "For the sauce:", "Sauce:", "Main Ingredients:", etc.
    String? currentSection;
    final result = <Ingredient>[];
    
    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;
      
      // Check if this is a section header (no amount, ends with colon, or "For the X" pattern)
      // Also check for short standalone items that look like headers
      final sectionPatterns = [
        RegExp(r'^For\s+(?:the\s+)?(.+?)[:.]?\s*$', caseSensitive: false),  // "For the sauce:"
        RegExp(r'^(.+?)\s+[Ii]ngredients?[:.]?\s*$'),  // "Main ingredients:"
        RegExp(r'^(.+?)\s+[Ss]auce[:.]?\s*$'),  // "Spicy ketchup sauce:"
        RegExp(r'^(.+?)\s+[Mm]arinade[:.]?\s*$'),  // "Tofu marinade:"
        RegExp(r'^(.+?)\s+[Gg]laze[:.]?\s*$'),  // "Honey glaze:"
        RegExp(r'^(.+?)\s+[Ss]easoning[:.]?\s*$'),  // "Spice seasoning:"
        RegExp(r'^(.+?)\s+[Rr]ub[:.]?\s*$'),  // "Spice rub:"
        RegExp(r'^(.+?)\s+[Tt]opping[s]?[:.]?\s*$'),  // "Toppings:"
        RegExp(r'^(.+?)\s+[Gg]arnish[:.]?\s*$'),  // "Garnish:"
        RegExp(r'^(.+?)\s+[Ff]illing[:.]?\s*$'),  // "Filling:"
        RegExp(r'^(.+?)[:–—]\s*$'),  // General "Something:" (must end with colon/dash)
      ];
      
      bool isSection = false;
      for (final pattern in sectionPatterns) {
        final match = pattern.firstMatch(decoded);
        if (match != null) {
          // Verify it's not an ingredient (no numbers at start)
          if (!RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]').hasMatch(decoded)) {
            currentSection = match.group(1)?.trim();
            isSection = true;
            break;
          }
        }
      }
      
      if (!isSection) {
        final ingredient = _parseIngredientString(decoded);
        if (ingredient.name.isNotEmpty) {
          // Update currentSection if ingredient has inline section
          if (ingredient.section != null) {
            currentSection = ingredient.section;
          }
          
          // Apply current section to this ingredient (inline or header-based)
          final effectiveSection = ingredient.section ?? currentSection;
          if (effectiveSection != null && effectiveSection != ingredient.section) {
            result.add(Ingredient.create(
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              preparation: ingredient.preparation,
              alternative: ingredient.alternative,
              isOptional: ingredient.isOptional,
              section: effectiveSection,
            ));
          } else {
            result.add(ingredient);
          }
        }
      }
    }
    
    return result;
  }

  /// Parse a single ingredient string into structured data
  Ingredient _parseIngredientString(String text) {
    var remaining = text;
    bool isOptional = false;
    List<String> notesParts = [];
    String? amount;
    String? inlineSection;
    
    // Check for inline section markers like "[Sauce]" or "(For the sauce)" at the start
    final inlineSectionMatch = RegExp(
      r'^\[([^\]]+)\]\s*|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s*',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (inlineSectionMatch != null) {
      inlineSection = (inlineSectionMatch.group(1) ?? inlineSectionMatch.group(2))?.trim();
      remaining = remaining.substring(inlineSectionMatch.end).trim();
    }
    
    // Remove footnote markers like [1], *, †, etc.
    remaining = remaining.replaceAll(RegExp(r'\[\d+\]|\*+|†+'), '').trim();
    
    // Check for optional markers anywhere and extract to notes
    final optionalPatterns = [
      RegExp(r'\(\s*optional\s*\)', caseSensitive: false),
      RegExp(r',\s*optional\s*$', caseSensitive: false),
      RegExp(r'\s+optional\s*$', caseSensitive: false),
    ];
    
    for (final pattern in optionalPatterns) {
      if (pattern.hasMatch(remaining)) {
        isOptional = true;
        remaining = remaining.replaceAll(pattern, '').trim();
        notesParts.add('optional');
        break;
      }
    }
    
    // Extract ALL parenthetical content as notes (preparation info, alternatives, etc.)
    // Handle double parentheses like ((0.6 pounds)) and leading commas like (, regular)
    // First normalize double parentheses to single
    remaining = remaining.replaceAll('((', '(').replaceAll('))', ')');
    
    final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(remaining).toList();
    for (final match in parenMatches.reversed) {
      var content = match.group(1)?.trim() ?? '';
      
      // Remove leading commas/spaces from inside parentheses (site-specific quirk)
      content = content.replaceAll(RegExp(r'^[,\s]+'), '').trim();
      
      if (content.isNotEmpty && content.toLowerCase() != 'optional') {
        // Check if it's a weight conversion (e.g., "0.6 pounds", "1 lb", "500g")
        final isWeightConversion = RegExp(
          r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$',
          caseSensitive: false
        ).hasMatch(content);
        
        if (isWeightConversion) {
          // Add weight conversion to notes
          notesParts.insert(0, content);
        } else {
          // Add other parenthetical content to notes
          notesParts.insert(0, content);
        }
      }
      remaining = remaining.substring(0, match.start) + remaining.substring(match.end);
    }
    remaining = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Try to extract amount (number at start, possibly with range and unit)
    // Handle compound fractions like "1 1/2" or "1 ½" (whole number + fraction)
    // Handle ranges like "1-1.5 Tbsp" or "1 -1.5 Tbsp" (space before dash)
    final compoundFractionMatch = RegExp(
      r'^(\d+)\s+([½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]|1/2|1/4|3/4|1/3|2/3|1/8|3/8|5/8|7/8)'
      r'(\s*(?:cup|cups|Tbsp|tsp|oz|lb|kg|g|ml|L|pound|pounds|ounce|ounces|inch|inches|in|cm)s?)?\s+',
      caseSensitive: false,
    ).firstMatch(remaining);
    
    if (compoundFractionMatch != null) {
      // Handle compound fraction like "1 1/2 tsp" or "1 ½ tsp"
      final whole = compoundFractionMatch.group(1) ?? '';
      var fraction = compoundFractionMatch.group(2) ?? '';
      final unit = compoundFractionMatch.group(3)?.trim() ?? '';
      // Convert text fractions to unicode
      fraction = _fractionMap[fraction] ?? fraction;
      amount = '$whole$fraction';
      if (unit.isNotEmpty) {
        amount = '$amount $unit';
      }
      remaining = remaining.substring(compoundFractionMatch.end).trim();
    } else {
      // Original pattern for simple amounts and ranges
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+|[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:cup|cups|Tbsp|tsp|oz|lb|kg|g|ml|L|pound|pounds|ounce|ounces|inch|inches|in|cm)s?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (amountMatch != null) {
        final number = amountMatch.group(1)?.trim() ?? '';
        final unit = amountMatch.group(2)?.trim() ?? '';
        // Normalize the range format (remove extra spaces around dash)
        amount = number.replaceAll(RegExp(r'\s*[-–]\s*'), '-');
        if (unit.isNotEmpty) {
          amount = '$amount $unit';
        }
        remaining = remaining.substring(amountMatch.end).trim();
      }
    }
    
    // Extract preparation instructions after comma (e.g., "oil, I used rice bran oil")
    final commaIndex = remaining.indexOf(',');
    if (commaIndex > 0) {
      var afterComma = remaining.substring(commaIndex + 1).trim();
      remaining = remaining.substring(0, commaIndex).trim();
      
      // Clean up common patterns like "I used X" -> just note the alternative
      afterComma = afterComma.replaceAllMapped(
        RegExp(r'^I\s+used\s+', caseSensitive: false),
        (m) => '',
      );
      
      // Remove any leading commas or spaces
      afterComma = afterComma.replaceAll(RegExp(r'^[,\s]+'), '').trim();
      
      if (afterComma.isNotEmpty) {
        notesParts.add(afterComma);
      }
    }
    
    // Skip empty ingredients (like just "cooking oil" with nothing useful after extraction)
    // But allow simple ingredients like "oil", "salt", etc.
    if (remaining.isEmpty && notesParts.isEmpty && amount == null) {
      return Ingredient.create(name: '', amount: null);
    }
    
    // If the remaining ingredient name is empty but we have notes, try to salvage it
    if (remaining.isEmpty && notesParts.isNotEmpty) {
      // Use the first meaningful note as the name
      for (var i = 0; i < notesParts.length; i++) {
        final note = notesParts[i].toLowerCase();
        if (!note.contains('optional') && 
            !RegExp(r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$', caseSensitive: false).hasMatch(notesParts[i])) {
          remaining = notesParts.removeAt(i);
          break;
        }
      }
    }
    
    // Clean the ingredient name - remove trailing/leading punctuation
    remaining = remaining.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    
    // Build final notes string, cleaning up any remaining stray parentheses, commas, and footnotes
    String? finalNotes;
    if (notesParts.isNotEmpty) {
      finalNotes = notesParts
          .map((n) => n
              .replaceAll(RegExp(r'^\(+|\)+$'), '')  // Remove stray parentheses
              .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')  // Remove leading/trailing commas and spaces
              .trim())
          .where((n) => n.isNotEmpty)
          // Filter out footnote references like "Footnote 1", "Footnote 2", etc.
          .where((n) => !RegExp(r'^Footnote\s*\d*$', caseSensitive: false).hasMatch(n))
          .join(', ');
      if (finalNotes.isEmpty) finalNotes = null;
    }
    
    return Ingredient.create(
      name: remaining,
      amount: _normalizeFractions(amount),
      preparation: finalNotes,
      isOptional: isOptional,
      section: inlineSection,
    );
  }

  /// Normalize fractions to unicode characters (1/2 → ½, 0.5 → ½)
  String? _normalizeFractions(String? text) {
    if (text == null || text.isEmpty) return text;
    
    var result = text;
    
    // Decimal to fraction mapping
    const decimalToFraction = {
      '0.5': '½', '0.25': '¼', '0.75': '¾',
      '0.33': '⅓', '0.333': '⅓', '0.67': '⅔', '0.666': '⅔', '0.667': '⅔',
      '0.125': '⅛', '0.375': '⅜', '0.625': '⅝', '0.875': '⅞',
      '0.2': '⅕', '0.4': '⅖', '0.6': '⅗', '0.8': '⅘',
    };
    
    // Text fraction to unicode mapping
    const textToFraction = {
      '1/2': '½', '1/4': '¼', '3/4': '¾',
      '1/3': '⅓', '2/3': '⅔',
      '1/8': '⅛', '3/8': '⅜', '5/8': '⅝', '7/8': '⅞',
      '1/5': '⅕', '2/5': '⅖', '3/5': '⅗', '4/5': '⅘',
      '1/6': '⅙', '5/6': '⅚',
    };
    
    // Replace text fractions first (before decimals to avoid conflicts)
    for (final entry in textToFraction.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    // Replace decimals
    for (final entry in decimalToFraction.entries) {
      // Only replace if it's a standalone decimal or at word boundary
      result = result.replaceAll(RegExp('(?<![\\d])${RegExp.escape(entry.key)}(?![\\d])'), entry.value);
    }
    
    return result;
  }

  /// Sort ingredients by quantity (largest first), keeping sections together
  List<Ingredient> _sortIngredientsByQuantity(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return ingredients;
    
    // Group by section
    final Map<String?, List<Ingredient>> sections = {};
    for (final ing in ingredients) {
      sections.putIfAbsent(ing.section, () => []).add(ing);
    }
    
    // Sort each section by unit priority then quantity
    final result = <Ingredient>[];
    for (final section in sections.keys) {
      final sectionItems = sections[section]!;
      sectionItems.sort((a, b) {
        final aScore = _getIngredientSortScore(a.amount);
        final bScore = _getIngredientSortScore(b.amount);
        return bScore.compareTo(aScore); // Descending (largest first)
      });
      result.addAll(sectionItems);
    }
    
    return result;
  }

  /// Get a sort score for an ingredient amount (higher = larger/more important)
  /// Priority order: weight (kg, g, lb, oz) > whole items > volume (cups, ml) > Tbsp > tsp
  double _getIngredientSortScore(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    final text = amount.toLowerCase();
    
    // Unit priority multipliers - weight first, then volume, then small measures
    double unitMultiplier = 1.0;
    
    // Weight units - highest priority
    if (text.contains('kg') || text.contains('kilogram')) {
      unitMultiplier = 10000.0; // kg - largest weight
    } else if (text.contains('lb') || text.contains('pound')) {
      unitMultiplier = 8000.0;
    } else if (RegExp(r'\bg\b').hasMatch(text) || text.contains('gram')) {
      unitMultiplier = 5000.0; // grams
    } else if (text.contains('oz') || text.contains('ounce')) {
      unitMultiplier = 4000.0;
    }
    // Whole items (pure numbers like "1 onion") - high priority
    else if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      unitMultiplier = 3000.0;
    }
    // Volume units - medium priority
    else if (text.contains('l') && (text.contains(' l') || text.endsWith('l') || text.contains('liter') || text.contains('litre'))) {
      unitMultiplier = 2000.0; // liters
    } else if (text.contains('ml') || text.contains('milliliter')) {
      unitMultiplier = 1500.0;
    } else if (text.contains('cup') || RegExp(r'\bc\b').hasMatch(text)) {
      unitMultiplier = 1000.0; // cups
    }
    // Small measurements - lower priority
    else if (text.contains('tbsp') || text.contains('tablespoon')) {
      unitMultiplier = 100.0;
    } else if (text.contains('tsp') || text.contains('teaspoon')) {
      unitMultiplier = 10.0;
    } else if (text.contains('in') || text.contains('inch') || text.contains('"')) {
      unitMultiplier = 5.0; // length measurements
    }
    
    // Extract numeric quantity
    final quantity = _extractNumericQuantity(amount);
    
    return quantity * unitMultiplier;
  }

  /// Extract numeric value from amount string for sorting
  double _extractNumericQuantity(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    // Unicode fractions to decimal
    final fractionValues = {
      '½': 0.5, '¼': 0.25, '¾': 0.75,
      '⅓': 0.33, '⅔': 0.67,
      '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 0.167, '⅚': 0.833,
    };
    
    var text = amount;
    double total = 0;
    
    // Replace unicode fractions with values
    for (final entry in fractionValues.entries) {
      if (text.contains(entry.key)) {
        total += entry.value;
        text = text.replaceAll(entry.key, '');
      }
    }
    
    // Try to find integer or range
    final numMatch = RegExp(r'(\d+)(?:\s*[-–]\s*(\d+))?').firstMatch(text);
    if (numMatch != null) {
      final first = double.tryParse(numMatch.group(1) ?? '') ?? 0;
      final second = double.tryParse(numMatch.group(2) ?? '');
      // Use the higher number in a range
      total += second ?? first;
    }
    
    return total;
  }

  List<String> _parseInstructions(dynamic value) {
    if (value == null) return [];
    
    if (value is String) {
      return _decodeHtml(value)
          .split(RegExp(r'\n+|\. (?=[A-Z])'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    
    if (value is List) {
      return value.map((item) {
        if (item is String) return _decodeHtml(item.trim());
        if (item is Map) {
          return _decodeHtml(_parseString(item['text']) ?? _parseString(item['name']) ?? '');
        }
        return _decodeHtml(item.toString().trim());
      }).where((s) => s.isNotEmpty).toList();
    }
    
    return [];
  }

  String? _parseImage(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return _parseImage(value.first);
    }
    if (value is Map) {
      return _parseString(value['url']) ?? _parseString(value['contentUrl']);
    }
    return null;
  }

  /// Check if a URL is from a known cocktail/drinks site
  bool _isCocktailSite(String url) {
    final lower = url.toLowerCase();
    return _cocktailSites.any((site) => lower.contains(site));
  }

  /// Detect the course, with special handling for drinks/cocktails
  String _guessCourse(Map data, {String? sourceUrl}) {
    final category = _parseString(data['recipeCategory'])?.toLowerCase();
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final description = _parseString(data['description'])?.toLowerCase() ?? '';
    
    // Check if this is from a cocktail site
    if (sourceUrl != null && _isCocktailSite(sourceUrl)) {
      return 'drinks';
    }
    
    // Check for drink/cocktail indicators in the data
    if (_isDrinkRecipe(category, keywords, name, description)) {
      return 'drinks';
    }
    
    if (category != null) {
      if (category.contains('dessert') || category.contains('sweet')) return 'Desserts';
      if (category.contains('appetizer') || category.contains('starter')) return 'Apps';
      if (category.contains('soup')) return 'Soups';
      if (category.contains('salad') || category.contains('side')) return 'Sides';
      if (category.contains('bread')) return 'Breads';
      if (category.contains('breakfast') || category.contains('brunch')) return 'Brunch';
      if (category.contains('main') || category.contains('dinner') || category.contains('entrée')) return 'Mains';
      if (category.contains('sauce') || category.contains('dressing')) return 'Sauces';
      if (category.contains('pizza')) return 'Pizzas';
    }
    
    if (keywords.contains('vegetarian') || keywords.contains('vegan')) return "Veg'n";
    
    return 'Mains'; // Default
  }

  /// Check if this is a drink/cocktail recipe based on content
  bool _isDrinkRecipe(String? category, String keywords, String name, String description) {
    final allText = '${category ?? ''} $keywords $name $description'.toLowerCase();
    
    // Cocktail/drink category indicators
    const drinkIndicators = [
      'cocktail', 'cocktails', 'drink', 'drinks', 'beverage', 'beverages',
      'martini', 'margarita', 'mojito', 'negroni', 'manhattan', 'daiquiri',
      'old fashioned', 'old-fashioned', 'highball', 'lowball', 'sour',
      'fizz', 'collins', 'spritz', 'punch', 'shooter', 'shot',
      'mocktail', 'smoothie', 'shake', 'milkshake',
    ];
    
    // Spirit indicators
    const spiritIndicators = [
      'gin', 'vodka', 'rum', 'whiskey', 'whisky', 'bourbon', 'scotch',
      'tequila', 'mezcal', 'brandy', 'cognac', 'liqueur',
      'champagne', 'prosecco', 'wine', 'vermouth', 'amaro', 'aperol',
      'campari', 'bitters',
    ];
    
    for (final indicator in drinkIndicators) {
      if (allText.contains(indicator)) return true;
    }
    
    // If category specifically mentions spirits, it's likely a drink
    if (category != null) {
      for (final spirit in spiritIndicators) {
        if (category.contains(spirit)) return true;
      }
    }
    
    return false;
  }

  /// Detect the base spirit for a cocktail from ingredients
  String? _detectSpirit(List<Ingredient> ingredients) {
    final ingredientNames = ingredients.map((i) => i.name).toList();
    return Spirit.detectFromIngredients(ingredientNames);
  }

  /// Fallback HTML parsing for sites without JSON-LD
  Recipe? _parseFromHtml(dynamic document, String sourceUrl) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim() ??
                  'Untitled Recipe';

    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient'
    );
    
    var ingredients = ingredientElements
        .map((e) => _parseIngredientString(_decodeHtml(e.text.trim())))
        .where((i) => i.name.isNotEmpty)
        .toList();
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction'
    );
    
    final directions = instructionElements
        .map((e) => _decodeHtml(e.text.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    if (ingredients.isEmpty && directions.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktail = _isCocktailSite(sourceUrl);
    final course = isCocktail ? 'drinks' : 'Mains';
    
    // For drinks, detect the base spirit
    String? subcategory;
    if (isCocktail) {
      final spiritCode = _detectSpirit(ingredients);
      if (spiritCode != null) {
        subcategory = Spirit.toDisplayName(spiritCode);
      }
    }

    return Recipe.create(
      uuid: _uuid.v4(),
      name: _cleanRecipeName(title),
      course: course,
      subcategory: subcategory,
      ingredients: ingredients,
      directions: directions,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }

  /// Fallback HTML parsing with confidence scoring
  RecipeImportResult? _parseFromHtmlWithConfidence(dynamic document, String sourceUrl) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim();

    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient'
    );
    
    final rawIngredientStrings = ingredientElements
        .map((e) => _decodeHtml(e.text.trim()))
        .where((s) => s.isNotEmpty)
        .toList();
    
    var ingredients = rawIngredientStrings
        .map((s) => _parseIngredientString(s))
        .where((i) => i.name.isNotEmpty)
        .toList();
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction'
    );
    
    final rawDirections = instructionElements
        .map((e) => _decodeHtml(e.text.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktail = _isCocktailSite(sourceUrl);
    final course = isCocktail ? 'drinks' : 'Mains';
    
    // For drinks, detect the base spirit
    String? subcategory;
    if (isCocktail) {
      final spiritCode = _detectSpirit(ingredients);
      if (spiritCode != null) {
        subcategory = Spirit.toDisplayName(spiritCode);
      }
    }

    // Calculate confidence - HTML parsing is generally less reliable
    final nameConfidence = title != null && title.isNotEmpty ? 0.7 : 0.0;
    final ingredientsConfidence = rawIngredientStrings.isNotEmpty 
        ? (ingredients.length / rawIngredientStrings.length) * 0.6 
        : 0.0;
    final directionsConfidence = rawDirections.isNotEmpty ? 0.6 : 0.0;
    final courseConfidence = isCocktail ? 0.8 : 0.3; // Low confidence for defaulting to Mains

    // Create raw ingredient data
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        name: parsed.name.isNotEmpty ? parsed.name : raw,
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    }).toList();

    return RecipeImportResult(
      name: title != null ? _cleanRecipeName(title) : null,
      course: course,
      subcategory: subcategory,
      ingredients: ingredients,
      directions: rawDirections,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: isCocktail ? ['drinks'] : ['Mains'],
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }
}

// Provider for URL recipe importer
final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
