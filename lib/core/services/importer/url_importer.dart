import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/recipe_import_result.dart';
import '../../recipes/models/recipe.dart';
// Import your strategies and util
import 'importer/ingredient_parser.dart';
import 'importer/strategies/youtube_strategy.dart';
import 'importer/strategies/json_ld_strategy.dart';
import 'importer/strategies/html_fallback_strategy.dart';

class UrlRecipeImporter {
  final IngredientParser _ingredientParser;
  final List<RecipeParserStrategy> _strategies;

  UrlRecipeImporter({IngredientParser? ingredientParser}) 
      : _ingredientParser = ingredientParser ?? IngredientParser(),
        _strategies = [
          YouTubeStrategy(),      // Specific: Checks URL pattern
          JsonLdStrategy(),       // Generic: Checks for <script type="ld+json">
          HtmlFallbackStrategy(), // Fallback: Scrapes DOM
        ];

  /// The main entry point called by the UI
  Future<RecipeImportResult> importFromUrl(String url) async {
    // 1. Fetch Data (Network Logic)
    final response = await _fetchUrl(url); // Extracted fetch logic
    final body = response.body; // Handle decoding here
    final document = html_parser.parse(body);

    // 2. Select Strategy
    RecipeParserStrategy? bestStrategy;
    double highScore = 0.0;

    for (final strategy in _strategies) {
      final score = strategy.canParse(url, document, body);
      if (score == 1.0) {
        // Perfect match, stop searching
        bestStrategy = strategy;
        break;
      } else if (score > highScore) {
        highScore = score;
        bestStrategy = strategy;
      }
    }

    if (bestStrategy == null || highScore == 0.0) {
      throw Exception('No valid recipe data found.');
    }

    // 3. Execute Strategy
    final result = await bestStrategy.parse(url, document, body);
    
    if (result == null) throw Exception('Parser failed to extract data.');
    
    return result;
  }

  /// Centralized HTTP fetching logic
  Future<http.Response> _fetchUrl(String url) async {
    // ... [Insert the User-Agent rotation logic from original file here] ...
    // This keeps the networking noise out of the parsing logic.
    return http.get(Uri.parse(url)); 
  }

  // Legacy support wrapper
  Future<Recipe?> importRecipeFromUrl(String url) async {
     final result = await importFromUrl(url);
     return result.toRecipe(Uuid().v4());
  }
}

// Provider
final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
