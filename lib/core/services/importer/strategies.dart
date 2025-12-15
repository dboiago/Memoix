import 'dart:convert';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/recipe_import_result.dart';
import '../../../features/recipes/models/recipe.dart';
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
      return 1.0;
    }
    return 0.0;
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    final videoId = _extractYouTubeVideoId(url);
    if (videoId == null) throw Exception('Could not extract YouTube Video ID');

    final response = await http.get(
      Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    
    final body = response.body;
    
    // Extract metadata
    String title = 'YouTube Recipe';
    final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(body);
    if (titleMatch != null) {
       title = _decodeUnicodeEscapes(titleMatch.group(1) ?? '');
    }

    String description = '';
    final descMatch = RegExp(r'"shortDescription":\s*"((?:[^"\\]|\\.)*)"').firstMatch(body);
    if (descMatch != null) {
      description = _decodeUnicodeEscapes(descMatch.group(1) ?? '');
    }

    // Parse Description for Ingredients
    final parsedDesc = _parseYouTubeDescription(description);
    final rawIngredients = (parsedDesc['ingredients'] as List<String>? ?? []);
    final ingredients = _ingParser.parseList(rawIngredients);

    // Extract Chapters/Directions
    List<String> directions = parsedDesc['directions'] ?? [];
    if (directions.isEmpty) {
       // Fallback: try to find chapters in description
       final chapters = _extractYouTubeChapters(description);
       if (chapters.isNotEmpty) {
         directions = chapters.map((c) => c.title).toList();
       }
    }

    return RecipeImportResult(
      name: _cleanYouTubeTitle(title),
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: ingredients,
      directions: directions,
      notes: parsedDesc['notes'],
      time: parsedDesc['totalTime'],
      imageUrl: 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
    );
  }

  String? _extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    if (uri.host == 'youtu.be') return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return null;
  }

  String _cleanYouTubeTitle(String title) {
    var cleaned = title;
    final patterns = [
      RegExp(r'\s*[|\-–—]\s*YouTube\s*$', caseSensitive: false),
      RegExp(r'\s*\|\s*[^|]+$'),
      RegExp(r'^\s*(?:How\s+to\s+(?:Make|Cook|Prepare)\s+)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    return cleaned.trim();
  }

  Map<String, dynamic> _parseYouTubeDescription(String description) {
    final result = <String, dynamic>{'ingredients': <String>[], 'directions': <String>[], 'notes': null};
    if (description.isEmpty) return result;

    final lines = description.split('\n');
    String? currentSection;
    final ingredients = <String>[];
    final directions = <String>[];
    final notes = <String>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      final lower = line.toLowerCase();
      if (RegExp(r'^(ingredients?|shopping list)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'ingredients'; continue;
      } else if (RegExp(r'^(directions?|instructions?|method)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'directions'; continue;
      } else if (RegExp(r'^(notes?)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'notes'; continue;
      }

      // Check specific timestamp lines and skip
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(line)) continue;

      if (currentSection == 'ingredients') ingredients.add(line);
      else if (currentSection == 'directions') directions.add(line);
      else if (currentSection == 'notes') notes.add(line);
      else {
        // Auto-detect if we haven't hit a header yet
        if (RegExp(r'\d+\s*(?:cup|tbsp|tsp|g|oz)').hasMatch(lower)) {
          currentSection = 'ingredients';
          ingredients.add(line);
        }
      }
    }
    result['ingredients'] = ingredients;
    result['directions'] = directions;
    if (notes.isNotEmpty) result['notes'] = notes.join('\n');
    return result;
  }

  List<({String title})> _extractYouTubeChapters(String description) {
    final chapters = <({String title})>[];
    final lines = description.split('\n');
    for (var line in lines) {
      final match = RegExp(r'(\d{1,2}:\d{2})\s+(.+)').firstMatch(line.trim());
      if (match != null) {
        chapters.add((title: match.group(2)!.trim()));
      }
    }
    return chapters;
  }

  String _decodeUnicodeEscapes(String text) {
    return text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    }).replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
  }
}

// --- Standard Web Strategy ---

class StandardWebStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  StandardWebStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    return 0.5; // Default fallback
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    if (document == null) return null;

    // 1. JSON-LD
    final jsonLdResult = _parseJsonLd(document, url);
    if (jsonLdResult != null) return jsonLdResult;

    // 2. HTML Scraping
    return _parseHtmlFallback(document, url);
  }

  RecipeImportResult? _parseJsonLd(Document document, String url) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        final data = jsonDecode(script.text);
        // Handle graph or direct object
        dynamic recipeData = data;
        if (data is Map && data['@graph'] is List) {
           recipeData = (data['@graph'] as List).firstWhere(
             (e) => e['@type'] == 'Recipe' || (e['@type'] is List && e['@type'].contains('Recipe')),
             orElse: () => null
           );
        } else if (data is List) {
           recipeData = data.firstWhere((e) => e['@type'] == 'Recipe', orElse: () => null);
        }
        
        if (recipeData == null || recipeData['@type'] != 'Recipe') continue;

        // Extract fields
        final name = recipeData['name'];
        final rawIngs = _extractRawList(recipeData['recipeIngredient'] ?? recipeData['ingredients']);
        final rawDirs = _extractRawList(recipeData['recipeInstructions'] ?? recipeData['instructions']);

        return RecipeImportResult(
          name: name is String ? _ingParser.decodeHtml(name) : 'Untitled',
          source: RecipeSource.url,
          sourceUrl: url,
          ingredients: _ingParser.parseList(rawIngs),
          directions: rawDirs, // Keep raw for now, or normalize
          imageUrl: _parseImage(recipeData['image']),
          serves: _parseString(recipeData['recipeYield']),
        );
      } catch (_) { continue; }
    }
    return null;
  }

  RecipeImportResult? _parseHtmlFallback(Document document, String url) {
    // Basic selector based scraping
    final title = document.querySelector('h1')?.text.trim() ?? 'Untitled Recipe';
    
    // Try standard selectors for ingredients
    final ingSelectors = ['.ingredients li', '.ingredient-list li', '[itemprop="recipeIngredient"]'];
    List<String> rawIngs = [];
    
    for (final selector in ingSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        rawIngs = elements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
        break;
      }
    }

    // Try standard selectors for directions
    final dirSelectors = ['.instructions li', '.directions li', '[itemprop="recipeInstructions"] li'];
    List<String> directions = [];
    
    for (final selector in dirSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        directions = elements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
        break;
      }
    }

    if (rawIngs.isEmpty && directions.isEmpty) return null;

    return RecipeImportResult(
      name: title,
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: _ingParser.parseList(rawIngs),
      directions: directions,
      imageUrl: document.querySelector('meta[property="og:image"]')?.attributes['content'],
    );
  }

  List<String> _extractRawList(dynamic data) {
    if (data == null) return [];
    if (data is String) return [data];
    if (data is List) {
      return data.map((e) {
        if (e is String) return e;
        if (e is Map && e['text'] != null) return e['text'].toString(); // Schema.org step
        if (e is Map && e['name'] != null) return e['name'].toString(); 
        return e.toString();
      }).toList();
    }
    return [];
  }

  String? _parseImage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is List && data.isNotEmpty) return _parseImage(data.first);
    if (data is Map) return data['url'] as String?;
    return null;
  }
  
  String? _parseString(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is List && data.isNotEmpty) return data.first.toString();
    return data.toString();
  }
}
