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
      final ByteData data = await rootBundle.load('assets/ingredients.json.gz');
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

      _isInitialized = true;
    } catch (e) {
      print("IngredientService Init Error: $e");
    }
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
  String _normalize(String input) {
    return input.toLowerCase()
        .trim()
        // Remove quantities and common measurement units
        .replaceAll(RegExp(r'\b(\d+|cups?|tbsps?|tsps?|oz|grams?|kg|ml|l|lb|units?|pinch|handful|dash)\b'), '')
        // Remove common recipe adjectives that aren't part of the ingredient identity
        .replaceAll(RegExp(r'\b(organic|fresh|diced|chopped|sliced|frozen|dried|cold|pressed|extra|virgin|large|small|minced)\b'), '')
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
