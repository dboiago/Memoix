// ============================================================================
// memoix_recipe_parser.dart
//
// Standalone, Flutter-free extraction of Memoix's deterministic recipe-parsing
// logic from lib/core/services/url_importer.dart, lib/features/recipes/models/
// recipe.dart, lib/features/recipes/models/cuisine.dart, and
// lib/core/utils/{unit,text}_normalizer.dart, for use as a CLI tool from the
// Node.js scraping pipeline (03_extract.js).
//
// Pulled 2026-07-10. Confirmed Flutter-free: no BuildContext, no riverpod, no
// widget-tree references anywhere in the functions below. The only Flutter
// coupling found anywhere in the source was a `colour: Color(0x...)` field on
// every Cuisine entry (UI display only), stripped mechanically before this
// file was assembled.
//
// NOTE ON SCOPE: this covers pure string/JSON-LD parsing only. The HTML-DOM
// site-config matching (_extractWithSiteConfig, _tryAllSiteConfigs, etc.) is
// NOT included here, since site_configs.js already covers that ground,
// ported from this same source file in an earlier session.
//
// NOTE ON _parseCuisine: this VALIDATES/normalizes a cuisine string that's
// already present (e.g. from JSON-LD's recipeCuisine field, "Sichuan cuisine"
// -> "Chinese"). It does NOT classify cuisine from recipe content when no
// hint exists at all (e.g. sites with no JSON-LD). Does not fix model-invented
// cuisine guesses on JSON-LD-less sites.
//
// NOTE ON _cleanRecipeName: only strips a generic trailing/leading "Recipe"
// word and applies Title Case. Does NOT strip site-branding suffixes (e.g.
// "- Okonomi Kitchen"); that's still handled by the LLM prompt instruction
// added 2026-07-10, not by this function.
//
// USAGE:
//   echo '{"ingredientLines": ["50 g for beans +40g (for fresh peppers) salt"]}' \
//     | dart run memoix_recipe_parser.dart
//
// Input JSON (all fields optional, only present fields are processed):
//   {
//     "ingredientLines": ["1 cup flour", ...],
//     "nutritionRaw": { "calories": "181 kcal", "carbohydrateContent": "10 g", ... },
//     "yieldRaw": "4 servings",
//     "cuisineRaw": "Sichuan cuisine",
//     "timeRaw": { "totalTime": "PT30M", "prepTime": "PT10M", "cookTime": "PT20M" },
//     "instructionsRaw": ["Step 1...", { "text": "Step 2..." }],
//     "nameRaw": "Almond Basil Pesto Pasta Recipe"
//   }
//
// Output JSON:
//   {
//     "ingredients": [ {...Ingredient.toJson()...}, ... ],
//     "nutrition": {...NutritionInfo.toJson()...} | null,
//     "yield": "4" | null,
//     "cuisine": "Chinese" | null,
//     "time": "30 min" | null,
//     "instructions": ["Step 1...", ...],
//     "name": "Almond Basil Pesto Pasta"
//   }
// ============================================================================

import 'dart:convert';
import 'dart:io';

// ---- Data models (from recipe.dart) ----
class Ingredient {
  /// Unique identifier for sync
  String uuid = '';

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
    this.uuid = '',
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
      ..uuid = json['uuid']?.toString() ?? ''
      ..name = (json['name'] as String?) ?? ''
      ..amount = json['amount']?.toString()
      ..unit = json['unit']?.toString()
      ..preparation = json['preparation']?.toString()
      ..alternative = json['alternative']?.toString()
      ..isOptional = json['isOptional'] as bool? ?? false
      ..section = json['section']?.toString()
      ..bakerPercent = json['bakerPercent']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
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


// ---- Cuisine reference table (from cuisine.dart, Color field stripped) ----
class Cuisine {
  final String code;        // 2-letter code (KR, JP, etc.)
  final String name;        // Full name (Korean, Japanese)
  final String continent;   // Continent grouping
  final String flag;        // Emoji flag

  const Cuisine({
    required this.code,
    required this.name,
    required this.continent,
    required this.flag,
  });

  /// All supported cuisines, grouped by continent
  static const List<Cuisine> all = [
    // African
    Cuisine(code: 'DZ', name: 'Algerian', continent: 'African', flag: '🇩🇿'),
    Cuisine(code: 'CM', name: 'Cameroonian', continent: 'African', flag: '🇨🇲'),
    Cuisine(code: 'EG', name: 'Egyptian', continent: 'African', flag: '🇪🇬'),
    Cuisine(code: 'ET', name: 'Ethiopian', continent: 'African', flag: '🇪🇹'),
    Cuisine(code: 'GH', name: 'Ghanaian', continent: 'African', flag: '🇬🇭'),
    Cuisine(code: 'KE', name: 'Kenyan', continent: 'African', flag: '🇰🇪'),
    Cuisine(code: 'MA', name: 'Moroccan', continent: 'African', flag: '🇲🇦'),
    Cuisine(code: 'NG', name: 'Nigerian', continent: 'African', flag: '🇳🇬'),
    Cuisine(code: 'SN', name: 'Senegalese', continent: 'African', flag: '🇸🇳'),
    Cuisine(code: 'ZA', name: 'South African', continent: 'African', flag: '🇿🇦'),
    Cuisine(code: 'TZ', name: 'Tanzanian', continent: 'African', flag: '🇹🇿'),
    Cuisine(code: 'TN', name: 'Tunisian', continent: 'African', flag: '🇹🇳'),
    Cuisine(code: 'UG', name: 'Ugandan', continent: 'African', flag: '🇺🇬'),

    // North American
    Cuisine(code: 'CA', name: 'Canadian', continent: 'North American', flag: '🇨🇦'),
    Cuisine(code: 'MX', name: 'Mexican', continent: 'North American', flag: '🇲🇽'),
    Cuisine(code: 'US', name: 'American', continent: 'North American', flag: '🇺🇸'),

    // Central American
    Cuisine(code: 'CR', name: 'Costa Rican', continent: 'Central American', flag: '🇨🇷'),
    Cuisine(code: 'SV', name: 'Salvadoran', continent: 'Central American', flag: '🇸🇻'),
    Cuisine(code: 'GT', name: 'Guatemalan', continent: 'Central American', flag: '🇬🇹'),
    Cuisine(code: 'HN', name: 'Honduran', continent: 'Central American', flag: '🇭🇳'),
    Cuisine(code: 'NI', name: 'Nicaraguan', continent: 'Central American', flag: '🇳🇮'),
    Cuisine(code: 'PA', name: 'Panamanian', continent: 'Central American', flag: '🇵🇦'),

    // South American
    Cuisine(code: 'AR', name: 'Argentine', continent: 'South American', flag: '🇦🇷'),
    Cuisine(code: 'BO', name: 'Bolivian', continent: 'South American', flag: '🇧🇴'),
    Cuisine(code: 'BR', name: 'Brazilian', continent: 'South American', flag: '🇧🇷'),
    Cuisine(code: 'CL', name: 'Chilean', continent: 'South American', flag: '🇨🇱'),
    Cuisine(code: 'CO', name: 'Colombian', continent: 'South American', flag: '🇨🇴'),
    Cuisine(code: 'EC', name: 'Ecuadorian', continent: 'South American', flag: '🇪🇨'),
    Cuisine(code: 'PY', name: 'Paraguayan', continent: 'South American', flag: '🇵🇾'),
    Cuisine(code: 'PE', name: 'Peruvian', continent: 'South American', flag: '🇵🇪'),
    Cuisine(code: 'UY', name: 'Uruguayan', continent: 'South American', flag: '🇺🇾'),
    Cuisine(code: 'VE', name: 'Venezuelan', continent: 'South American', flag: '🇻🇪'),

    // Asian
    Cuisine(code: 'BD', name: 'Bangladeshi', continent: 'Asian', flag: '🇧🇩'),
    Cuisine(code: 'MM', name: 'Burmese', continent: 'Asian', flag: '🇲🇲'),
    Cuisine(code: 'KH', name: 'Cambodian', continent: 'Asian', flag: '🇰🇭'),
    Cuisine(code: 'CN', name: 'Chinese', continent: 'Asian', flag: '🇨🇳'),
    Cuisine(code: 'IN', name: 'Indian', continent: 'Asian', flag: '🇮🇳'),
    Cuisine(code: 'ID', name: 'Indonesian', continent: 'Asian', flag: '🇮🇩'),
    Cuisine(code: 'JP', name: 'Japanese', continent: 'Asian', flag: '🇯🇵'),
    Cuisine(code: 'KR', name: 'Korean', continent: 'Asian', flag: '🇰🇷'),
    Cuisine(code: 'LA', name: 'Laotian', continent: 'Asian', flag: '🇱🇦'),
    Cuisine(code: 'MY', name: 'Malaysian', continent: 'Asian', flag: '🇲🇾'),
    Cuisine(code: 'MN', name: 'Mongolian', continent: 'Asian', flag: '🇲🇳'),
    Cuisine(code: 'NP', name: 'Nepali', continent: 'Asian', flag: '🇳🇵'),
    Cuisine(code: 'PK', name: 'Pakistani', continent: 'Asian', flag: '🇵🇰'),
    Cuisine(code: 'PH', name: 'Filipino', continent: 'Asian', flag: '🇵🇭'),
    Cuisine(code: 'SG', name: 'Singaporean', continent: 'Asian', flag: '🇸🇬'),
    Cuisine(code: 'LK', name: 'Sri Lankan', continent: 'Asian', flag: '🇱🇰'),
    Cuisine(code: 'TW', name: 'Taiwanese', continent: 'Asian', flag: '🇹🇼'),
    Cuisine(code: 'TH', name: 'Thai', continent: 'Asian', flag: '🇹🇭'),
    Cuisine(code: 'VN', name: 'Vietnamese', continent: 'Asian', flag: '🇻🇳'),

    // Caribbean
    Cuisine(code: 'BS', name: 'Bahamian', continent: 'Caribbean', flag: '🇧🇸'),
    Cuisine(code: 'BB', name: 'Barbadian', continent: 'Caribbean', flag: '🇧🇧'),
    Cuisine(code: 'CU', name: 'Cuban', continent: 'Caribbean', flag: '🇨🇺'),
    Cuisine(code: 'DO', name: 'Dominican', continent: 'Caribbean', flag: '🇩🇴'),
    Cuisine(code: 'GY', name: 'Guyanese', continent: 'Caribbean', flag: '🇬🇾'),
    Cuisine(code: 'HT', name: 'Haitian', continent: 'Caribbean', flag: '🇭🇹'),
    Cuisine(code: 'JM', name: 'Jamaican', continent: 'Caribbean', flag: '🇯🇲'),
    Cuisine(code: 'PR', name: 'Puerto Rican', continent: 'Caribbean', flag: '🇵🇷'),
    Cuisine(code: 'TT', name: 'Trinidadian', continent: 'Caribbean', flag: '🇹🇹'),

    // European
    Cuisine(code: 'AL', name: 'Albanian', continent: 'European', flag: '🇦🇱'),
    Cuisine(code: 'AT', name: 'Austrian', continent: 'European', flag: '🇦🇹'),
    Cuisine(code: 'BY', name: 'Belarusian', continent: 'European', flag: '🇧🇾'),
    Cuisine(code: 'BE', name: 'Belgian', continent: 'European', flag: '🇧🇪'),
    Cuisine(code: 'BA', name: 'Bosnian', continent: 'European', flag: '🇧🇦'),
    Cuisine(code: 'GB', name: 'British', continent: 'European', flag: '🇬🇧'),
    Cuisine(code: 'BG', name: 'Bulgarian', continent: 'European', flag: '🇧🇬'),
    Cuisine(code: 'HR', name: 'Croatian', continent: 'European', flag: '🇭🇷'),
    Cuisine(code: 'CY', name: 'Cypriot', continent: 'European', flag: '🇨🇾'),
    Cuisine(code: 'CZ', name: 'Czech', continent: 'European', flag: '🇨🇿'),
    Cuisine(code: 'DK', name: 'Danish', continent: 'European', flag: '🇩🇰'),
    Cuisine(code: 'NL', name: 'Dutch', continent: 'European', flag: '🇳🇱'),
    Cuisine(code: 'EE', name: 'Estonian', continent: 'European', flag: '🇪🇪'),
    Cuisine(code: 'FI', name: 'Finnish', continent: 'European', flag: '🇫🇮'),
    Cuisine(code: 'FR', name: 'French', continent: 'European', flag: '🇫🇷'),
    Cuisine(code: 'GE', name: 'Georgian', continent: 'European', flag: '🇬🇪'),
    Cuisine(code: 'DE', name: 'German', continent: 'European', flag: '🇩🇪'),
    Cuisine(code: 'GR', name: 'Greek', continent: 'European', flag: '🇬🇷'),
    Cuisine(code: 'HU', name: 'Hungarian', continent: 'European', flag: '🇭🇺'),
    Cuisine(code: 'IS', name: 'Icelandic', continent: 'European', flag: '🇮🇸'),
    Cuisine(code: 'IE', name: 'Irish', continent: 'European', flag: '🇮🇪'),
    Cuisine(code: 'IT', name: 'Italian', continent: 'European', flag: '🇮🇹'),
    Cuisine(code: 'LV', name: 'Latvian', continent: 'European', flag: '🇱🇻'),
    Cuisine(code: 'LT', name: 'Lithuanian', continent: 'European', flag: '🇱🇹'),
    Cuisine(code: 'MT', name: 'Maltese', continent: 'European', flag: '🇲🇹'),
    Cuisine(code: 'MD', name: 'Moldovan', continent: 'European', flag: '🇲🇩'),
    Cuisine(code: 'ME', name: 'Montenegrin', continent: 'European', flag: '🇲🇪'),
    Cuisine(code: 'NO', name: 'Norwegian', continent: 'European', flag: '🇳🇴'),
    Cuisine(code: 'PL', name: 'Polish', continent: 'European', flag: '🇵🇱'),
    Cuisine(code: 'PT', name: 'Portuguese', continent: 'European', flag: '🇵🇹'),
    Cuisine(code: 'RO', name: 'Romanian', continent: 'European', flag: '🇷🇴'),
    Cuisine(code: 'RU', name: 'Russian', continent: 'European', flag: '🇷🇺'),
    Cuisine(code: 'RS', name: 'Serbian', continent: 'European', flag: '🇷🇸'),
    Cuisine(code: 'SK', name: 'Slovak', continent: 'European', flag: '🇸🇰'),
    Cuisine(code: 'SI', name: 'Slovenian', continent: 'European', flag: '🇸🇮'),
    Cuisine(code: 'ES', name: 'Spanish', continent: 'European', flag: '🇪🇸'),
    Cuisine(code: 'SE', name: 'Swedish', continent: 'European', flag: '🇸🇪'),
    Cuisine(code: 'CH', name: 'Swiss', continent: 'European', flag: '🇨🇭'),
    Cuisine(code: 'UA', name: 'Ukrainian', continent: 'European', flag: '🇺🇦'),

    // Middle Eastern
    Cuisine(code: 'AF', name: 'Afghan', continent: 'Middle Eastern', flag: '🇦🇫'),
    Cuisine(code: 'BH', name: 'Bahraini', continent: 'Middle Eastern', flag: '🇧🇭'),
    Cuisine(code: 'AE', name: 'Emirati', continent: 'Middle Eastern', flag: '🇦🇪'),
    Cuisine(code: 'IR', name: 'Persian', continent: 'Middle Eastern', flag: '🇮🇷'),
    Cuisine(code: 'IQ', name: 'Iraqi', continent: 'Middle Eastern', flag: '🇮🇶'),
    Cuisine(code: 'IL', name: 'Israeli', continent: 'Middle Eastern', flag: '🇮🇱'),
    Cuisine(code: 'JO', name: 'Jordanian', continent: 'Middle Eastern', flag: '🇯🇴'),
    Cuisine(code: 'KW', name: 'Kuwaiti', continent: 'Middle Eastern', flag: '🇰🇼'),
    Cuisine(code: 'LB', name: 'Lebanese', continent: 'Middle Eastern', flag: '🇱🇧'),
    Cuisine(code: 'OM', name: 'Omani', continent: 'Middle Eastern', flag: '🇴🇲'),
    Cuisine(code: 'PS', name: 'Palestinian', continent: 'Middle Eastern', flag: '🇵🇸'),
    Cuisine(code: 'QA', name: 'Qatari', continent: 'Middle Eastern', flag: '🇶🇦'),
    Cuisine(code: 'SA', name: 'Saudi', continent: 'Middle Eastern', flag: '🇸🇦'),
    Cuisine(code: 'SY', name: 'Syrian', continent: 'Middle Eastern', flag: '🇸🇾'),
    Cuisine(code: 'TR', name: 'Turkish', continent: 'Middle Eastern', flag: '🇹🇷'),
    Cuisine(code: 'YE', name: 'Yemeni', continent: 'Middle Eastern', flag: '🇾🇪'),

    // Oceanian
    Cuisine(code: 'AU', name: 'Australian', continent: 'Oceanian', flag: '🇦🇺'),
    Cuisine(code: 'FJ', name: 'Fijian', continent: 'Oceanian', flag: '🇫🇯'),
    Cuisine(code: 'HI', name: 'Hawaiian', continent: 'Oceanian', flag: '�🇸'),
    Cuisine(code: 'NZ', name: 'New Zealand', continent: 'Oceanian', flag: '🇳🇿'),
    Cuisine(code: 'PG', name: 'Papua New Guinean', continent: 'Oceanian', flag: '🇵🇬'),
    Cuisine(code: 'WS', name: 'Samoan', continent: 'Oceanian', flag: '🇼🇸'),
    Cuisine(code: 'TO', name: 'Tongan', continent: 'Oceanian', flag: '🇹🇴'),
  ];

