import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/import/models/recipe_import_result.dart';
import '../../features/recipes/models/recipe.dart';
import 'importer/ingredient_parser.dart';
import 'importer/recipe_parser_strategy.dart';
import 'importer/strategies.dart';

class UrlRecipeImporter {
  static final _uuid = Uuid();
  final IngredientParser _ingredientParser;
  late final List<RecipeParserStrategy> _strategies;
  final http.Client _client;

  /// Optional client injection for testing
  UrlRecipeImporter({http.Client? client}) 
      : _client = client ?? http.Client(), 
        _ingredientParser = IngredientParser() {
    _strategies = [
      YouTubeStrategy(_ingredientParser),
      SquarespaceRecipeStrategy(_ingredientParser),
      StandardWebStrategy(_ingredientParser),
    ];
  }

  Future<RecipeImportResult> importFromUrl(String url) async {
    try {
      final response = await _fetchUrl(url);
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = html_parser.parse(body);

      RecipeParserStrategy? bestStrategy;
      double maxConfidence = 0.0;

      for (final strategy in _strategies) {
        final confidence = strategy.canParse(url, document, body);
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          bestStrategy = strategy;
        }
        if (confidence >= 1.0) break;
      }

      if (bestStrategy == null) {
        throw Exception('No supported parser found for this URL.');
      }

      final result = await bestStrategy.parse(url, document, body);
      if (result == null) {
        throw Exception('Parser failed to extract recipe data.');
      }

      return result;
    } catch (e) {
      throw Exception('Failed to import recipe: $e');
    }
  }

  Future<Recipe?> importRecipeFromUrl(String url) async {
    final result = await importFromUrl(url);
    return result.toRecipe(_uuid.v4());
  }

  Future<http.Response> _fetchUrl(String url) async {
    final uri = Uri.parse(url);
    final origin = '${uri.scheme}://${uri.host}';
    
    // Multiple header configurations to bypass bot protection
    final headerConfigs = [
      // Config 1: Standard Chrome browser headers with all Sec-* headers
      {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
        'Referer': origin,
        'Origin': origin,
        'Sec-Ch-Ua': '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-User': '?1',
        'Upgrade-Insecure-Requests': '1',
        'Cache-Control': 'max-age=0',
        'Connection': 'keep-alive',
      },
      // Config 2: Googlebot (many sites serve pre-rendered HTML for SEO crawlers)
      {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
      },
      // Config 3: Mobile Safari (some sites have better mobile versions)
      {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
      },
      // Config 4: Firefox with minimal headers
      {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'identity',
      },
      // Config 5: Bare minimum headers (last resort)
      {
        'User-Agent': 'Mozilla/5.0',
        'Accept': '*/*',
      },
    ];

    http.Response? response;
    String? lastError;

    for (final headers in headerConfigs) {
      try {
        response = await _client.get(uri, headers: headers).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Request timeout'),
        );
        if (response.statusCode == 200) return response;
        lastError = 'HTTP ${response.statusCode}';
      } on http.ClientException catch (e) {
        // Handle HTTP protocol mismatch errors (HTTP/2 vs HTTP/1.1)
        // This happens with sites like delish.com that require HTTP/2
        lastError = 'HTTP protocol error: $e';
        continue;
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    throw Exception('Failed to fetch URL after multiple attempts: $lastError');
  }
}

final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
