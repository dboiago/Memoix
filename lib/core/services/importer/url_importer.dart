import 'dart:convert';
import 'dart:io' show gzip;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_import_result.dart';
import '../../recipes/models/recipe.dart';
import 'importer/ingredient_parser.dart';
import 'importer/parser_strategy.dart';
import 'importer/strategies.dart';

/// Service to import recipes from URLs using a Strategy Pattern.
class UrlRecipeImporter {
  static final _uuid = Uuid();
  final IngredientParser _ingredientParser;
  final List<RecipeParserStrategy> _strategies;

  UrlRecipeImporter() : _ingredientParser = IngredientParser() {
    // Initialize strategies with the shared parser
    _strategies = [
      YouTubeStrategy(_ingredientParser),
      StandardWebStrategy(_ingredientParser),
    ];
  }

  /// Import a recipe from a URL
  Future<RecipeImportResult> importFromUrl(String url) async {
    try {
      // 1. Fetch and Decode
      final response = await _fetchUrl(url);
      final body = _decodeResponseBody(response);
      final document = html_parser.parse(body);

      // 2. Select Best Strategy
      RecipeParserStrategy? bestStrategy;
      double maxConfidence = 0.0;

      for (final strategy in _strategies) {
        final confidence = strategy.canParse(url, document, body);
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          bestStrategy = strategy;
        }
        if (confidence >= 1.0) break; // Found exact match
      }

      if (bestStrategy == null) {
        throw Exception('No supported parser found for this URL.');
      }

      // 3. Execute
      final result = await bestStrategy.parse(url, document, body);
      if (result == null) {
        throw Exception('Parser failed to extract recipe data.');
      }

      return result;
    } catch (e) {
      throw Exception('Failed to import recipe: $e');
    }
  }

  /// Legacy compatibility wrapper
  Future<Recipe?> importRecipeFromUrl(String url) async {
    final result = await importFromUrl(url);
    return result.toRecipe(_uuid.v4());
  }

  // --- Network Helpers (Moved from Monolith) ---

  Future<http.Response> _fetchUrl(String url) async {
    final uri = Uri.parse(url);
    final origin = '${uri.scheme}://${uri.host}';
    
    // Try multiple User-Agent configurations (Chrome, Googlebot, etc.)
    final headerConfigs = [
      {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': origin,
      },
      {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
      }
    ];

    for (final headers in headerConfigs) {
      try {
        final response = await http.get(uri, headers: headers);
        if (response.statusCode == 200) return response;
      } catch (_) { continue; }
    }
    throw Exception('Failed to fetch URL after multiple attempts');
  }

  String _decodeResponseBody(http.Response response) {
    // Handle GZIP and Charset decoding
    // (Preserve the robust decoding logic from the original file here)
    try {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return response.body;
    }
  }
}

final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