  /// Get all unique continents (sorted alphabetically)
  static List<String> get continents {
    final continents = all.map((c) => c.continent).toSet().toList();
    continents.sort();
    return continents;
  }

  /// Get cuisines for a specific continent (sorted alphabetically by name)
  static List<Cuisine> forContinent(String continent) {
    final cuisines = all.where((c) => c.continent == continent).toList();
    cuisines.sort((a, b) => a.name.compareTo(b.name));
    return cuisines;
  }

  /// Get cuisine by code
  static Cuisine? byCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get cuisine by name (case-insensitive)
  static Cuisine? byName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return all.firstWhere((c) => c.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Get the continent for a cuisine (by code or name)
  static String? continentFor(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Try by code first (2-3 letter codes)
    if (cuisine.length <= 3) {
      final byCodeResult = byCode(cuisine.toUpperCase());
      if (byCodeResult != null) return byCodeResult.continent;
    }
    
    // Try by name
    final byNameResult = byName(cuisine);
    if (byNameResult != null) return byNameResult.continent;
    
    // Check adjective forms
    final lower = cuisine.toLowerCase().trim();
    for (final c in all) {
      if (c.name.toLowerCase() == lower) return c.continent;
    }
    
    return null;
  }

  /// Get all cuisines sorted by continent then name
  static List<Cuisine> get sortedAll {
    final sorted = List<Cuisine>.from(all);
    sorted.sort((a, b) {
      final continentCompare = a.continent.compareTo(b.continent);
      if (continentCompare != 0) return continentCompare;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// Convert a country/region name or code to its cuisine adjective form
  /// e.g., "Japan" -> "Japanese", "Korea" -> "Korean", "JP" -> "Japanese"
  static String toAdjective(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    
    // First check if it's a 2-3 letter country code
    if (raw.length <= 3) {
      final cuisine = byCode(raw.toUpperCase());
      if (cuisine != null) return cuisine.name;
    }
    
    // Map of country/region names to adjective forms
    const countryToAdjective = {
      // Asian
      'japan': 'Japanese',
      'korea': 'Korean',
      'south korea': 'Korean',
      'china': 'Chinese',
      'india': 'Indian',
      'thailand': 'Thai',
      'vietnam': 'Vietnamese',
      'philippines': 'Filipino',
      'indonesia': 'Indonesian',
      'malaysia': 'Malaysian',
      'singapore': 'Singaporean',
      'taiwan': 'Taiwanese',
      'pakistan': 'Pakistani',
      'nepal': 'Nepali',
      'sri lanka': 'Sri Lankan',
      
      // European
      'france': 'French',
      'italy': 'Italian',
      'spain': 'Spanish',
      'germany': 'German',
      'greece': 'Greek',
      'uk': 'British',
      'united kingdom': 'British',
      'great britain': 'British',
      'england': 'British',
      'ireland': 'Irish',
      'poland': 'Polish',
      'portugal': 'Portuguese',
      'russia': 'Russian',
      'sweden': 'Swedish',
      'hungary': 'Hungarian',
      'ukraine': 'Ukrainian',
      'austria': 'Austrian',
      'belgium': 'Belgian',
      'croatia': 'Croatian',
      'czech republic': 'Czech',
      'czechia': 'Czech',
      'denmark': 'Danish',
      'netherlands': 'Dutch',
      'holland': 'Dutch',
      'finland': 'Finnish',
      'norway': 'Norwegian',
      'romania': 'Romanian',
      'serbia': 'Serbian',
      'switzerland': 'Swiss',
      
      // Americas
      'usa': 'American',
      'united states': 'American',
      'america': 'American',
      'mexico': 'Mexican',
      'brazil': 'Brazilian',
      'argentina': 'Argentine',
      'peru': 'Peruvian',
      'canada': 'Canadian',
      'chile': 'Chilean',
      'colombia': 'Colombian',
      'venezuela': 'Venezuelan',
      
      // Caribbean
      'jamaica': 'Jamaican',
      'cuba': 'Cuban',
      'haiti': 'Haitian',
      'dominican republic': 'Dominican',
      'puerto rico': 'Puerto Rican',
      'trinidad': 'Trinidadian',
      'trinidad and tobago': 'Trinidadian',
      'barbados': 'Barbadian',
      
      // Middle Eastern
      'turkey': 'Turkish',
      'lebanon': 'Lebanese',
      'israel': 'Israeli',
      'iran': 'Persian',
      'persia': 'Persian',
      'middle east': 'Middle Eastern',
      'iraq': 'Iraqi',
      'syria': 'Syrian',
      'jordan': 'Jordanian',
      'palestine': 'Palestinian',
      'saudi arabia': 'Saudi',
      'yemen': 'Yemeni',
      'afghanistan': 'Afghan',
      
      // African
      'morocco': 'Moroccan',
      'ethiopia': 'Ethiopian',
      'south africa': 'South African',
      'egypt': 'Egyptian',
      'nigeria': 'Nigerian',
      'ghana': 'Ghanaian',
      'kenya': 'Kenyan',
      'tunisia': 'Tunisian',
      
      // Oceanian
      'australia': 'Australian',
      'new zealand': 'New Zealand',
      'hawaii': 'Hawaiian',
      'fiji': 'Fijian',
      'samoa': 'Samoan',
      
      // Already adjective forms (return as-is)
      'japanese': 'Japanese',
      'korean': 'Korean',
      'chinese': 'Chinese',
      'indian': 'Indian',
      'thai': 'Thai',
      'vietnamese': 'Vietnamese',
      'filipino': 'Filipino',
      'indonesian': 'Indonesian',
      'malaysian': 'Malaysian',
      'singaporean': 'Singaporean',
      'taiwanese': 'Taiwanese',
      'pakistani': 'Pakistani',
      'nepali': 'Nepali',
      'sri lankan': 'Sri Lankan',
      'french': 'French',
      'italian': 'Italian',
      'spanish': 'Spanish',
      'german': 'German',
      'greek': 'Greek',
      'british': 'British',
      'irish': 'Irish',
      'polish': 'Polish',
      'portuguese': 'Portuguese',
      'russian': 'Russian',
      'swedish': 'Swedish',
      'hungarian': 'Hungarian',
      'ukrainian': 'Ukrainian',
      'austrian': 'Austrian',
      'belgian': 'Belgian',
      'croatian': 'Croatian',
      'czech': 'Czech',
      'danish': 'Danish',
      'dutch': 'Dutch',
      'finnish': 'Finnish',
      'norwegian': 'Norwegian',
      'romanian': 'Romanian',
      'serbian': 'Serbian',
      'swiss': 'Swiss',
      'american': 'American',
      'mexican': 'Mexican',
      'brazilian': 'Brazilian',
      'argentine': 'Argentine',
      'peruvian': 'Peruvian',
      'canadian': 'Canadian',
      'chilean': 'Chilean',
      'colombian': 'Colombian',
      'venezuelan': 'Venezuelan',
      'jamaican': 'Jamaican',
      'cuban': 'Cuban',
      'haitian': 'Haitian',
      'dominican': 'Dominican',
      'puerto rican': 'Puerto Rican',
      'trinidadian': 'Trinidadian',
      'barbadian': 'Barbadian',
      'turkish': 'Turkish',
      'lebanese': 'Lebanese',
      'israeli': 'Israeli',
      'persian': 'Persian',
      'middle eastern': 'Middle Eastern',
      'iraqi': 'Iraqi',
      'syrian': 'Syrian',
      'jordanian': 'Jordanian',
      'palestinian': 'Palestinian',
      'saudi': 'Saudi',
      'yemeni': 'Yemeni',
      'afghan': 'Afghan',
      'moroccan': 'Moroccan',
      'ethiopian': 'Ethiopian',
      'south african': 'South African',
      'egyptian': 'Egyptian',
      'nigerian': 'Nigerian',
      'ghanaian': 'Ghanaian',
      'kenyan': 'Kenyan',
      'tunisian': 'Tunisian',
      'australian': 'Australian',
      'hawaiian': 'Hawaiian',
      'fijian': 'Fijian',
      'samoan': 'Samoan',
      
      // Generic regions
      'asian': 'Asian',
      'european': 'European',
      'african': 'African',
      'mediterranean': 'Mediterranean',
      'caribbean': 'Caribbean',
      'latin america': 'Latin American',
      'latin american': 'Latin American',
      'nordic': 'Nordic',
      'scandinavian': 'Scandinavian',
      'southern': 'Southern',
      'cajun': 'Cajun',
      'creole': 'Creole',
      'tex-mex': 'Tex-Mex',
    };
    
    final key = raw.toLowerCase().trim();
    return countryToAdjective[key] ?? raw;
  }
  
  /// Validate and normalize a cuisine string for import.
  /// 
  /// This method:
  /// 1. Maps regional/provincial terms to their parent national cuisine
  ///    (e.g., "Sichuan" -> "Chinese", "Cantonese" -> "Chinese")
  /// 2. Returns null if the input doesn't match any known cuisine
  /// 3. Returns the standardized cuisine name if valid
  /// 
  /// Use this during import to ensure only valid cuisines are assigned.
  static String? validateForImport(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    
    final lower = raw.toLowerCase().trim();
    
    // Map of regional/provincial terms to their parent national cuisine
    const regionToParent = <String, String>{
      // Chinese regions
      'sichuan': 'Chinese',
      'szechuan': 'Chinese',
      'szechwan': 'Chinese',
      'cantonese': 'Chinese',
      'hunan': 'Chinese',
      'hunanese': 'Chinese',
      'shanghai': 'Chinese',
      'shanghainese': 'Chinese',
      'beijing': 'Chinese',
      'peking': 'Chinese',
      'fujian': 'Chinese',
      'hokkien': 'Chinese',
      'teochew': 'Chinese',
      'hakka': 'Chinese',
      'dongbei': 'Chinese',
      'manchurian': 'Chinese',
      'xinjiang': 'Chinese',
      'uyghur': 'Chinese',
      'yunnan': 'Chinese',
      'guangdong': 'Chinese',
      'zhejiang': 'Chinese',
      'jiangsu': 'Chinese',
      'anhui': 'Chinese',
      'shandong': 'Chinese',
      
      // Indian regions
      'punjabi': 'Indian',
      'gujarati': 'Indian',
      'rajasthani': 'Indian',
      'goan': 'Indian',
      'kerala': 'Indian',
      'south indian': 'Indian',
      'north indian': 'Indian',
      'bengali': 'Indian',
      'kashmiri': 'Indian',
      'hyderabadi': 'Indian',
      'chettinad': 'Indian',
      'mughlai': 'Indian',
      'maharashtrian': 'Indian',
      'tamil': 'Indian',
      'andhra': 'Indian',
      'telugu': 'Indian',
      'konkani': 'Indian',
      
      // Japanese regions
      'osaka': 'Japanese',
      'kansai': 'Japanese',
      'kanto': 'Japanese',
      'tokyo': 'Japanese',
      'hokkaido': 'Japanese',
      'okinawan': 'Japanese',
      'kyoto': 'Japanese',
      
      // Italian regions
      'tuscan': 'Italian',
      'tuscany': 'Italian',
      'sicilian': 'Italian',
      'sicily': 'Italian',
      'neapolitan': 'Italian',
      'naples': 'Italian',
      'roman': 'Italian',
      'rome': 'Italian',
      'venetian': 'Italian',
      'lombardy': 'Italian',
      'milanese': 'Italian',
      'piedmont': 'Italian',
      'piedmontese': 'Italian',
      'emilia-romagna': 'Italian',
      'bolognese': 'Italian',
      'ligurian': 'Italian',
      'sardinian': 'Italian',
      'calabrian': 'Italian',
      'puglia': 'Italian',
      'amalfi': 'Italian',
      
      // French regions
      'provençal': 'French',
      'provencal': 'French',
      'provence': 'French',
      'normandy': 'French',
      'norman': 'French',
      'breton': 'French',
      'brittany': 'French',
      'alsatian': 'French',
      'alsace': 'French',
      'burgundy': 'French',
      'burgundian': 'French',
      'lyonnaise': 'French',
      'lyon': 'French',
      'basque': 'French',
      'parisian': 'French',
      'bordeaux': 'French',
      
      // Spanish regions
      'catalan': 'Spanish',
      'catalonia': 'Spanish',
      'andalusian': 'Spanish',
      'andalusia': 'Spanish',
      'galician': 'Spanish',
      'valencian': 'Spanish',
      'barcelona': 'Spanish',
      'madrid': 'Spanish',
      'castilian': 'Spanish',
      
      // American regions
      'southern': 'American',
      'new england': 'American',
      'cajun': 'American',
      'creole': 'American',
      'tex-mex': 'American',
      'southwestern': 'American',
      'california': 'American',
      'pacific northwest': 'American',
      'new orleans': 'American',
      'louisiana': 'American',
      'southern american': 'American',
      
      // Thai regions
      'isaan': 'Thai',
      'isan': 'Thai',
      'northern thai': 'Thai',
      'southern thai': 'Thai',
      'bangkok': 'Thai',
      
      // Mexican regions
      'oaxacan': 'Mexican',
      'oaxaca': 'Mexican',
      'yucatan': 'Mexican',
      'yucatecan': 'Mexican',
      'veracruz': 'Mexican',
      'baja': 'Mexican',
      'jalisco': 'Mexican',
      'michoacan': 'Mexican',
      'puebla': 'Mexican',
      
      // Other regional terms
      'levantine': 'Lebanese',
      'aegean': 'Greek',
      'bavarian': 'German',
      'austrian': 'Austrian',  // Keep as valid
      'viennese': 'Austrian',
      'swiss german': 'Swiss',
    };
    
    // Check if it's a known regional term first
    if (regionToParent.containsKey(lower)) {
      return regionToParent[lower];
    }
    
    // Try to find a matching cuisine in our standard list
    // First try exact match by name
    final byNameMatch = byName(raw);
    if (byNameMatch != null) {
      return byNameMatch.name;
    }
    
    // Try adjective conversion (handles country names -> adjective)
    final adjective = toAdjective(raw);
    final byAdjectiveMatch = byName(adjective);
    if (byAdjectiveMatch != null) {
      return byAdjectiveMatch.name;
    }
    
    // Not a recognized cuisine - return null to indicate validation failure
    return null;
  }
  
  /// Get a list of all valid cuisine names (for autocomplete/validation UI)
  static List<String> get allNames {
    return all.map((c) => c.name).toList()..sort();
  }
}


// ---- Normalizer utilities (from core/utils/, copied verbatim, zero deps) ----
/// Utility for normalizing measurement units to their abbreviations
class UnitNormalizer {
  /// Map of common unit variations to their normalized abbreviation
  static const Map<String, String> _unitMap = {
    // Volume - cups
    'cup': 'C',
    'cups': 'C',
    'c': 'C',
    
    // Volume - tablespoons
    'tablespoon': 'Tbsp',
    'tablespoons': 'Tbsp',
    'tbsp': 'Tbsp',
    'tbs': 'Tbsp',  // OCR often reads "Tbs." without the 'p'
    'tb': 'Tbsp',
    't': 'Tbsp', // Only uppercase T, lowercase t is teaspoon
    
    // Volume - teaspoons
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'tsp': 'tsp',
    'ts': 'tsp',
    
    // Volume - fluid ounces
    'fluid ounce': 'fl oz',
    'fluid ounces': 'fl oz',
    'fl. oz': 'fl oz',
    'fl.oz': 'fl oz',
    'floz': 'fl oz',
    
    // Volume - liters
    'liter': 'L',
    'liters': 'L',
    'litre': 'L',
    'litres': 'L',
    'l': 'L',
    
    // Volume - milliliters
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'mls': 'ml',
    
    // Weight - grams
    'gram': 'g',
    'grams': 'g',
    'gr': 'g',
    'gm': 'g',
    'gms': 'g',
    
    // Weight - kilograms
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'kgs': 'kg',
    
    // Weight - milligrams
    'milligram': 'mg',
    'milligrams': 'mg',
    'mgs': 'mg',
    
    // Weight - ounces
    'ounce': 'oz',
    'ounces': 'oz',
    
    // Weight - pounds
    'pound': 'lb',
    'pounds': 'lb',
    'lbs': 'lb',
    
    // Common cooking units
    'can': 'can',
    'cans': 'cans',
    'bunch': 'bunch',
    'bunches': 'bunches',
    'clove': 'clove',
    'cloves': 'clove',
    'pinch': 'pinch',
    'pinches': 'pinches',
    'dash': 'dash',
    'dashes': 'dashes',
    'slice': 'slice',
    'slices': 'slices',
    'piece': 'pc',
    'pieces': 'pcs',
    'pcs': 'pcs',
    'pc': 'pc',
    'sprig': 'sprig',
    'sprigs': 'sprigs',
    'stalk': 'stalk',
    'stalks': 'stalks',
    'head': 'head',
    'heads': 'heads',
    'package': 'pkg',
    'packages': 'pkgs',
    'pkg': 'pkg',
    'pkgs': 'pkgs',
    'stick': 'stick',
    'sticks': 'sticks',
    'drop': 'drop',
    'drops': 'drops',
    'handful': 'handful',
    'handfuls': 'handfuls',
    'pint': 'pt',
    'pints': 'pt',
    'pt': 'pt',
    'quart': 'qt',
    'quarts': 'qt',
    'qt': 'qt',
    'gallon': 'gal',
    'gallons': 'gal',
    'gal': 'gal',
    
    // Size descriptors (kept as-is for countable items like "2 large eggs")
    'large': 'large',
    'medium': 'medium',
    'small': 'small',
  };
  
  /// Normalize a unit string to its abbreviation
  /// Returns the original string if no match is found
  static String normalize(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    
    var trimmed = unit.trim();
    
    // Strip trailing period (e.g., "tsp." -> "tsp")
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    
    final lower = trimmed.toLowerCase();
    
    // Check for exact match in map
    if (_unitMap.containsKey(lower)) {
      return _unitMap[lower]!;
    }
    
    // Check if it's already a normalized abbreviation (preserve case)
    final normalizedValues = _unitMap.values.toSet();
    if (normalizedValues.contains(trimmed)) {
      return trimmed;
    }
    
    // Return original if no match
    return trimmed;
  }

  /// De-pluralizes a unit string for use as a grouping key.
  ///
  /// Applied **only** during shopping list aggregation to ensure that variant
  /// spellings of the same unit (e.g. "cloves" vs "clove", "pinches" vs
  /// "pinch") land in the same quantity bucket.
  ///
  /// Does NOT modify the stored or displayed unit — purely for bucketing.
  ///
  /// Examples:
  ///   normalizeUnit('cloves')  → 'clove'
  ///   normalizeUnit('pinches') → 'pinch'
  ///   normalizeUnit('tbsp')    → 'tbsp'   (no trailing 's', unchanged)
  ///   normalizeUnit('C')       → 'c'      (lowercased)
  static String normalizeUnit(String unit) {
    var u = unit.toLowerCase().trim();
    u = u.replaceAll(RegExp(r'ies$'), 'y');
    u = u.replaceAll(RegExp(r'oes$'), 'o');
    u = u.replaceAll(RegExp(r'(?<=[^aeiou])es$'), ''); // bunches→bunch, dashes→dash, pinches→pinch
    u = u.replaceAll(RegExp(r'ses$'), 's');
    u = u.replaceAll(RegExp(r'(?<![sui])s$'), '');
    return u;
  }

  /// Check if a string is a recognized unit
  static bool isRecognizedUnit(String? unit) {
    if (unit == null || unit.isEmpty) return false;
    var cleaned = unit.trim();
    // Strip trailing period (e.g. "C." → "C", "tsp." → "tsp")
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final lower = cleaned.toLowerCase();
    return _unitMap.containsKey(lower) ||
           _unitMap.values.contains(cleaned);
  }
  
  /// Get all possible unit options for autocomplete
  static List<String> get allUnits {
    return _unitMap.values.toSet().toList()..sort();
  }
  
  /// Get common units for display in UI
  static const List<String> commonUnits = [
    'C',
    'Tbsp',
    'tsp',
    'oz',
    'lb',
    'g',
    'kg',
    'ml',
    'L',
    'can',
    'clove',
    'bunch',
    'pinch',
    'dash',
    'slice',
    'pc',
  ];

  /// Normalize units for all items in a list that have a unit field
  /// Works with List<Ingredient>, List<SmokingSeasoning>, List<ModernistIngredient>, etc.
  static void normalizeUnitsInList(List list) {
    for (final item in list) {
      // Use dynamic to access unit field regardless of type
      final dynamic itemWithUnit = item;
      if (itemWithUnit.unit != null && itemWithUnit.unit is String) {
        final unit = itemWithUnit.unit as String;
        if (unit.isNotEmpty) {
          itemWithUnit.unit = normalize(unit);
        }
      }
    }
  }

  /// Normalize time strings to compact format (e.g., "4h 30m", "1d", "45m")
  /// Handles various input formats: "1 hour", "30 minutes", "1 day 2 hours", "1.5h", etc.
  static String normalizeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    
    final trimmed = timeStr.trim().toLowerCase();
    
    // Parse components
    double totalMinutes = 0;
    
    // Match days (including decimals like "1.5 days")
    final dayMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:days?|d\b)').firstMatch(trimmed);
    if (dayMatch != null) {
      totalMinutes += double.parse(dayMatch.group(1)!) * 1440;
    }
    
    // Match hours (including decimals like "1.5h" or "1.5 hours")
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h\b)').firstMatch(trimmed);
    if (hourMatch != null) {
      totalMinutes += double.parse(hourMatch.group(1)!) * 60;
    }
    
    // Match minutes (including decimals)
    final minMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m\b)').firstMatch(trimmed);
    if (minMatch != null) {
      totalMinutes += double.parse(minMatch.group(1)!);
    }
    
    // If nothing parsed, return original
    if (totalMinutes == 0) return timeStr;
    
    return formatMinutes(totalMinutes.round());
  }

