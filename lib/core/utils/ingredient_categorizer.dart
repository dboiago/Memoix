import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

enum IngredientCategory {
  produce, meat, poultry, seafood, egg, cheese, dairy,
  grain, pasta, legume, nut, spice, condiment, oil,
  vinegar, flour, sugar, leavening, alcohol, pop, juice, beverage, unknown
}

class IngredientService {
  static final IngredientService _instance = IngredientService._internal();
  factory IngredientService() => _instance;
  IngredientService._internal();

  Map<String, int> _lookupMap = {};
  List<String> _sortedKeys = [];
  bool _isInitialized = false;

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
  }

  void _injectFallbackData() {
    // Basic fallback map to ensure key ingredients work even if asset is bad
    final fallback = {
      'onion': IngredientCategory.produce.index,
      'bacon': IngredientCategory.meat.index,
      'garlic': IngredientCategory.produce.index,
      'apple': IngredientCategory.produce.index,
      'chicken': IngredientCategory.poultry.index,
      'beef': IngredientCategory.meat.index,
      'pork': IngredientCategory.meat.index,
      'salmon': IngredientCategory.seafood.index,
      'tuna': IngredientCategory.seafood.index,
      'shrimp': IngredientCategory.seafood.index,
      'milk': IngredientCategory.dairy.index,
      'cheese': IngredientCategory.cheese.index,
      'cheddar': IngredientCategory.cheese.index,
      'parmesan': IngredientCategory.cheese.index,
      'mozzarella': IngredientCategory.cheese.index,
      'egg': IngredientCategory.egg.index,
      'eggs': IngredientCategory.egg.index,
      'flour': IngredientCategory.flour.index,
      'sugar': IngredientCategory.sugar.index,
      'salt': IngredientCategory.spice.index,
      'pepper': IngredientCategory.spice.index,
      'oil': IngredientCategory.oil.index,
      'olive oil': IngredientCategory.oil.index,
      'vinegar': IngredientCategory.vinegar.index,
      'butter': IngredientCategory.dairy.index,
      'cream': IngredientCategory.dairy.index,
      'yogurt': IngredientCategory.dairy.index,
      'rice': IngredientCategory.grain.index,
      'pasta': IngredientCategory.pasta.index,
      'bread': IngredientCategory.grain.index,
      'tomato': IngredientCategory.produce.index,
      'potato': IngredientCategory.produce.index,
      'carrot': IngredientCategory.produce.index,
      'lettuce': IngredientCategory.produce.index,
      'steak': IngredientCategory.meat.index,
      'ground beef': IngredientCategory.meat.index,
    };
    
    fallback.forEach((k, v) {
      if (!_lookupMap.containsKey(k) || _lookupMap[k] == 0) {
         // Overwrite if 0 (Assume 0 is sketchy unless it's produce) 
         // Actually, produce IS index 0. 
         // But "beef" being 0 is wrong.
         // So we prioritize our fallback map.
         _lookupMap[k] = v;
      }
    });

    // Re-sort keys
    _sortedKeys = _lookupMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Classifies a recipe ingredient line.
  IngredientCategory classify(String input) {
    if (!_isInitialized || input.isEmpty) return IngredientCategory.unknown;

    final normalized = _normalize(input);

    // Step 1: Exact Match (Fastest)
    if (_lookupMap.containsKey(normalized)) {
      return _indexToCategory(_lookupMap[normalized]!);
    }

    // Step 2: Greedy Substring Match
    // We iterate through keys starting from the longest strings.
    for (final key in _sortedKeys) {
      if (normalized.contains(key)) {
        return _indexToCategory(_lookupMap[key]!);
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
    return input.toLowerCase()
        .trim()
        // Remove quantities and common measurement units
        .replaceAll(RegExp(r'\b(\d+|cups?|tbsps?|tsps?|oz|grams?|kg|ml|l|lb|units?|pinch|handful|dash)\b'), '')
        // Remove common recipe adjectives that aren't part of the ingredient identity
        // Added negative lookbehind (?<!-) to protect compound words like "sun-dried"
        .replaceAll(RegExp(r'(?<!-)\b(organic|fresh|diced|chopped|sliced|frozen|dried|cold|pressed|extra|virgin|large|small|minced)\b'), '')
        // Simple plural handling
        .replaceAll(RegExp(r's$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  IngredientCategory _indexToCategory(int index) {
    if (index < 0 || index >= IngredientCategory.values.length) {
      return IngredientCategory.unknown;
    }
    return IngredientCategory.values[index];
  }
}
