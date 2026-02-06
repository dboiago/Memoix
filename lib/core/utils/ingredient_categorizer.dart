import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

enum IngredientCategory {
  produce, meat, poultry, seafood, egg, cheese, dairy,
  grain, pasta, legume, nut, spice, condiment, oil,
  vinegar, flour, sugar, leavening, alcohol, pop, juice, beverage,
  unknown, // index 22 — must stay here for gzip compatibility
  pantry,  // index 23 — jarred/canned/preserved goods, spreads (store center aisles)
}

/// Rich metadata for an ingredient from OpenFoodFacts.
/// Available when ingredients_meta.gz is loaded.
class IngredientMeta {
  final int categoryIndex;
  final bool isVegan;
  final bool isVegetarian;
  final String? allergens;
  final int? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sodium;

  const IngredientMeta({
    required this.categoryIndex,
    this.isVegan = false,
    this.isVegetarian = false,
    this.allergens,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
  });

  factory IngredientMeta.fromJson(Map<String, dynamic> json) {
    return IngredientMeta(
      categoryIndex: json['cat'] as int? ?? 22,
      isVegan: json['vegan'] as bool? ?? false,
      isVegetarian: json['vegetarian'] as bool? ?? false,
      allergens: json['allergens'] as String?,
      kcal: json['kcal'] as int?,
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
    );
  }

  /// The "true" category from OpenFoodFacts data (may differ from shopping
  /// aisle category used by classify()).
  IngredientCategory get trueCategory {
    if (categoryIndex < 0 || categoryIndex >= IngredientCategory.values.length) {
      return IngredientCategory.unknown;
    }
    return IngredientCategory.values[categoryIndex];
  }
}

class IngredientService {
  static final IngredientService _instance = IngredientService._internal();
  factory IngredientService() => _instance;
  IngredientService._internal();

  Map<String, int> _lookupMap = {};
  Map<String, IngredientMeta> _metaMap = {};
  List<String> _sortedKeys = [];
  Set<String> _fallbackKeys = {};
  bool _isInitialized = false;
  bool _metaLoaded = false;

  /// Call this once at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load the Gzipped binary from assets
      // Corrected path to match workspace structure
      final ByteData data = await rootBundle.load('assets/ingredients/ingredients_json.gz');
      final List<int> bytes = data.buffer.asUint8List();

      // 2. Decompress and decode JSON
      final decodedBytes = GZipCodec().decode(bytes);
      final String jsonString = utf8.decode(decodedBytes);
      final Map<String, dynamic> rawMap = json.decode(jsonString);
      
      _lookupMap = rawMap.map((key, value) => MapEntry(key, value as int));

      // 3. Pre-sort keys by length (Descending) for "Longest Match Wins"
      // This ensures "coconut milk" (length 12) is checked before "milk" (length 4)
      _sortedKeys = _lookupMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      
      // Inject fallback map for guarantee
      _injectFallbackData();