  /// Format total minutes as compact string (e.g., "4h 30m", "1d", "45m")
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    
    final days = totalMinutes ~/ 1440;
    final remAfterDays = totalMinutes % 1440;
    final hours = remAfterDays ~/ 60;
    final mins = remAfterDays % 60;
    
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (mins > 0) parts.add('${mins}m');
    
    return parts.join(' ');
  }

  /// Normalize serves string to just numbers (e.g., "Serves 4" -> "4", "4 people" -> "4")
  static String normalizeServes(String? serves) {
    if (serves == null || serves.isEmpty) return '';
    
    // Remove leading colons and whitespace
    var cleaned = serves.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[:\s]+'), '');
    
    // Extract just the number(s)
    final match = RegExp(r'(\d+(?:\s*[-–]\s*\d+)?)').firstMatch(cleaned);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }
    
    return cleaned.trim();
  }

  /// Normalize temperature string to include degree symbol
  /// Handles various formats: "225", "225F", "225 F", "225°F", "107C", etc.
  static String normalizeTemperature(String? temp) {
    if (temp == null || temp.isEmpty) return '';
    
    final trimmed = temp.trim();
    
    // Already has degree symbol - return as-is
    if (trimmed.contains('°')) return trimmed;
    
    // Match number optionally followed by F/C
    final match = RegExp(r'^(\d+(?:-\d+)?)\s*([FfCc])?$').firstMatch(trimmed);
    if (match != null) {
      final number = match.group(1)!;
      final unit = match.group(2)?.toUpperCase() ?? '';
      return '$number°$unit'.trimRight();
    }
    
    // If it ends with a letter (F/C), insert degree symbol
    final unitMatch = RegExp(r'^(.+?)\s*([FfCc])$').firstMatch(trimmed);
    if (unitMatch != null) {
      final value = unitMatch.group(1)!.trim();
      final unit = unitMatch.group(2)!.toUpperCase();
      return '$value°$unit';
    }
    
    // Just a number - add degree symbol
    if (RegExp(r'^\d+(?:-\d+)?$').hasMatch(trimmed)) {
      return '$trimmed°';
    }
    
    return trimmed;
  }
}
/// Text normalization utilities for consistent data entry across the app.
/// 
/// These functions ensure the same normalization is applied whether data
/// comes from OCR, URL import, or manual entry.
/// 
/// This is the SINGLE SOURCE OF TRUTH for:
/// - Name/title cleaning (Title Case with lowercase connectors)
/// - Fraction normalization (text and decimal to unicode)
/// - Garnish normalization

