import 'dart:convert';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/recipe_import_result.dart';
import '../../../features/recipes/models/recipe.dart'; // Adjust path to Recipe model
import 'parser_strategy.dart';
import 'ingredient_parser.dart';

// --- YouTube Strategy ---

class YouTubeStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  YouTubeStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
      return 1.0; // High confidence for YouTube URLs
    }
    return 0.0;
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    // Extract Video ID
    final uri = Uri.parse(url);
    String? videoId = uri.queryParameters['v'];
    if (videoId == null && uri.host == 'youtu.be') {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (videoId == null) throw Exception('Could not extract YouTube Video ID');

    // ... [Insert the _importFromYouTube logic from original file here] ...
    // Note: Use _ingParser.parseList() instead of local parsing logic
    
    // Returning dummy result for brevity of example - replace with full logic
    return RecipeImportResult(
      name: "YouTube Recipe",
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: [], 
      directions: [],
    );
  }
}

// --- Standard Web Strategy (JSON-LD + HTML Fallback) ---

class StandardWebStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  StandardWebStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    // We can attempt to parse almost any HTML page
    return 0.5; 
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    if (document == null) return null;

    // 1. Try JSON-LD
    final jsonLdResult = _parseJsonLd(document, url);
    if (jsonLdResult != null) {
      // 2. Enrich JSON-LD with HTML data (Equipment, Glass, etc.)
      return _enrichJsonLdWithHtml(jsonLdResult, document);
    }

    // 3. Fallback to pure HTML scraping
    return _parseHtmlFallback(document, url);
  }

  RecipeImportResult? _parseJsonLd(Document document, String url) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    
    for (final script in scripts) {
      try {
        final data = jsonDecode(script.text);
        // ... [Insert logic to validate @type=Recipe and extract fields] ...
        
        // Use the shared parser
        // final ingredients = _ingParser.parseList(rawIngredients);

        // Placeholder return
        return RecipeImportResult(
          name: data['name'] ?? 'Untitled', 
          source: RecipeSource.url, 
          sourceUrl: url,
          ingredients: [], 
          directions: [],
        );
      } catch (_) { continue; }
    }
    return null;
  }

  RecipeImportResult _enrichJsonLdWithHtml(RecipeImportResult result, Document document) {
    // ... [Insert logic that checks for missing equipment/glass in result and scrapes HTML] ...
    return result;
  }

  RecipeImportResult? _parseHtmlFallback(Document document, String url) {
    // ... [Insert logic from _parseFromHtmlWithConfidence] ...
    return null;
  }
}