      _isInitialized = true;
    } catch (e) {
      print("IngredientService Init Error: $e");
      // Fallback: Use manual map
      _injectFallbackData();
      _isInitialized = true;
    }

    // Load metadata (non-blocking, best-effort)
    await _loadMeta();
  }

  /// Loads the rich metadata file (ingredients_meta.gz).
  /// Non-critical — app works fine without it.
  Future<void> _loadMeta() async {
    if (_metaLoaded) return;
    try {
      final ByteData data = await rootBundle.load('assets/ingredients/ingredients_meta.gz');
      final List<int> bytes = data.buffer.asUint8List();
      final decodedBytes = GZipCodec().decode(bytes);
      final String jsonString = utf8.decode(decodedBytes);
      final Map<String, dynamic> rawMap = json.decode(jsonString);

      _metaMap = rawMap.map((key, value) =>
        MapEntry(key, IngredientMeta.fromJson(value as Map<String, dynamic>)));
      _metaLoaded = true;
    } catch (e) {
      // Meta is optional — don't fail init
      print("IngredientService meta load skipped: $e");
    }
  }

  /// Whether rich metadata is available.
  bool get hasMetadata => _metaLoaded;

  /// Look up rich metadata for an ingredient (allergens, nutrition, etc.).
  /// Returns null if meta file not loaded or ingredient not found.
  IngredientMeta? lookupMeta(String input) {
    if (!_metaLoaded) return null;
    final normalized = _normalize(input);
    if (normalized.isEmpty) return null;

    // Exact match first
    if (_metaMap.containsKey(normalized)) return _metaMap[normalized];

    // Substring match (longest key first)
    for (final key in _metaMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length))) {
      if (key.length < 3) continue;
      if (normalized.contains(key)) return _metaMap[key];
    }
    return null;
  }

  void _injectFallbackData() {
    // Authoritative fallback map — always wins over gzip data.
    // This guarantees correct categorization for common ingredients
    // regardless of gzip quality.
    final fallback = <String, int>{
      // Produce
      'onion': IngredientCategory.produce.index,
      'garlic': IngredientCategory.produce.index,
      'apple': IngredientCategory.produce.index,
      'tomato': IngredientCategory.produce.index,
      'potato': IngredientCategory.produce.index,
      'carrot': IngredientCategory.produce.index,
      'celery': IngredientCategory.produce.index,
      'lettuce': IngredientCategory.produce.index,
      'spinach': IngredientCategory.produce.index,
      'broccoli': IngredientCategory.produce.index,
      'cucumber': IngredientCategory.produce.index,
      'bell pepper': IngredientCategory.produce.index,
      'zucchini': IngredientCategory.produce.index,
      'mushroom': IngredientCategory.produce.index,
      'avocado': IngredientCategory.produce.index,
      'lemon': IngredientCategory.produce.index,
      'lime': IngredientCategory.produce.index,
      'orange': IngredientCategory.produce.index,
      'ginger': IngredientCategory.produce.index,
      'scallion': IngredientCategory.produce.index,
      'green onion': IngredientCategory.produce.index,
      'shallot': IngredientCategory.produce.index,
      'jalapeño': IngredientCategory.produce.index,
      'jalapeno': IngredientCategory.produce.index,
      'cilantro': IngredientCategory.produce.index,
      'parsley': IngredientCategory.produce.index,
      'basil': IngredientCategory.produce.index,
      'thyme': IngredientCategory.produce.index,
      'rosemary': IngredientCategory.produce.index,
      'mint': IngredientCategory.produce.index,
      'dill': IngredientCategory.produce.index,
      'cabbage': IngredientCategory.produce.index,
      'kale': IngredientCategory.produce.index,
      'corn': IngredientCategory.produce.index,
      'asparagus': IngredientCategory.produce.index,
      'eggplant': IngredientCategory.produce.index,
      'pea': IngredientCategory.produce.index,
      'green bean': IngredientCategory.produce.index,
      'sweet potato': IngredientCategory.produce.index,
      'banana': IngredientCategory.produce.index,
      'strawberry': IngredientCategory.produce.index,
      'blueberry': IngredientCategory.produce.index,
      'raspberry': IngredientCategory.produce.index,
      'grape': IngredientCategory.produce.index,
      'peach': IngredientCategory.produce.index,
      'pear': IngredientCategory.produce.index,
      'cherry': IngredientCategory.produce.index,
      'plum': IngredientCategory.produce.index,
      'watermelon': IngredientCategory.produce.index,
      'cantaloupe': IngredientCategory.produce.index,
      'mango': IngredientCategory.produce.index,
      'pineapple': IngredientCategory.produce.index,
      // Meat
      'beef': IngredientCategory.meat.index,
      'steak': IngredientCategory.meat.index,
      'ground beef': IngredientCategory.meat.index,
      'pork': IngredientCategory.meat.index,
      'bacon': IngredientCategory.meat.index,
      'ham': IngredientCategory.meat.index,
      'sausage': IngredientCategory.meat.index,
      'lamb': IngredientCategory.meat.index,
      'veal': IngredientCategory.meat.index,
      'prosciutto': IngredientCategory.meat.index,
      'pancetta': IngredientCategory.meat.index,
      'chorizo': IngredientCategory.meat.index,
      // Poultry
      'chicken': IngredientCategory.poultry.index,
      'turkey': IngredientCategory.poultry.index,
      'duck': IngredientCategory.poultry.index,
      'chicken breast': IngredientCategory.poultry.index,
      'chicken thigh': IngredientCategory.poultry.index,
      // Seafood
      'salmon': IngredientCategory.seafood.index,
      'tuna': IngredientCategory.seafood.index,
      'shrimp': IngredientCategory.seafood.index,
      'cod': IngredientCategory.seafood.index,
      'crab': IngredientCategory.seafood.index,
      'lobster': IngredientCategory.seafood.index,
      'scallop': IngredientCategory.seafood.index,
      'mussel': IngredientCategory.seafood.index,
      'clam': IngredientCategory.seafood.index,
      'anchovy': IngredientCategory.seafood.index,
      'fish': IngredientCategory.seafood.index,
      'squid': IngredientCategory.seafood.index,
      // Egg
      'egg': IngredientCategory.egg.index,
      // Cheese
      'cheese': IngredientCategory.cheese.index,
      'cheddar': IngredientCategory.cheese.index,
      'parmesan': IngredientCategory.cheese.index,
      'mozzarella': IngredientCategory.cheese.index,
      'gruyere': IngredientCategory.cheese.index,
      'feta': IngredientCategory.cheese.index,
      'brie': IngredientCategory.cheese.index,
      'gouda': IngredientCategory.cheese.index,
      'ricotta': IngredientCategory.cheese.index,
      'cream cheese': IngredientCategory.cheese.index,
      'goat cheese': IngredientCategory.cheese.index,
      'blue cheese': IngredientCategory.cheese.index,
      'pecorino': IngredientCategory.cheese.index,
      'mascarpone': IngredientCategory.cheese.index,
      // Dairy
      'milk': IngredientCategory.dairy.index,
      'butter': IngredientCategory.dairy.index,
      'cream': IngredientCategory.dairy.index,
      'heavy cream': IngredientCategory.dairy.index,
      'sour cream': IngredientCategory.dairy.index,
      'yogurt': IngredientCategory.dairy.index,
      'buttermilk': IngredientCategory.dairy.index,
      'whipping cream': IngredientCategory.dairy.index,
      'half and half': IngredientCategory.dairy.index,
      // Grain
      'rice': IngredientCategory.grain.index,
      'bread': IngredientCategory.grain.index,
      'oat': IngredientCategory.grain.index,
      'quinoa': IngredientCategory.grain.index,
      'couscous': IngredientCategory.grain.index,
      'barley': IngredientCategory.grain.index,
      'breadcrumb': IngredientCategory.grain.index,
      'panko': IngredientCategory.grain.index,
      'tortilla': IngredientCategory.grain.index,
      // Pasta
      'pasta': IngredientCategory.pasta.index,
      'spaghetti': IngredientCategory.pasta.index,
      'penne': IngredientCategory.pasta.index,
      'linguine': IngredientCategory.pasta.index,
      'fettuccine': IngredientCategory.pasta.index,
      'noodle': IngredientCategory.pasta.index,
      'lasagna': IngredientCategory.pasta.index,
      'macaroni': IngredientCategory.pasta.index,
      // Legume
      'bean': IngredientCategory.legume.index,
      'black bean': IngredientCategory.legume.index,
      'kidney bean': IngredientCategory.legume.index,
      'chickpea': IngredientCategory.legume.index,
      'lentil': IngredientCategory.legume.index,
      'tofu': IngredientCategory.legume.index,
      // Spice
      'salt': IngredientCategory.spice.index,
      'pepper': IngredientCategory.spice.index,
      'black pepper': IngredientCategory.spice.index,
      'white pepper': IngredientCategory.spice.index,
      'cumin': IngredientCategory.spice.index,
      'paprika': IngredientCategory.spice.index,
      'cayenne': IngredientCategory.spice.index,
      'cinnamon': IngredientCategory.spice.index,
      'nutmeg': IngredientCategory.spice.index,
      'oregano': IngredientCategory.spice.index,
      'turmeric': IngredientCategory.spice.index,
      'coriander': IngredientCategory.spice.index,
      'chili powder': IngredientCategory.spice.index,
      'chili flake': IngredientCategory.spice.index,
      'red pepper flake': IngredientCategory.spice.index,
      'bay leaf': IngredientCategory.spice.index,
      'clove': IngredientCategory.spice.index,
      'cardamom': IngredientCategory.spice.index,
      'star anise': IngredientCategory.spice.index,
      'fennel seed': IngredientCategory.spice.index,
      'mustard powder': IngredientCategory.spice.index,
      'allspice': IngredientCategory.spice.index,
      'sage': IngredientCategory.spice.index,
      'tarragon': IngredientCategory.spice.index,
      'curry powder': IngredientCategory.spice.index,
      'garam masala': IngredientCategory.spice.index,
      'italian seasoning': IngredientCategory.spice.index,
      'onion powder': IngredientCategory.spice.index,
      'garlic powder': IngredientCategory.spice.index,
      // Condiment (true condiments — found in the condiment aisle)
      'soy sauce': IngredientCategory.condiment.index,
      'fish sauce': IngredientCategory.condiment.index,
      'worcestershire': IngredientCategory.condiment.index,
      'hot sauce': IngredientCategory.condiment.index,
      'ketchup': IngredientCategory.condiment.index,
      'mustard': IngredientCategory.condiment.index,
      'mayonnaise': IngredientCategory.condiment.index,
      'sriracha': IngredientCategory.condiment.index,
      'hoisin sauce': IngredientCategory.condiment.index,
      'oyster sauce': IngredientCategory.condiment.index,
      'dijon': IngredientCategory.condiment.index,
      'sambal': IngredientCategory.condiment.index,
      'salsa': IngredientCategory.condiment.index,
      'barbecue sauce': IngredientCategory.condiment.index,
      'teriyaki sauce': IngredientCategory.condiment.index,
      // Pantry (jarred, canned, preserved, spreads — store center aisles)
      'tomato paste': IngredientCategory.pantry.index,
      'tomato sauce': IngredientCategory.pantry.index,
      'sun-dried tomato': IngredientCategory.pantry.index,
      'sun dried tomato': IngredientCategory.pantry.index,
      'sundried tomato': IngredientCategory.pantry.index,
      'pickle': IngredientCategory.pantry.index,
      'pickled': IngredientCategory.pantry.index,
      'olive': IngredientCategory.pantry.index,
      'caper': IngredientCategory.pantry.index,
      'artichoke heart': IngredientCategory.pantry.index,
      'roasted pepper': IngredientCategory.pantry.index,
      'roasted red pepper': IngredientCategory.pantry.index,
      'canned tomato': IngredientCategory.pantry.index,
      'diced tomato': IngredientCategory.pantry.index,
      'crushed tomato': IngredientCategory.pantry.index,
      'whole tomato': IngredientCategory.pantry.index,
      'peanut butter': IngredientCategory.pantry.index,
      'almond butter': IngredientCategory.pantry.index,
      'cashew butter': IngredientCategory.pantry.index,
      'nutella': IngredientCategory.pantry.index,
      'miso': IngredientCategory.pantry.index,
      'tahini': IngredientCategory.pantry.index,
      'pesto': IngredientCategory.pantry.index,
      'coconut cream': IngredientCategory.pantry.index,
      'anchovy paste': IngredientCategory.pantry.index,
      'harissa': IngredientCategory.pantry.index,
      'gochujang': IngredientCategory.pantry.index,
      'chipotle': IngredientCategory.pantry.index,
      // Oil
      'oil': IngredientCategory.oil.index,
      'olive oil': IngredientCategory.oil.index,
      'vegetable oil': IngredientCategory.oil.index,
      'canola oil': IngredientCategory.oil.index,
      'sesame oil': IngredientCategory.oil.index,
      'coconut oil': IngredientCategory.oil.index,
      'cooking spray': IngredientCategory.oil.index,
      // Vinegar
      'vinegar': IngredientCategory.vinegar.index,
      'balsamic vinegar': IngredientCategory.vinegar.index,
      'red wine vinegar': IngredientCategory.vinegar.index,
      'white wine vinegar': IngredientCategory.vinegar.index,
      'apple cider vinegar': IngredientCategory.vinegar.index,
      'rice vinegar': IngredientCategory.vinegar.index,
      // Flour
      'flour': IngredientCategory.flour.index,
      'all-purpose flour': IngredientCategory.flour.index,
      'bread flour': IngredientCategory.flour.index,
      'cornstarch': IngredientCategory.flour.index,
      'corn starch': IngredientCategory.flour.index,
      'almond flour': IngredientCategory.flour.index,
      // Sugar
      'sugar': IngredientCategory.sugar.index,
      'brown sugar': IngredientCategory.sugar.index,
      'powdered sugar': IngredientCategory.sugar.index,
      'honey': IngredientCategory.sugar.index,
      'maple syrup': IngredientCategory.sugar.index,
      'molasses': IngredientCategory.sugar.index,
      'corn syrup': IngredientCategory.sugar.index,
      'agave': IngredientCategory.sugar.index,
      'vanilla extract': IngredientCategory.sugar.index,
      'vanilla': IngredientCategory.sugar.index,
      'chocolate': IngredientCategory.sugar.index,
      'cocoa powder': IngredientCategory.sugar.index,
      // Leavening
      'baking powder': IngredientCategory.leavening.index,
      'baking soda': IngredientCategory.leavening.index,
      'yeast': IngredientCategory.leavening.index,
      'gelatin': IngredientCategory.leavening.index,
      // Nut
      'almond': IngredientCategory.nut.index,
      'walnut': IngredientCategory.nut.index,
      'pecan': IngredientCategory.nut.index,
      'cashew': IngredientCategory.nut.index,
      'pistachio': IngredientCategory.nut.index,
      'peanut': IngredientCategory.nut.index,
      'pine nut': IngredientCategory.nut.index,
      'hazelnut': IngredientCategory.nut.index,
      'coconut': IngredientCategory.nut.index,
      'coconut milk': IngredientCategory.pantry.index,
      'sesame seed': IngredientCategory.nut.index,
      // Alcohol
      'wine': IngredientCategory.alcohol.index,
      'red wine': IngredientCategory.alcohol.index,
      'white wine': IngredientCategory.alcohol.index,
      'beer': IngredientCategory.alcohol.index,
      'brandy': IngredientCategory.alcohol.index,
      'rum': IngredientCategory.alcohol.index,
      'vodka': IngredientCategory.alcohol.index,
      'whiskey': IngredientCategory.alcohol.index,
      'bourbon': IngredientCategory.alcohol.index,
      'sake': IngredientCategory.alcohol.index,
      'sherry': IngredientCategory.alcohol.index,
      'port': IngredientCategory.alcohol.index,
      'marsala': IngredientCategory.alcohol.index,
      'mirin': IngredientCategory.alcohol.index,
      'kahlua': IngredientCategory.alcohol.index,
      'tequila': IngredientCategory.alcohol.index,
      'gin': IngredientCategory.alcohol.index,
      'cognac': IngredientCategory.alcohol.index,
      // Juice
      'lemon juice': IngredientCategory.juice.index,
      'lime juice': IngredientCategory.juice.index,
      'orange juice': IngredientCategory.juice.index,
      // Beverage
      'coffee': IngredientCategory.beverage.index,
      'tea': IngredientCategory.beverage.index,
      'broth': IngredientCategory.beverage.index,
      'stock': IngredientCategory.beverage.index,
      'chicken broth': IngredientCategory.beverage.index,
      'chicken stock': IngredientCategory.beverage.index,
      'beef broth': IngredientCategory.beverage.index,
      'vegetable broth': IngredientCategory.beverage.index,
      'water': IngredientCategory.beverage.index,
    };
    
    // Fallback always wins — overwrite unconditionally
    fallback.forEach((k, v) {
      _lookupMap[k] = v;
    });
    
    // Track which keys came from the authoritative fallback
    _fallbackKeys = fallback.keys.toSet();

    // Re-sort keys by length descending for longest-match-first
    _sortedKeys = _lookupMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Classifies a recipe ingredient line.
  IngredientCategory classify(String input) {
    if (!_isInitialized || input.isEmpty) return IngredientCategory.unknown;

    final normalized = _normalize(input);
    if (normalized.isEmpty) return IngredientCategory.unknown;

    // Step 1: Exact match on the full normalized string
    if (_lookupMap.containsKey(normalized)) {
      final idx = _lookupMap[normalized]!;
      // Trust exact matches from gzip ONLY if they are non-produce (index > 0)
      // or are in the fallback map (which always overwrites).
      // Produce (0) from gzip is unreliable because the OFF script defaulted
      // everything uncategorised to produce.
      if (idx != 0) {
        return _indexToCategory(idx);
      }
      // For idx == 0, check if this key exists in the fallback (authoritative).
      // Fallback always overwrites, so if it's still 0 here, it means the
      // fallback intentionally set it to produce — trust it.
      if (_fallbackKeys.contains(normalized)) {
        return IngredientCategory.produce;
      }
      // Otherwise idx 0 came from gzip — unreliable, continue searching
    }

    // Step 2: Greedy Substring Match (longest key first)
    // Minimum key length of 3 to prevent false matches like "za" from "pizza"
    for (final key in _sortedKeys) {
      if (key.length < 3) continue;
      if (normalized.contains(key)) {
        final idx = _lookupMap[key]!;
        // Same produce-skepticism: skip gzip-sourced produce
        if (idx == 0 && !_fallbackKeys.contains(key)) continue;
        return _indexToCategory(idx);
      }
    }

    return IngredientCategory.unknown;
  }

  /// Normalizes input to isolate core ingredient name
  /// Useful for deduplication in shopping lists
  String normalize(String input) {
    return _normalize(input);
  }

  /// Internal normalization logic
  String _normalize(String input) {
    var result = input.toLowerCase().trim();
    
    // Remove quantities and common measurement units
    result = result.replaceAll(RegExp(r'\b(\d+|cups?|tbsps?|tsps?|oz|grams?|kg|ml|l|lb|units?|pinch|handful|dash)\b'), '');
    
    // Remove common recipe adjectives that aren't part of the ingredient identity
    // Negative lookbehind (?<!-) protects compound words like "sun-dried"
    result = result.replaceAll(RegExp(r'(?<!-)\b(organic|fresh|diced|chopped|sliced|frozen|dried|cold|pressed|extra|virgin|large|small|minced|ground|whole|crushed|roasted|toasted|raw|cooked|boneless|skinless|thick|thin|finely|roughly|coarsely)\b'), '');
    
    // Proper plural handling (order matters)
    // "cherries" -> "cherry", "berries" -> "berry"
    result = result.replaceAll(RegExp(r'ies$'), 'y');
    // "tomatoes" -> "tomato", "potatoes" -> "potato"
    result = result.replaceAll(RegExp(r'oes$'), 'o');
    // "cheeses" -> "cheese", "sauces" -> "sauce"
    result = result.replaceAll(RegExp(r'ses$'), 'se');
    // "leaves" -> "leaf" (special case)
    result = result.replaceAll(RegExp(r'ves$'), 'f');
    // General: "onions" -> "onion", "peppers" -> "pepper"
    // But NOT words ending in 'ss' (e.g. "grass"), 'us', 'is'
    result = result.replaceAll(RegExp(r'(?<![sui])s$'), '');
    
    // Collapse whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return result;
  }

  IngredientCategory _indexToCategory(int index) {
    if (index < 0 || index >= IngredientCategory.values.length) {
      return IngredientCategory.unknown;
    }
    return IngredientCategory.values[index];
  }
}