/// Master text normalizer used across all importers and screens.
class TextNormalizer {
  
  /// Clean a name: collapse whitespace, remove trailing punctuation, apply Title Case.
  /// 
  /// Words like 'of', 'the', 'and', 'or' stay lowercase unless first word.
  /// Acronyms like 'BBQ', 'XO', 'MSG' stay uppercase.
  /// 
  /// Examples:
  /// - "all-purpose FLOUR" → "All-Purpose Flour"
  /// - "olive oil, " → "Olive Oil"
  /// - "juice of lemon" → "Juice of Lemon"
  /// - "bbq sauce" → "BBQ Sauce"
  static String cleanName(String name) {
    // Remove leading/trailing whitespace and collapse internal whitespace
    var cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,;:.]+$'), '').trim();
    
    if (cleaned.isEmpty) return cleaned;
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Words/acronyms that should stay uppercase
    const uppercaseWords = {
      'bbq', 'xo', 'msg', 'aoc', 'dop', 'igp', 'pdo', 'pgi', 'abv', 'ibu', 's&p', 'tt', 'ap', 'gf', 'df', 'vg', 'gmo', 'hp', 'a1',
      'usa', 'uk', 'eu', 'nyc', 'la', 'sf', 'doc', 'docg', 'aop',
      'ipa', 'blt', 'pb', 'pbj',
      'evoo', 'evo', 'ev'
      'diy', 'usda', 'fda',
      'ai', 'ml', 'tv', 'dvd', 'cd',
    };
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // Check if word (without punctuation) is an uppercase acronym
      final wordLower = word.toLowerCase().replaceAll(RegExp(r'[^a-z&0-9]'), '');
      if (uppercaseWords.contains(wordLower)) {
        // Preserve any trailing punctuation but uppercase the letters
        return word.replaceAllMapped(
          RegExp(r'[a-zA-Z]+'),
          (m) => m.group(0)!.toUpperCase(),
        );
      }
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }
  
  /// Convert text to simple Title Case (first letter uppercase, rest lowercase).
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Normalize fractions to unicode characters.
  /// 
  /// Handles:
  /// - Text fractions: "1/2" → "½"
  /// - Decimals: "0.5" → "½", "0.333" → "⅓"
  /// - Repeating decimals: "0.333..." → "⅓", "0.666..." → "⅔"
  /// 
  /// Examples:
  /// - "1 1/2 cups" → "1½ cups"
  /// - "0.25 lb" → "¼ lb"
  /// - "0.333 tsp" → "⅓ tsp"
  static String normalizeFractions(String? text) {
    if (text == null || text.isEmpty) return text ?? '';
    
    var result = text;
    
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
    
    // Replace long decimal representations of fractions
    // Match 0.333... (1/3), 0.666... (2/3), 0.166... (1/6), 0.833... (5/6)
    result = result.replaceAllMapped(
      RegExp(r'\b0\.3{3,}\d*\b'),  // 0.333...
      (m) => '⅓',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.6{3,}\d*\b'),  // 0.666...
      (m) => '⅔',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.16{2,}\d*\b'), // 0.166...
      (m) => '⅙',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b0\.83{2,}\d*\b'), // 0.833...
      (m) => '⅚',
    );
    
    // Decimal to fraction mapping for common short decimals
    const decimalToFraction = {
      '0.5': '½', '0.25': '¼', '0.75': '¾',
      '0.33': '⅓', '0.333': '⅓', '0.67': '⅔', '0.666': '⅔', '0.667': '⅔',
      '0.125': '⅛', '0.375': '⅜', '0.625': '⅝', '0.875': '⅞',
      '0.2': '⅕', '0.4': '⅖', '0.6': '⅗', '0.8': '⅘',
    };
    
    // Replace decimals
    for (final entry in decimalToFraction.entries) {
      // Only replace if it's a standalone decimal or at word boundary
      result = result.replaceAll(RegExp('(?<![\\d])${RegExp.escape(entry.key)}(?![\\d])'), entry.value);
    }
    
    return result;
  }
}

/// Normalize garnish text: remove leading articles, apply title case
/// 
/// Examples:
/// - "a lemon wedge" → "Lemon Wedge"
/// - "A sprig of mint" → "Sprig of Mint"
/// - "the orange peel." → "Orange Peel"
String normalizeGarnish(String text) {
  var cleaned = text.trim();
  
  // Remove trailing punctuation
  cleaned = cleaned.replaceAll(RegExp(r'[.,;:!?]+$'), '');
  
  // Remove leading articles (a, an, the)
  cleaned = cleaned.replaceFirst(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '');
  
  // Use shared cleanName for consistent Title Case
  return TextNormalizer.cleanName(cleaned);
}

// ---- Static lookup tables (from url_importer.dart) ----
final _htmlEntities = {
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


final _fractionMap = {
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


final _measurementNormalisation = {
    RegExp(r'\btbsp\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbs\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbl\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btb\b', caseSensitive: false): 'Tbsp',
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


// ---- Parsing functions (from url_importer.dart, converted to top-level) ----
  String _decodeHtml(String text) {
    var result = text;
    
    // Strip HTML tags first (e.g., <span style="...">text</span> -> text)
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    
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


  String? _extractStepFromTimestamp(String line) {
    final match = RegExp(r'^(.+?)\s*[–-]\s*\d{1,2}:\d{2}(?::\d{2})?\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }


  String _cleanDirectionLine(String line) {
    // First, try to extract step title from timestamp format
    final timestampStep = _extractStepFromTimestamp(line);
    if (timestampStep != null) {
      return timestampStep;
    }
    // Remove step numbers at the beginning
    final cleaned = line.replaceFirst(RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false), '');
    return cleaned.trim();
  }


  String _cleanRecipeName(String name) {
    var cleaned = _decodeHtml(name);
    
    // Remove common suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-–—]\s*Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^Recipe\s*[-–—:]\s*', caseSensitive: false), '');
    
    cleaned = cleaned.trim();
    
    if (cleaned.isEmpty) return cleaned;
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }


  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return _decodeHtml(value.trim());
    if (value is List && value.isNotEmpty) return _decodeHtml(value.first.toString().trim());
    return _decodeHtml(value.toString().trim());
  }


  String? _parseYield(dynamic value) {
    if (value == null) return null;
    
    String? raw;
    if (value is String) {
      raw = _decodeHtml(value);
    } else if (value is num) {
      return value.toString();
    } else if (value is List && value.isNotEmpty) {
      raw = _decodeHtml(value.first.toString());
    }
    
    if (raw == null) return null;
    
    // Check for "(X servings)" pattern first - common in King Arthur, etc.
    // e.g., "one 9" x 4" loaf (16 servings)" -> "16"
    final parenServingsMatch = RegExp(r'\((\d+)\s*(?:servings?|portions?)\)', caseSensitive: false).firstMatch(raw);
    if (parenServingsMatch != null) {
      return parenServingsMatch.group(1);
    }
    
    // Check for "X servings" pattern anywhere in string
    final servingsMatch = RegExp(r'(\d+)\s*(?:servings?|portions?)', caseSensitive: false).firstMatch(raw);
    if (servingsMatch != null) {
      return servingsMatch.group(1);
    }
    
    // Strip common prefixes like "Servings:", "Serves:", "Yield:", "Makes:"
    raw = raw.replaceFirst(RegExp(r'^(?:Servings?|Serves?|Yield|Makes?)\s*:?\s*', caseSensitive: false), '').trim();
    
    // Extract just the number from strings like "16 per loaf", "4 servings", "makes 12"
    // First try to find a number at the start
    final leadingNumber = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(raw.trim());
    if (leadingNumber != null) {
      return leadingNumber.group(1);
    }
    
    // Try "makes X" pattern
    final makesMatch = RegExp(r'makes\s+(\d+)', caseSensitive: false).firstMatch(raw);
    if (makesMatch != null) {
      return makesMatch.group(1);
    }
    
    // Strip trailing "servings" or "portions"
    raw = raw.replaceFirst(RegExp(r'\s+(?:servings?|portions?)$', caseSensitive: false), '').trim();
    
    return raw;
  }


  String? _parseCuisine(dynamic value) {
    if (value == null) return null;
    
    final cuisine = _parseString(value);
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Use the centralized cuisine validation which:
    // - Maps regions to parent cuisines (Sichuan -> Chinese)
    // - Validates against known cuisines
    // - Returns null for invalid values
    return Cuisine.validateForImport(cuisine);
  }


  String _normalizeServes(String text) {
    var cleaned = text.trim();
    
    // Check for "(X servings)" pattern first - common in King Arthur, etc.
    // e.g., "one 9" x 4" loaf (16 servings)" -> "16"
    final parenServingsMatch = RegExp(r'\((\d+)\s*(?:servings?|portions?)\)', caseSensitive: false).firstMatch(cleaned);
    if (parenServingsMatch != null) {
      return parenServingsMatch.group(1) ?? cleaned;
    }
    
    // Check for "X servings" or "serves X" pattern
    final servingsMatch = RegExp(r'(\d+)\s*(?:servings?|portions?)', caseSensitive: false).firstMatch(cleaned);
    if (servingsMatch != null) {
      return servingsMatch.group(1) ?? cleaned;
    }
    
    final servesMatch = RegExp(r'(?:serves?|yields?|makes?)\s*:?\s*(\d+)', caseSensitive: false).firstMatch(cleaned);
    if (servesMatch != null) {
      return servesMatch.group(1) ?? cleaned;
    }
    
    // Strip common prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:Servings?|Serves?|Yield|Makes?)\s*:?\s*', caseSensitive: false), '');
    // Strip trailing labels like "servings" from "4 servings"
    cleaned = cleaned.replaceFirst(RegExp(r'\s+(?:servings?|portions?)$', caseSensitive: false), '');
    
    // If what remains is a simple number, return it
    final simpleNumber = RegExp(r'^(\d+)$').firstMatch(cleaned.trim());
    if (simpleNumber != null) {
      return simpleNumber.group(1) ?? cleaned;
    }
    
    // If there's a number at the start, extract it (e.g., "4-6" -> "4-6", "4 people" -> "4")
    final leadingNumber = RegExp(r'^(\d+(?:\s*-\s*\d+)?)').firstMatch(cleaned.trim());
    if (leadingNumber != null) {
      return leadingNumber.group(1) ?? cleaned;
    }
    
    return cleaned.trim();
  }


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


  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0 min';
    final days = totalMinutes ~/ 1440;
    final remAfterDays = totalMinutes % 1440;
    final hours = remAfterDays ~/ 60;
    final mins = remAfterDays % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours hr');
    if (mins > 0) parts.add('$mins min');
    return parts.join(' ');
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
      return _formatMinutes(totalMinutes);
    }
    
    return null;
  }


  int _parseDurationMinutes(dynamic value) {
    if (value == null) return 0;
    var str = value.toString().toLowerCase().trim();
    
    // Normalize malformed ISO 8601 durations
    // Some sites use "PT1hour5M" instead of "PT1H5M"
    str = str.replaceAll(RegExp(r'hours?'), 'h');
    str = str.replaceAll(RegExp(r'minutes?|mins?'), 'm');
    str = str.replaceAll(RegExp(r'seconds?|secs?'), 's');
    
    // Parse full ISO 8601 duration format (e.g., P0Y0M0DT0H35M0.000S, PT30M, PT1H30M)
    final fullIsoRegex = RegExp(
      r'p(?:(\d+)y)?(?:(\d+)m)?(?:(\d+)d)?(?:t(?:(\d+)h)?(?:(\d+)m)?(?:[\d.]+s)?)?',
      caseSensitive: false,
    );
    final isoMatch = fullIsoRegex.firstMatch(str);
    
    if (isoMatch != null) {
      final years = int.tryParse(isoMatch.group(1) ?? '') ?? 0;
      final months = int.tryParse(isoMatch.group(2) ?? '') ?? 0;
      final days = int.tryParse(isoMatch.group(3) ?? '') ?? 0;
      final hours = int.tryParse(isoMatch.group(4) ?? '') ?? 0;
      final minutes = int.tryParse(isoMatch.group(5) ?? '') ?? 0;
      
      // Convert to total minutes
      final totalMinutes = (years * 365 * 24 * 60) + (months * 30 * 24 * 60) + 
                           (days * 24 * 60) + (hours * 60) + minutes;
      if (totalMinutes > 0) {
        return totalMinutes;
      }
    }

    // Pure number => treat as minutes
    final pureNumber = int.tryParse(str);
    if (pureNumber != null) {
      return pureNumber;
    }

    // Extract days/hours/minutes from textual formats (e.g., "6 hours 20 minutes", "380 min")
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(str);
    final hoursMatch = RegExp(r'(\d+)\s*(hours?|hrs?|h)').firstMatch(str);
    final minsMatch = RegExp(r'(\d+)\s*(minutes?|mins?|min|m)').firstMatch(str);
    int days = 0, hours = 0, minutes = 0;
    if (daysMatch != null) {
      days = int.tryParse(daysMatch.group(1) ?? '') ?? 0;
    }
    if (hoursMatch != null) {
      hours = int.tryParse(hoursMatch.group(1) ?? '') ?? 0;
    }
    if (minsMatch != null) {
      minutes = int.tryParse(minsMatch.group(1) ?? '') ?? 0;
    }
    
    if (days > 0 || hours > 0 || minutes > 0) {
      return days * 1440 + hours * 60 + minutes;
    }

    return 0;
  }


  String? _parseDuration(dynamic value) {
    if (value == null) return null;
    var str = value.toString();
    
    // Normalize malformed ISO 8601 durations
    // Some sites use "PT1hour5M" instead of "PT1H5M"
    // Also handle "PT1hours30minutes" variants
    str = str.replaceAll(RegExp(r'hours?', caseSensitive: false), 'H');
    str = str.replaceAll(RegExp(r'minutes?|mins?', caseSensitive: false), 'M');
    str = str.replaceAll(RegExp(r'seconds?|secs?', caseSensitive: false), 'S');
    
    // Parse full ISO 8601 duration format (e.g., P0Y0M0DT0H35M0.000S, PT30M, PT1H30M)
    // Format: P[n]Y[n]M[n]DT[n]H[n]M[n]S where each component is optional
    // FoodNetwork uses: P0Y0M0DT0H35M0.000S
    final fullIsoRegex = RegExp(
      r'P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:[\d.]+S)?)?',
      caseSensitive: false,
    );
    final fullMatch = fullIsoRegex.firstMatch(str);
    
    if (fullMatch != null) {
      final years = int.tryParse(fullMatch.group(1) ?? '') ?? 0;
      final months = int.tryParse(fullMatch.group(2) ?? '') ?? 0;
      final days = int.tryParse(fullMatch.group(3) ?? '') ?? 0;
      final hours = int.tryParse(fullMatch.group(4) ?? '') ?? 0;
      final minutes = int.tryParse(fullMatch.group(5) ?? '') ?? 0;
      
      // Convert to total minutes (approximate: 1 month = 30 days, 1 year = 365 days)
      final totalMinutes = (years * 365 * 24 * 60) + (months * 30 * 24 * 60) + 
                           (days * 24 * 60) + (hours * 60) + minutes;
      if (totalMinutes > 0) {
        return _formatMinutes(totalMinutes);
      }
    }
    
    // Fallback: parse non-ISO strings like "380 minutes", "6 hours 20 minutes"
    final lowered = str.toLowerCase().trim();
    // Pure number => treat as minutes
    final pureNumber = int.tryParse(lowered);
    if (pureNumber != null) {
      return _formatMinutes(pureNumber);
    }

    // Extract hours and minutes from text
    final hoursMatch = RegExp(r'(\d+)\s*(hours?|hrs?|h)').firstMatch(lowered);
    final minsMatch = RegExp(r'(\d+)\s*(minutes?|mins?|min|m)').firstMatch(lowered);
    int hours = 0;
    int minutes = 0;
    if (hoursMatch != null) {
      hours = int.tryParse(hoursMatch.group(1) ?? '') ?? 0;
    }
    if (minsMatch != null) {
      minutes = int.tryParse(minsMatch.group(1) ?? '') ?? 0;
    }
    if (hours > 0 || minutes > 0) {
      final totalMinutes = hours * 60 + minutes;
      return _formatMinutes(totalMinutes);
    }

    // Days support: "1 day 2 hours"
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(lowered);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1) ?? '') ?? 0;
      // try also to capture any hours/mins if present
      final hrs = hoursMatch != null ? (int.tryParse(hoursMatch.group(1)!) ?? 0) : 0;
      final mins = minsMatch != null ? (int.tryParse(minsMatch.group(1)!) ?? 0) : 0;
      return _formatMinutes(days * 1440 + hrs * 60 + mins);
    }

    // If nothing matched, return cleaned original
    return lowered;
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


  String? _extractBakerPercent(String text) {
    final match = RegExp(
      r'^[^,]+,\s*([\d.]+)%\s*[–—-]',  // en-dash, em-dash, or hyphen
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }


  Ingredient _parseIngredientString(String text) {
    var remaining = text;
    bool isOptional = false;
    final List<String> notesParts = [];
    String? amount;
    String? inlineSection;
    
    // Handle "Optional:" prefix at the start of ingredient line
    // e.g., "Optional: 1/4 tsp calcium chloride (aka Pickle Crisp granules)"
    // -> amount: "1/4 tsp", name: "Calcium Chloride", preparation: "optional, aka Pickle Crisp granules"
    final optionalPrefixMatch = RegExp(
      r'^Optional\s*:\s*',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (optionalPrefixMatch != null) {
      isOptional = true;
      remaining = remaining.substring(optionalPrefixMatch.end).trim();
      notesParts.add('optional');
    }
    
    // Handle "Top up with [Ingredient]" format (Difford's style)
    // e.g., "Top up with Thomas Henry Soda Water" -> name: "Thomas Henry Soda Water", amount: "Top"
    final topUpWithMatch = RegExp(
      r'^Top\s+(?:up\s+)?with\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (topUpWithMatch != null) {
      final name = topUpWithMatch.group(1)?.trim() ?? '';
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: 'Top',
      );
    }
    
    // Handle Seedlip/cocktail format: "Name: amount / metric" 
    // e.g., "Seedlip Grove 42: 1.75 oz / 53ml" or "Marmalade Cordial*: 1 oz / 30 ml"
    // Also handles "Cold Sparkling Water: Top" where "Top" means "top up"
    // Also handles unicode fractions like "Fresh lime juice: ½ oz"
    final colonAmountMatch = RegExp(
      r'^([^:]+):\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:oz|ml|cl|dash|dashes|drops?|barspoons?|tsp|tbsp)\.?|Top(?:\s+up)?|to\s+taste|as\s+needed)\s*(?:/\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:ml|cl|oz)\.?))?(.*)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (colonAmountMatch != null) {
      var name = colonAmountMatch.group(1)?.trim() ?? '';
      var primaryAmount = colonAmountMatch.group(2)?.trim() ?? '';
      final metricAmount = colonAmountMatch.group(3)?.trim();
      final extra = colonAmountMatch.group(4)?.trim() ?? '';
      
      // Remove leading and trailing * or other footnote markers from name
      name = name.replaceAll(RegExp(r'^[\*†]+|[\*†]+$'), '').trim();
      
      // Normalize "Top" to "Top" (capitalize)
      if (primaryAmount.toLowerCase() == 'top' || primaryAmount.toLowerCase() == 'top up') {
        primaryAmount = 'Top';
      }
      
      // Use the primary amount (typically oz for US sites)
      // Add metric as a note if present
      String? preparation;
      if (metricAmount != null && metricAmount.isNotEmpty) {
        preparation = metricAmount;
      }
      if (extra.isNotEmpty) {
        preparation = preparation != null ? '$preparation $extra' : extra;
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: primaryAmount,
        preparation: preparation,
      );
    }
    
    // Handle baker's percentage format: "All-Purpose Flour, 100% – 600g (4 1/2 Cups)"
    // or "Warm Water, 75% – 450g (2 Cups)" or "Extra Virgin Olive Oil, 3.3% – 20g (2 tbsp.)"
    // or "Active Dry Yeast, 0.15% – 1/4 tsp. (Instant is good too)"
    final bakerPercentMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–—-]\s*([\d./½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:g|kg|ml|l|tsp|tbsp|cup|oz|lb)s?\.?)\s*(?:\(([^)]+)\))?',  // en-dash, em-dash, or hyphen
      caseSensitive: false,
    ).firstMatch(remaining);
    if (bakerPercentMatch != null) {
      final name = bakerPercentMatch.group(1)?.trim() ?? '';
      final bakerPercent = bakerPercentMatch.group(2)?.trim();
      final amount = bakerPercentMatch.group(3)?.trim() ?? '';
      final notes = bakerPercentMatch.group(4)?.trim();
      
      // Use the amount as-is, notes go to preparation
      // Store bakerPercent in the bakerPercent field
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amount,
        preparation: notes,
        bakerPercent: bakerPercent != null ? '$bakerPercent%' : null,
      );
    }
    
    // Handle leading baker's percentage format: "15% warm water" or "2% of salt"
    // These are common in artisan bread recipes (baker's math)
    // Also handles alternatives: "2% dry yeast, or 6% fresh yeast, or 20% sourdough starter"
    final leadingBakerPercentMatch = RegExp(
      r'^([\d.]+)%\s+(?:of\s+)?(.+?)(?:,\s*(.+))?$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (leadingBakerPercentMatch != null) {
      final bakerPercent = leadingBakerPercentMatch.group(1)?.trim();
      var name = leadingBakerPercentMatch.group(2)?.trim() ?? '';
      final alternatives = leadingBakerPercentMatch.group(3)?.trim();
      
      // Clean up the name - remove leading "of" if still present
      name = name.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '').trim();
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        bakerPercent: bakerPercent != null ? '$bakerPercent%' : null,
        preparation: alternatives,
      );
    }
    
    // Handle ratio-based ingredients: "1 egg per 250 grams of flour"
    // Also handles: "1 egg per 250g flour", "2 eggs per pound of flour"
    final perRatioMatch = RegExp(
      r'^(\d+)\s+([a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s+per\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (perRatioMatch != null) {
      final amountNum = perRatioMatch.group(1)?.trim() ?? '';
      final name = perRatioMatch.group(2)?.trim() ?? '';
      var ratioNote = perRatioMatch.group(3)?.trim() ?? '';
      
      // Normalize common unit patterns in the ratio note
      ratioNote = ratioNote
          .replaceAll(RegExp(r'grams?\s+of\s+', caseSensitive: false), 'g ')
          .replaceAll(RegExp(r'grams?', caseSensitive: false), 'g')
          .replaceAll(RegExp(r'kilograms?\s+of\s+', caseSensitive: false), 'kg ')
          .replaceAll(RegExp(r'kilograms?', caseSensitive: false), 'kg')
          .replaceAll(RegExp(r'pounds?\s+of\s+', caseSensitive: false), 'lb ')
          .replaceAll(RegExp(r'pounds?', caseSensitive: false), 'lb')
          .replaceAll(RegExp(r'ounces?\s+of\s+', caseSensitive: false), 'oz ')
          .replaceAll(RegExp(r'ounces?', caseSensitive: false), 'oz')
          .trim();
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amountNum,
        preparation: 'per $ratioNote',
      );
    }
    
    // Handle "Name, amount unit (notes)" format
    // e.g., "00 Flour, 300g (10.5 oz. or about 2 Cups)"
    // e.g., "Egg Yolks, 5 each"
    // e.g., "Fine Sea Salt, 1/4 tsp. (or 1g)"
    // e.g., "EVOO, 1 tsp. (about 3g or 0.125 oz.)"
    final nameAmountMatch = RegExp(
      r'^([^,]+),\s*(\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?(?:\s*\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?)?)\s*(g|kg|ml|l|oz|lb|cup|cups|c|tbsp|tsp|each|whole|large|medium|small)?\.?\s*(?:\(([^)]+)\))?$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (nameAmountMatch != null) {
      final name = nameAmountMatch.group(1)?.trim() ?? '';
      var amountNum = nameAmountMatch.group(2)?.trim() ?? '';
      final unit = nameAmountMatch.group(3)?.trim() ?? '';
      final notes = nameAmountMatch.group(4)?.trim();
      
      // Convert text fractions to unicode
      amountNum = amountNum.replaceAllMapped(RegExp(r'(\d+)/(\d+)'), (m) {
        final frac = '${m.group(1)}/${m.group(2)}';
        return _fractionMap[frac] ?? frac;
      });
      
      final amount = unit.isNotEmpty ? '$amountNum $unit' : amountNum;
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amount,
        preparation: notes,
      );
    }
    
    // Handle simple "Ingredient, as needed" or "Ingredient Name – amount" formats
    final simpleAsNeededMatch = RegExp(
      r'^([^,–-]+),\s*(as needed|to taste)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (simpleAsNeededMatch != null) {
      final name = simpleAsNeededMatch.group(1)?.trim() ?? '';
      final note = simpleAsNeededMatch.group(2)?.trim() ?? '';
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: note,
      );
    }
    
    // Check for inline section markers like "[Sauce]" or "(For the sauce)" at the start
    final inlineSectionMatch = RegExp(
      r'^\[([^\]]+)\]\s*|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s*',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (inlineSectionMatch != null) {
      inlineSection = (inlineSectionMatch.group(1) ?? inlineSectionMatch.group(2))?.trim();
      remaining = remaining.substring(inlineSectionMatch.end).trim();
      
      // If the entire line was just a section marker (no ingredient after it), 
      // return an ingredient with only section set (acts as section header)
      if (remaining.isEmpty) {
        return Ingredient.create(
          name: '', // Empty name marks this as a pure section header
          section: inlineSection,
        );
      }
    }
    
    // Remove footnote markers like [1], *, †, etc. from both start and end
    remaining = remaining.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
    
    // Convert word numbers to digits at the start of ingredient
    // e.g., "One 6-in. sage sprig" -> "1 6-in. sage sprig"
    // e.g., "Two large eggs" -> "2 large eggs"
    const wordNumbers = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
      'eleven': '11', 'twelve': '12', 'a': '1', 'an': '1',
      'half': '½', 'quarter': '¼',
    };
    final wordNumberMatch = RegExp(r'^(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a|an|half|quarter)\b\s*', caseSensitive: false).firstMatch(remaining);
    if (wordNumberMatch != null) {
      final word = wordNumberMatch.group(1)!.toLowerCase();
      final digit = wordNumbers[word] ?? word;
      remaining = digit + remaining.substring(wordNumberMatch.end);
    }
    
    // Handle King Arthur Baking complex format:
    // "2 cups plus 2 tablespoons (255g) King Arthur Unbleached Cake Flour or King Arthur Gluten-Free Flour*"
    // Pattern: amount unit "plus" amount unit (weight) Name or Alternative
    final kingArthurMatch = RegExp(
      r'^([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s+plus\s+([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s*(?:\((\d+g?)\))?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (kingArthurMatch != null) {
      final primaryAmt = kingArthurMatch.group(1)?.trim() ?? '';
      final primaryUnit = _normalizeUnit(kingArthurMatch.group(2)?.trim() ?? '');
      final secondaryAmt = kingArthurMatch.group(3)?.trim() ?? '';
      final secondaryUnit = _normalizeUnit(kingArthurMatch.group(4)?.trim() ?? '');
      final weight = kingArthurMatch.group(5)?.trim();
      var nameAndAlt = kingArthurMatch.group(6)?.trim() ?? '';
      
      // Remove trailing asterisk/footnote markers
      nameAndAlt = nameAndAlt.replaceAll(RegExp(r'\*+$'), '').trim();
      
      // Check for "or" alternatives
      String name;
      String? alternative;
      final orMatch = RegExp(r'^(.+?)\s+or\s+(.+)$', caseSensitive: false).firstMatch(nameAndAlt);
      if (orMatch != null) {
        name = orMatch.group(1)?.trim() ?? nameAndAlt;
        alternative = orMatch.group(2)?.trim();
      } else {
        name = nameAndAlt;
      }
      
      // Build preparation string with additional info
      final prepParts = <String>[];
      prepParts.add('plus $secondaryAmt $secondaryUnit');
      if (weight != null && weight.isNotEmpty) {
        // Ensure weight has 'g' suffix
        final weightStr = weight.endsWith('g') ? weight : '${weight}g';
        prepParts.add(weightStr);
      }
      if (alternative != null) {
        prepParts.add('alt: $alternative');
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: '$primaryAmt $primaryUnit',
        preparation: prepParts.join(', '),
      );
    }
    
    // Handle simpler "X plus Y" format without the complex alternative
    // e.g., "3/4 cup plus 2 tablespoons (173g) granulated sugar"
    final simplePlusMatch = RegExp(
      r'^([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s+plus\s+([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s*(?:\((\d+g?)\))?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (simplePlusMatch != null) {
      final primaryAmt = simplePlusMatch.group(1)?.trim() ?? '';
      final primaryUnit = _normalizeUnit(simplePlusMatch.group(2)?.trim() ?? '');
      final secondaryAmt = simplePlusMatch.group(3)?.trim() ?? '';
      final secondaryUnit = _normalizeUnit(simplePlusMatch.group(4)?.trim() ?? '');
      final weight = simplePlusMatch.group(5)?.trim();
      final name = simplePlusMatch.group(6)?.trim() ?? '';
      
      // Build preparation string
      final prepParts = <String>[];
      prepParts.add('plus $secondaryAmt $secondaryUnit');
      if (weight != null && weight.isNotEmpty) {
        final weightStr = weight.endsWith('g') ? weight : '${weight}g';
        prepParts.add(weightStr);
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name.replaceAll(RegExp(r'\*+$'), '').trim()),
        amount: '$primaryAmt $primaryUnit',
        preparation: prepParts.join(', '),
      );
    }
    
    // Handle Bon Appétit style: "1 28-oz./794-g can crushed tomatoes"
    // Pattern: quantity + size-unit./size-metric + container + name
    // e.g., "1 28-oz./794-g can crushed tomatoes" -> amount: "1 can (28-oz./794-g)", name: "crushed tomatoes"
    // e.g., "1 12-oz./355-ml jar banana peppers" -> amount: "1 jar (12-oz./355-ml)", name: "banana peppers"
    final quantitySizeContainerMatch = RegExp(
      r'^(\d+)\s+([\d.]+)\s*[-–—−]?\s*(oz|ounces?)\.?\s*/\s*([\d.]+)\s*[-–—−]?\s*(g|grams?|ml|l)\s+(can|jar|bottle|package|pkg|box|bag|container|carton)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (quantitySizeContainerMatch != null) {
      final quantity = quantitySizeContainerMatch.group(1)?.trim() ?? '';
      final sizeAmt = quantitySizeContainerMatch.group(2)?.trim() ?? '';
      final sizeUnit = quantitySizeContainerMatch.group(3)?.trim() ?? '';
      final metricAmt = quantitySizeContainerMatch.group(4)?.trim() ?? '';
      final metricUnit = quantitySizeContainerMatch.group(5)?.trim() ?? '';
      final container = quantitySizeContainerMatch.group(6)?.trim() ?? '';
      final ingredientName = quantitySizeContainerMatch.group(7)?.trim() ?? '';
      
      // Normalize units
      String normalizedSizeUnit = sizeUnit.toLowerCase();
      if (normalizedSizeUnit.startsWith('ounce')) normalizedSizeUnit = 'oz';
      
      String normalizedMetricUnit = metricUnit.toLowerCase();
      if (normalizedMetricUnit.startsWith('gram')) normalizedMetricUnit = 'g';
      
      // Format: amount = "1 can", preparation = "(28-oz./794-g)" or just the metric info
      final sizeInfo = '$sizeAmt $normalizedSizeUnit / $metricAmt$normalizedMetricUnit';
      
      return Ingredient.create(
        name: _cleanIngredientName(ingredientName),
        amount: '$quantity $container',
        preparation: sizeInfo,
      );
    }
    
    // Handle dual unit amounts EARLY - before other patterns can partially match
    // Pattern: "28-oz./794-g can" or "14.5-oz./411-g can" or "One 28-oz./794-g can"
    // These have number-unit./number-unit followed by descriptor/name
    // Handle various dash types (hyphen, en-dash, em-dash) and Unicode minus
    // Also handle ounces as 'ounce' or 'ounces' not just 'oz'
    final dualUnitMatch = RegExp(
      r'^([\d.]+)\s*[-–—−]?\s*(oz|ounces?|lb|pounds?|cups?|tbsp|tsp)\.?\s*/\s*([\d.]+)\s*[-–—−]?\s*(g|kg|ml|l|grams?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (dualUnitMatch != null) {
      final primaryAmt = dualUnitMatch.group(1)?.trim() ?? '';
      final primaryUnit = dualUnitMatch.group(2)?.trim() ?? '';
      final metricAmt = dualUnitMatch.group(3)?.trim() ?? '';
      final metricUnit = dualUnitMatch.group(4)?.trim() ?? '';
      final nameWithDescriptor = dualUnitMatch.group(5)?.trim() ?? '';
      
      // Normalize units (ounces -> oz, pounds -> lb, grams -> g)
      String normalizedPrimaryUnit = primaryUnit.toLowerCase();
      if (normalizedPrimaryUnit.startsWith('ounce')) normalizedPrimaryUnit = 'oz';
      if (normalizedPrimaryUnit.startsWith('pound')) normalizedPrimaryUnit = 'lb';
      
      String normalizedMetricUnit = metricUnit.toLowerCase();
      if (normalizedMetricUnit.startsWith('gram')) normalizedMetricUnit = 'g';
      
      // Check for "can", "jar", "bottle" etc. as part of the ingredient description
      // e.g., "can crushed tomatoes" -> name: "can crushed tomatoes" or just "crushed tomatoes"
      return Ingredient.create(
        name: _cleanIngredientName(nameWithDescriptor),
        amount: '$primaryAmt $normalizedPrimaryUnit',
        preparation: '$metricAmt$normalizedMetricUnit',
      );
    }
    
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
        // Check if this looks like a ratio/recipe description that should stay with the name
        // e.g., "(2 sugar to 1 water, 65.0°Brix)" or "(3:1 simple syrup)"
        // These describe the ingredient itself, not preparation
        final looksLikeRatio = RegExp(
          r'\d+\s*(to|:|parts?)\s*\d+|brix|syrup|ratio|simple|rich',
          caseSensitive: false,
        ).hasMatch(content);
        
        if (looksLikeRatio) {
          // Keep this as part of the ingredient name, don't extract to notes
          continue;
        }
        
        // Check if it's a weight conversion (e.g., "0.6 pounds", "1 lb", "500g")
        final isWeightConversion = RegExp(
          r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$',
          caseSensitive: false,
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
      r'(\s*(?:teaspoons?|tablespoons?|cups?|c|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
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
        amount = '$amount ${_normalizeUnit(unit)}';
      }
      remaining = remaining.substring(compoundFractionMatch.end).trim();
    }
    
    // Try standalone text fraction like "1/4 tsp" (without whole number)
    if (amount == null) {
      final textFractionMatch = RegExp(
        r'^(\d+/\d+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|c|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (textFractionMatch != null) {
        var fraction = textFractionMatch.group(1) ?? '';
        final unit = textFractionMatch.group(2)?.trim() ?? '';
        // Convert text fractions to unicode
        fraction = _fractionMap[fraction] ?? fraction;
        amount = fraction;
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(textFractionMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Handle "X to Y unit" range format (e.g., "1 to 2 teaspoons")
      final toRangeMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)\s+to\s+([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|c|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (toRangeMatch != null) {
        final start = toRangeMatch.group(1)?.trim() ?? '';
        final end = toRangeMatch.group(2)?.trim() ?? '';
        final unit = toRangeMatch.group(3)?.trim() ?? '';
        amount = '$start-$end';
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(toRangeMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Original pattern for simple amounts and ranges with dash/en-dash
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+|[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|c|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (amountMatch != null) {
        final number = amountMatch.group(1)?.trim() ?? '';
        final unit = amountMatch.group(2)?.trim() ?? '';
        // Normalize the range format (remove extra spaces around dash)
        amount = number.replaceAll(RegExp(r'\s*[-–]\s*'), '-');
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(amountMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Bare-unit lines with no leading number at all ("pinch of baking
      // soda", "dash of bitters", "handful of herbs", "drop of vanilla
      // extract") -- confirmed as the actual gap: none of the four patterns
      // above can match these, since every one of them requires the string
      // to start with a digit or fraction glyph. With amount left null, the
      // whole phrase, including the unit word itself, falls through into
      // the ingredient name untouched ("pinch of baking soda" -> name
      // "Pinch Baking Soda", unit never set). These words always imply a
      // quantity of exactly one, so amount is set to "1 <unit>" here, same
      // combined-string convention the four patterns above already use,
      // and gets split into amount/unit by the same downstream logic in
      // main() that already handles that split for every other branch.
      // Scoped to words that are unambiguously a quantity, never plausibly
      // the ingredient's own name on their own -- extend this list if more
      // real cases surface, but each addition should be confirmed against
      // an actual corpus line first, not assumed.
      final unitOnlyMatch = RegExp(
        r'^(pinch(?:es)?|dash(?:es)?|handful(?:s)?|drop(?:s)?)\s+',
        caseSensitive: false,
      ).firstMatch(remaining);

      if (unitOnlyMatch != null) {
        final unit = unitOnlyMatch.group(1)?.trim() ?? '';
        amount = '1 ${_normalizeUnit(unit)}';
        remaining = remaining.substring(unitOnlyMatch.end).trim();
      }
    }

    // Strip leading "of" that some sites include after the amount
    // e.g., "2 tbsp of sunflower oil" -> remaining is "of sunflower oil" after amount extraction
    remaining = remaining.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '');
    
    // Extract leading adjectives/modifiers AFTER amount extraction
    // e.g., "boneless, skinless chicken thighs" -> extract "boneless, skinless"
    // Handles both space-separated and comma-separated modifiers
    final leadingModifierRegex = RegExp(
      r'^(boneless|skinless|skin-?on|bone-?in|frozen|fresh|dried|organic|chopped|minced|diced|sliced|grated|shredded|crushed|crumbled|smashed|cubed|melted|softened|beaten|sifted|peeled|cored|seeded|pitted|trimmed|finely|coarsely)(?:,?\s+)',
      caseSensitive: false,
    );
    
    final extractedMods = <String>[];
    while (remaining.isNotEmpty) {
      final match = leadingModifierRegex.firstMatch(remaining);
      if (match == null) break;
      
      final mod = match.group(1)?.trim().toLowerCase();
      if (mod != null && mod.isNotEmpty) {
        extractedMods.add(mod);
      }
      // Strip the matched modifier AND any following comma+space or just space
      remaining = remaining.substring(match.end).trim();
      // Also strip any leading comma that might remain
      remaining = remaining.replaceFirst(RegExp(r'^,\s*'), '');
    }
    
    // Add extracted modifiers to notesParts in correct order
    if (extractedMods.isNotEmpty) {
      notesParts.addAll(extractedMods);
    }
    
    // Extract preparation instructions after comma (e.g., "oil, I used rice bran oil")
    // But don't split on commas that are inside parentheses
    int commaIndex = -1;
    int parenDepth = 0;
    for (int i = 0; i < remaining.length; i++) {
      final char = remaining[i];
      if (char == '(') {
        parenDepth++;
      } else if (char == ')') parenDepth--;
      else if (char == ',' && parenDepth == 0) {
        commaIndex = i;
        break;
      }
    }
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
    
    // Handle "or" alternatives - e.g., "confectioners' sugar or King Arthur Snow White Sugar"
    // BUT: Don't split on "or" when it's between adjectives describing the same ingredient
    // e.g., "red or yellow onion" should stay as "red or yellow onion", not split to "red" + "alt: yellow onion"
    // Match " or " but not at very start, and not "for" or other words ending in "or"
    final orMatch = RegExp(r'\s+or\s+', caseSensitive: false).firstMatch(remaining);
    if (orMatch != null && orMatch.start > 0) {
      final beforeOr = remaining.substring(0, orMatch.start).trim();
      final afterOr = remaining.substring(orMatch.end).trim();
      
      // Check if beforeOr is just a simple adjective (color, size, etc.)
      // If so, keep the entire phrase together as the ingredient name
      final adjectivePattern = RegExp(
        r'^(red|yellow|green|white|black|brown|orange|purple|pink|blue|'
        r'large|medium|small|big|tiny|fresh|dried|frozen|canned|raw|cooked|'
        r'hot|cold|warm|sweet|sour|spicy|mild)$',
        caseSensitive: false,
      );
      
      final isSimpleAdjective = adjectivePattern.hasMatch(beforeOr);
      
      // Only treat as alternative if:
      // 1. beforeOr is NOT just a simple adjective
      // 2. afterOr looks like an ingredient name, not a phrase
      // (avoid splitting on "or until golden brown" type phrases in directions that leaked in)
      if (!isSimpleAdjective && 
          afterOr.isNotEmpty && 
          !RegExp(r'^(until|if|when|as)\s', caseSensitive: false).hasMatch(afterOr)) {
        remaining = beforeOr;
        // Clean up the alternative - remove trailing punctuation and footnotes
        final alternative = afterOr
            .replaceAll(RegExp(r'\*+$'), '')
            .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
            .trim();
        if (alternative.isNotEmpty) {
          notesParts.insert(0, 'alt: $alternative');
        }
      }
      // If isSimpleAdjective, keep the entire "red or yellow onion" as the name (don't split)
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
              .trim(),)
          .where((n) => n.isNotEmpty)
          // Filter out footnote references like "Footnote 1", "Footnote 2", etc.
          .where((n) => !RegExp(r'^Footnote\s*\d*$', caseSensitive: false).hasMatch(n))
          .join(', ');
      if (finalNotes.isEmpty) finalNotes = null;
    }
    
    return Ingredient.create(
      name: _cleanIngredientName(remaining),
      amount: _normalizeFractions(amount),
      preparation: finalNotes,
      isOptional: isOptional,
      section: inlineSection,
    );
  }


  String _cleanIngredientName(String name) {
    if (name.isEmpty) return name;
    
    var cleaned = name.trim();
    
    // Remove trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,;:.]+$'), '').trim();
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }


  String _normalizeUnit(String unit) {
    return UnitNormalizer.normalize(unit);
  }


  String? _normalizeFractions(String? text) {
    if (text == null || text.isEmpty) return text;
    return TextNormalizer.normalizeFractions(text);
  }


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


// ---- CLI entry point ----
//
// Reads one JSON object from stdin, writes one JSON object to stdout.
// Designed to be called once per recipe (batching all ingredient lines into
// a single process invocation), not once per line, to avoid paying Dart's
// process-startup cost 15-20 times per recipe.
void main() async {
  final input = await stdin.transform(utf8.decoder).join();

  Map<String, dynamic> data;
  try {
    data = jsonDecode(input) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Invalid JSON on stdin: $e');
    exit(1);
  }

  final result = <String, dynamic>{};

  try {
    if (data['ingredientLines'] != null) {
      final lines = (data['ingredientLines'] as List).map((e) => e.toString());
      result['ingredients'] = lines.map((line) {
        try {
          final ingredient = _parseIngredientString(line);
          // _parseIngredientString's most common branch (plain "amount unit
          // name" lines with no comma) folds the unit into the amount string
          // and leaves `unit` null -- confirmed 2026-07-10 by testing the
          // compiled output directly, not assumed. This is not a porting bug:
          // it's how url_importer.dart's own source already behaves. The
          // actual amount/unit split the user has validated across hundreds
          // of real saved recipes happens later, in recipe_edit_screen.dart's
          // save path, which takes the single combined amount string and
          // splits on the first whitespace: first token -> amount, remainder
          // -> unit. Reproduced here verbatim from that logic, applied only
          // when this function's own branches left unit empty, so branches
          // that already split correctly (compound fractions, colon-format,
          // etc.) are untouched.
          if ((ingredient.unit == null || ingredient.unit!.isEmpty) &&
              ingredient.amount != null) {
            final normalized = TextNormalizer.normalizeFractions(ingredient.amount!) ?? ingredient.amount!;
            final parts = normalized.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              ingredient.amount = parts.first;
              ingredient.unit = parts.sublist(1).join(' ');
            }
          }
          return ingredient.toJson();
        } catch (e) {
          // Never let one bad line kill the whole batch; surface it instead
          // of silently dropping it, so it's still visible for manual review.
          return {'error': e.toString(), 'rawLine': line};
        }
      }).toList();
    }

    if (data['nutritionRaw'] != null) {
      final nutrition = _parseNutrition(data['nutritionRaw']);
      result['nutrition'] = nutrition?.toJson();
    }

    if (data['yieldRaw'] != null) {
      result['yield'] = _parseYield(data['yieldRaw']);
    }

    if (data['cuisineRaw'] != null) {
      result['cuisine'] = _parseCuisine(data['cuisineRaw']);
    }

    if (data['timeRaw'] != null) {
      result['time'] = _parseTime(data['timeRaw'] as Map);
    }

    if (data['instructionsRaw'] != null) {
      result['instructions'] = _parseInstructions(data['instructionsRaw']);
    }

    if (data['nameRaw'] != null) {
      result['name'] = _cleanRecipeName(data['nameRaw'].toString());
    }
  } catch (e, st) {
    stderr.writeln('Parse error: $e\n$st');
    exit(1);
  }

  stdout.write(jsonEncode(result));
}
