import 'dart:convert';
import 'dart:io' show gzip;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/spirit.dart';
import '../models/recipe_import_result.dart';

/// Helper class for YouTube chapters
class YouTubeChapter {
  final String title;
  final int startSeconds;
  
  YouTubeChapter({required this.title, required this.startSeconds});
}

/// Helper class for transcript segments with timestamps
class TranscriptSegment {
  final String text;
  final double startSeconds;
  
  TranscriptSegment({required this.text, required this.startSeconds});
}

/// Service to import recipes from URLs
class UrlRecipeImporter {
  static final _uuid = Uuid();

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
    'seedlipdrinks.com',
    'lyres.com',
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

  /// Import a recipe from a URL
  /// Supports JSON-LD schema.org Recipe format, common recipe sites, and YouTube videos
  /// Returns RecipeImportResult with confidence scores for user review
  Future<RecipeImportResult> importFromUrl(String url) async {
    try {
      // Check if this is a YouTube video
      final videoId = _extractYouTubeVideoId(url);
      if (videoId != null) {
        return await _importFromYouTube(videoId, url);
      }
      
      // Parse the URL to get the host for Referer header
      final uri = Uri.parse(url);
      final origin = '${uri.scheme}://${uri.host}';
      
      // Helper function to attempt fetch with given headers
      Future<http.Response> tryFetch(Map<String, String> headers) async {
        return await http.get(Uri.parse(url), headers: headers);
      }
      
      // List of header configurations to try in order
      final headerConfigs = [
        // Config 1: Standard Chrome browser headers
        {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity', // No compression - safest option
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
        // Config 2: Googlebot (sites allow crawlers)
        {
          'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity',
        },
        // Config 3: Mobile Safari
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
        // Config 5: Bare minimum headers
        {
          'User-Agent': 'Mozilla/5.0',
          'Accept': '*/*',
        },
      ];
      
      http.Response? response;
      String? lastError;
      
      // Try each configuration until one works
      for (final headers in headerConfigs) {
        try {
          response = await tryFetch(headers);
          if (response.statusCode == 200) {
            break; // Success!
          }
          lastError = 'HTTP ${response.statusCode}';
        } catch (e) {
          // ClientException or other HTTP errors - try next config
          lastError = e.toString();
          response = null;
          continue;
        }
      }
      
      if (response == null || response.statusCode != 200) {
        throw Exception('Failed to fetch URL: ${lastError ?? "unknown error"}');
      }

      // Decode response body - handle encoding errors gracefully
      String body = _decodeResponseBody(response);
      var document = html_parser.parse(body);
      
      // Check if we got a JavaScript shell (no real content)
      final hasRealContent = document.querySelector('title')?.text?.isNotEmpty == true ||
          document.querySelectorAll('h1, h2, h3').isNotEmpty ||
          document.querySelector('[itemtype*="Recipe"]') != null ||
          document.querySelectorAll('script[type="application/ld+json"]').isNotEmpty;
      
      // If no real content, retry with Googlebot user-agent (many sites serve pre-rendered HTML for SEO)
      if (!hasRealContent) {
        response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        );
        
        if (response.statusCode == 200) {
          body = _decodeResponseBody(response);
          document = html_parser.parse(body);
        }
      }

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      RecipeImportResult? jsonLdResult;
      
      for (final script in jsonLdScripts) {
        try {
          // Handle potential encoding issues in JSON-LD script content
          final String scriptText = script.text;
          // If decoding fails, try to fix common encoding issues
          try {
            final data = jsonDecode(scriptText);
            jsonLdResult = _parseJsonLdWithConfidence(data, url);
            if (jsonLdResult != null) break;
          } on FormatException {
            // If JSON decode fails due to encoding, try to re-encode
            try {
              // Re-encode as UTF-8 bytes and decode again
              final bytes = utf8.encode(scriptText);
              final fixed = utf8.decode(bytes, allowMalformed: true);
              final data = jsonDecode(fixed);
              jsonLdResult = _parseJsonLdWithConfidence(data, url);
              if (jsonLdResult != null) break;
            } catch (_) {
              // Skip this script if we can't fix it
              continue;
            }
          }
        } catch (_) {
          continue;
        }
      }
      
      // If JSON-LD found a result, check if we need to supplement with equipment or sections from HTML
      if (jsonLdResult != null) {
        // Check if HTML has ingredient sections that JSON-LD is missing
        // This handles sites like AmazingFoodMadeEasy where JSON-LD has flat ingredient list
        // but HTML has section headers (ingredient_dish_header, li.category, etc.)
        final hasHtmlSections = document.querySelector('.ingredient_dish_header') != null ||
                                document.querySelector('li.category') != null ||
                                document.querySelector('.ingredient-group-header') != null ||
                                document.querySelector('.wprm-recipe-group-name') != null ||
                                document.querySelector('.ingredients__section .ingredient-section-name') != null || // Tasty.co
                                document.querySelector('[class*="ingredientgroup_name"]') != null || // NYT Cooking
                                document.querySelector('.structured-ingredients__list-heading') != null || // Serious Eats
                                document.querySelector('.ingredient-section') != null; // King Arthur Baking
        
        if (hasHtmlSections) {
          // Re-parse with HTML to get section headers
          // Fall through to HTML parsing below instead of returning JSON-LD result
          // We'll use JSON-LD for other metadata but get ingredients from HTML
          final htmlIngredients = _extractIngredientsWithSections(document);
          if (htmlIngredients.isNotEmpty) {
            // Parse the raw ingredient strings to Ingredient objects with sections
            final ingredients = _parseIngredients(htmlIngredients);
            
            // Return combined result: ingredients from HTML (with sections), rest from JSON-LD
            // Also get equipment from HTML
            final sectionResult = _parseHtmlBySections(document);
            final htmlEquipment = sectionResult['equipment'] as List<String>? ?? [];
            
            return RecipeImportResult(
              name: jsonLdResult.name,
              course: jsonLdResult.course,
              cuisine: jsonLdResult.cuisine,
              subcategory: jsonLdResult.subcategory,
              serves: jsonLdResult.serves,
              time: jsonLdResult.time,
              ingredients: ingredients,
              directions: jsonLdResult.directions,
              notes: jsonLdResult.notes,
              imageUrl: jsonLdResult.imageUrl,
              nutrition: jsonLdResult.nutrition,
              equipment: htmlEquipment.isNotEmpty ? htmlEquipment : jsonLdResult.equipment,
              rawIngredients: htmlIngredients.map((raw) {
                final parsed = _parseIngredientString(raw);
                // Clean the fallback raw string by removing footnote markers (*, †, [1], etc.)
                final cleanedRaw = raw.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
                return RawIngredientData(
                  original: raw,
                  amount: parsed.amount,
                  unit: parsed.unit,
                  preparation: parsed.preparation,
                  name: parsed.name.isNotEmpty ? parsed.name : cleanedRaw,
                  looksLikeIngredient: parsed.name.isNotEmpty,
                  isSection: parsed.section != null,
                  sectionName: parsed.section,
                );
              }).toList(),
              rawDirections: jsonLdResult.rawDirections,
              detectedCourses: jsonLdResult.detectedCourses,
              detectedCuisines: jsonLdResult.detectedCuisines,
              nameConfidence: jsonLdResult.nameConfidence,
              courseConfidence: jsonLdResult.courseConfidence,
              cuisineConfidence: jsonLdResult.cuisineConfidence,
              ingredientsConfidence: jsonLdResult.ingredientsConfidence,
              directionsConfidence: jsonLdResult.directionsConfidence,
              servesConfidence: jsonLdResult.servesConfidence,
              timeConfidence: jsonLdResult.timeConfidence,
              sourceUrl: jsonLdResult.sourceUrl,
              source: jsonLdResult.source,
              imagePaths: jsonLdResult.imagePaths,
            );
          }
        }
        
        // Always try to supplement JSON-LD with glass/garnish from HTML (for drink recipes)
        // and equipment/directions if missing. These aren't standard Schema.org Recipe properties.
        final sectionResult = _parseHtmlBySections(document);
        final htmlEquipment = sectionResult['equipment'] as List<String>? ?? [];
        final htmlGlass = sectionResult['glass'] as String?;
        final htmlGarnish = sectionResult['garnish'] as List<String>? ?? [];
        final htmlNotes = sectionResult['notes'] as String?;
        
        // Also try to extract directions from HTML (handles Lyres/Shopify embedded JSON)
        final htmlDirections = _extractDirectionsFromRawHtml(document, body);
        
        // Check if we need to supplement anything
        final needsEquipment = jsonLdResult.equipment.isEmpty && htmlEquipment.isNotEmpty;
        final needsGlass = (jsonLdResult.glass == null || jsonLdResult.glass!.isEmpty) && htmlGlass != null;
        final needsGarnish = jsonLdResult.garnish.isEmpty && htmlGarnish.isNotEmpty;
        final needsNotes = (jsonLdResult.notes == null || jsonLdResult.notes!.isEmpty) && htmlNotes != null;
        final needsDirections = jsonLdResult.directions.isEmpty && htmlDirections.isNotEmpty;
        
        if (needsEquipment || needsGlass || needsGarnish || needsNotes || needsDirections) {
          // Combine notes if both exist
          String? combinedNotes = jsonLdResult.notes;
          if (needsNotes) {
            combinedNotes = htmlNotes;
          } else if (combinedNotes != null && htmlNotes != null && !combinedNotes.contains(htmlNotes)) {
            // Append HTML notes to existing notes if they differ
            combinedNotes = '$combinedNotes\n\n$htmlNotes';
          }
          
          return RecipeImportResult(
            name: jsonLdResult.name,
            course: jsonLdResult.course,
            cuisine: jsonLdResult.cuisine,
            subcategory: jsonLdResult.subcategory,
            serves: jsonLdResult.serves,
            time: jsonLdResult.time,
            ingredients: jsonLdResult.ingredients,
            directions: needsDirections ? List<String>.from(htmlDirections) : jsonLdResult.directions,
            notes: combinedNotes,
            imageUrl: jsonLdResult.imageUrl,
            nutrition: jsonLdResult.nutrition,
            equipment: needsEquipment ? htmlEquipment : jsonLdResult.equipment,
            glass: needsGlass ? htmlGlass : jsonLdResult.glass,
            garnish: needsGarnish ? htmlGarnish : jsonLdResult.garnish,
            rawIngredients: jsonLdResult.rawIngredients,
            rawDirections: needsDirections ? htmlDirections : jsonLdResult.rawDirections,
            detectedCourses: jsonLdResult.detectedCourses,
            detectedCuisines: jsonLdResult.detectedCuisines,
            nameConfidence: jsonLdResult.nameConfidence,
            courseConfidence: jsonLdResult.courseConfidence,
            cuisineConfidence: jsonLdResult.cuisineConfidence,
            ingredientsConfidence: jsonLdResult.ingredientsConfidence,
            directionsConfidence: needsDirections ? 0.7 : jsonLdResult.directionsConfidence, // Lower confidence for HTML-extracted directions
            servesConfidence: jsonLdResult.servesConfidence,
            timeConfidence: jsonLdResult.timeConfidence,
            sourceUrl: jsonLdResult.sourceUrl,
            source: jsonLdResult.source,
            imagePaths: jsonLdResult.imagePaths,
          );
        }
        
        return jsonLdResult;
      }
      
      // Try to extract recipe data from embedded JavaScript (React/Next.js/Vue hydration state)
      final embeddedResult = _tryExtractFromEmbeddedJson(body, url);
      if (embeddedResult != null) return embeddedResult;

      // Fallback: try to parse from HTML structure
      final result = _parseFromHtmlWithConfidence(document, url, body);
      if (result != null) return result;
      
      // Provide more helpful error message with diagnostic info
      final jsonLdCount = jsonLdScripts.length;
      final hasMicrodata = document.querySelector('[itemtype*="Recipe"]') != null;
      final hasIngredientById = document.querySelector('#ingredients, [id="ingredients"]') != null;
      final hasRecipeClass = document.querySelector('.recipe, .recipe-card, .recipe-content') != null;
      final hasAnyLists = document.querySelectorAll('ul li, ol li').length > 0;
      final bodyText = document.body?.text ?? '';
      final bodyLength = bodyText.length;
      final hasBullets = bodyText.contains('•') || bodyText.contains('\u2022') || bodyText.contains('\u2023') || bodyText.contains('\u25E6');
      final hasH2 = document.querySelectorAll('h2').length;
      final hasH3 = document.querySelectorAll('h3').length;
      final hasIngredientWord = bodyText.toLowerCase().contains('ingredient');
      
      // Get page title to help diagnose what was returned
      final pageTitle = document.querySelector('title')?.text?.trim() ?? '';
      final titlePreview = pageTitle.length > 50 ? '${pageTitle.substring(0, 50)}...' : pageTitle;
      
      // Check for common text patterns
      final hasMeasurements = RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|tbsp|tsp)', caseSensitive: false).hasMatch(bodyText);
      
      // Check raw HTML for bullets and measurements (in case DOM parsing strips them)
      final rawHasBullets = body.contains('•') || body.contains('&bull;') || body.contains('&#8226;');
      final rawHasMeasurements = RegExp(r'\d+\s*g\s*\(', caseSensitive: false).hasMatch(body);
      
      // Check raw HTML for key markers the page should have
      final rawHasH2 = body.contains('<h2');
      final rawHasItemtype = body.toLowerCase().contains('itemtype');
      final rawHasSchema = body.toLowerCase().contains('schema.org');
      
      // Sample of body text for debugging (first 200 chars after title-like content)
      String bodySample = '';
      final ingredientIdx = bodyText.toLowerCase().indexOf('ingredient');
      if (ingredientIdx >= 0) {
        final endIdx = (ingredientIdx + 300).clamp(0, bodyText.length);
        bodySample = bodyText.substring(ingredientIdx, endIdx).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (bodySample.length > 100) bodySample = '${bodySample.substring(0, 100)}...';
      }
      
      // Also sample raw HTML near ingredient patterns
      String rawSample = '';
      final rawIngIdx = body.toLowerCase().indexOf('ingredient');
      if (rawIngIdx >= 0) {
        final rawEnd = (rawIngIdx + 200).clamp(0, body.length);
        rawSample = body.substring(rawIngIdx, rawEnd).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (rawSample.length > 80) rawSample = '${rawSample.substring(0, 80)}...';
      }
      
      String diagnostics = 'title:"$titlePreview", JSON-LD:$jsonLdCount, microdata:${hasMicrodata ? "yes" : "no"}, #ingredients:${hasIngredientById ? "yes" : "no"}, h2:$hasH2, h3:$hasH3, lists:${hasAnyLists ? "yes" : "no"}';
      diagnostics += ', rawH2:${rawHasH2 ? "yes" : "no"}, rawSchema:${rawHasSchema ? "yes" : "no"}';
      diagnostics += ', bullets:${hasBullets ? "yes" : "no"}, measurements:${hasMeasurements ? "yes" : "no"}';
      diagnostics += ', rawBullets:${rawHasBullets ? "yes" : "no"}, rawMeas:${rawHasMeasurements ? "yes" : "no"}';
      diagnostics += ', body=$bodyLength chars';
      if (rawSample.isNotEmpty) diagnostics += '. Raw: "$rawSample"';
      
      throw Exception(
        'Could not find recipe data on this page. '
        '$diagnostics. '
        'The page may use JavaScript to load content dynamically or use an unsupported format.'
      );
    } catch (e) {
      throw Exception('Failed to import recipe from URL: $e');
    }
  }
  
  /// Decode HTTP response body handling encoding errors and compression gracefully
  String _decodeResponseBody(http.Response response) {
    List<int> bytes = response.bodyBytes.toList();
    
    // Check if response is gzip compressed (either by header or by magic bytes)
    final contentEncoding = response.headers['content-encoding']?.toLowerCase() ?? '';
    final isGzipHeader = contentEncoding.contains('gzip');
    // Gzip magic bytes: 0x1f 0x8b
    final isGzipMagic = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    
    if (isGzipHeader || isGzipMagic) {
      try {
        bytes = gzip.decode(bytes);
      } catch (_) {
        // If decompression fails, try with original bytes
      }
    }
    
    // Check for brotli (we can't decode it, but detect it for better error messages)
    final isBrotli = contentEncoding.contains('br');
    if (isBrotli && bytes.length >= 2 && !(bytes[0] == 0x3c || bytes[0] == 0x0a || bytes[0] == 0x20)) {
      // Brotli compressed - try to request without compression
      // For now, just try to decode what we have
    }
    
    try {
      // Try UTF-8 decoding
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      try {
        // Try automatic decoding (handles Content-Type charset)
        return response.body;
      } catch (_) {
        // Last resort: use Latin-1 (never fails, but may produce wrong characters)
        return latin1.decode(bytes);
      }
    }
  }
  
  /// Try to extract recipe data from embedded JavaScript (React/Next.js/Vue hydration state)
  /// Many modern sites embed recipe data in script tags for client-side rendering
  RecipeImportResult? _tryExtractFromEmbeddedJson(String body, String sourceUrl) {
    // Common patterns for embedded JSON data in JavaScript-heavy sites
    final patterns = [
      // Next.js __NEXT_DATA__
      RegExp(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true),
      // Nuxt.js __NUXT__
      RegExp(r'window\.__NUXT__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      // Generic window.__INITIAL_STATE__ or similar
      RegExp(r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      // WordPress REST API embedded data
      RegExp(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', dotAll: true),
      // Generic JSON object containing recipe-like data
      RegExp(r'"recipeIngredient"\s*:\s*\[(.*?)\]', dotAll: true),
      RegExp(r'"ingredients"\s*:\s*\[(.*?)\]', dotAll: true),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(body);
      for (final match in matches) {
        try {
          String jsonStr = match.group(1) ?? '';
          if (jsonStr.isEmpty) continue;
          
          // For the ingredient array patterns, wrap them back into valid JSON
          if (pattern.pattern.contains('recipeIngredient') || pattern.pattern.contains('"ingredients"')) {
            // Try to find the full recipe object around this
            final ingredientIdx = body.indexOf(match.group(0)!);
            if (ingredientIdx >= 0) {
              // Search backward for opening brace of recipe object
              int braceCount = 0;
              int startIdx = ingredientIdx;
              for (int i = ingredientIdx; i >= 0 && i > ingredientIdx - 5000; i--) {
                if (body[i] == '}') braceCount++;
                if (body[i] == '{') {
                  braceCount--;
                  if (braceCount < 0) {
                    startIdx = i;
                    break;
                  }
                }
              }
              // Search forward for closing brace
              braceCount = 0;
              int endIdx = ingredientIdx + match.group(0)!.length;
              for (int i = startIdx; i < body.length && i < startIdx + 10000; i++) {
                if (body[i] == '{') braceCount++;
                if (body[i] == '}') {
                  braceCount--;
                  if (braceCount == 0) {
                    endIdx = i + 1;
                    break;
                  }
                }
              }
              jsonStr = body.substring(startIdx, endIdx);
            }
          }
          
          // Try to parse as JSON
          final data = jsonDecode(jsonStr);
          
          // Look for recipe data within the parsed JSON
          final result = _findRecipeInNestedJson(data, sourceUrl);
          if (result != null) return result;
        } catch (_) {
          continue;
        }
      }
    }
    
    return null;
  }
  
  /// Recursively search for recipe data in nested JSON structures
  RecipeImportResult? _findRecipeInNestedJson(dynamic data, String sourceUrl, [int depth = 0]) {
    if (depth > 10) return null; // Prevent infinite recursion
    
    if (data is Map<String, dynamic>) {
      // Check for @type: Recipe (standard JSON-LD)
      if (data['@type'] == 'Recipe' || data['type'] == 'Recipe') {
        final result = _parseJsonLdWithConfidence(data, sourceUrl);
        if (result != null) return result;
      }
      
      // Check if this looks like a recipe object but without @type (Next.js, WordPress ACF, etc.)
      if (_looksLikeRecipe(data)) {
        // First try JSON-LD parser (handles standard format)
        final result = _parseJsonLdWithConfidence(data, sourceUrl);
        if (result != null) return result;
        
        // If JSON-LD parser returned null (no @type), try parsing as non-standard format
        final nonStandardResult = _parseNonStandardRecipeJson(data, sourceUrl);
        if (nonStandardResult != null) return nonStandardResult;
      }
      
      // Recurse into nested objects
      for (final value in data.values) {
        final result = _findRecipeInNestedJson(value, sourceUrl, depth + 1);
        if (result != null) return result;
      }
    } else if (data is List) {
      for (final item in data) {
        final result = _findRecipeInNestedJson(item, sourceUrl, depth + 1);
        if (result != null) return result;
      }
    }
    
    return null;
  }
  
  /// Parse non-standard recipe JSON (Next.js __NEXT_DATA__, WordPress ACF, etc.)
  /// These have recipe data but no @type: Recipe
  RecipeImportResult? _parseNonStandardRecipeJson(Map<String, dynamic> data, String sourceUrl) {
    // Must have name
    final name = _cleanRecipeName(
      _parseString(data['name']) ?? 
      _parseString(data['title']) ?? 
      _parseString(data['recipeName']) ?? ''
    );
    if (name.isEmpty) return null;
    
    // Extract ingredients - support various formats
    var rawIngredientStrings = <String>[];
    final ingredientsData = data['ingredients'] ?? data['recipeIngredient'];
    if (ingredientsData != null) {
      rawIngredientStrings = _extractRawIngredients(ingredientsData);
    }
    
    // Extract directions - support various formats  
    var directions = <String>[];
    var rawDirections = <String>[];
    final instructionsData = data['instructions'] ?? data['recipeInstructions'] ?? data['directions'] ?? data['steps'];
    if (instructionsData != null) {
      directions = _parseInstructions(instructionsData);
      rawDirections = _extractRawDirections(instructionsData);
    }
    
    // Must have at least ingredients OR directions to be a valid recipe
    if (rawIngredientStrings.isEmpty && directions.isEmpty) return null;
    
    // Parse ingredients
    var ingredients = _parseIngredients(rawIngredientStrings);
    ingredients = _sortIngredientsByQuantity(ingredients);
    
    // Build raw ingredients list
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      final cleanedRaw = raw.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
      final isSectionOnly = parsed.name.isEmpty && parsed.section != null;
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        preparation: parsed.preparation,
        name: isSectionOnly ? '' : (parsed.name.isNotEmpty ? parsed.name : cleanedRaw),
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    }).where((i) => (i.name.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(i.name)) || i.sectionName != null).toList();
    
    // Extract other fields
    final serves = _parseString(data['serves']) ?? 
                   _parseString(data['yield']) ?? 
                   _parseString(data['recipeYield']);
    final time = _parseString(data['time']) ?? 
                 _parseString(data['cookTimeCustom']) ??
                 _parseString(data['cookTime']);
    final description = _parseString(data['description']);
    final imageUrl = _parseImage(data['image']);
    
    // Detect course
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    
    // Detect cuisine
    final cuisine = _parseCuisine(data['cuisine'] ?? data['recipeCuisine']);
    
    return RecipeImportResult(
      name: name,
      course: course,
      cuisine: cuisine,
      serves: serves,
      time: time,
      ingredients: ingredients,
      directions: directions,
      notes: description,
      imageUrl: imageUrl,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: _detectAllCourses(data),
      detectedCuisines: _detectAllCuisines(data),
      nameConfidence: 0.9,
      courseConfidence: 0.6,
      cuisineConfidence: cuisine != null ? 0.7 : 0.3,
      ingredientsConfidence: rawIngredientStrings.isNotEmpty ? 0.8 : 0.0,
      directionsConfidence: directions.isNotEmpty ? 0.8 : 0.0,
      servesConfidence: serves != null ? 0.7 : 0.0,
      timeConfidence: time != null ? 0.7 : 0.0,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }
  
  /// Check if a map looks like it might be recipe data
  bool _looksLikeRecipe(Map<String, dynamic> data) {
    // Must have some kind of name/title
    final hasName = data.containsKey('name') || data.containsKey('title') || data.containsKey('recipeName');
    if (!hasName) return false;
    
    // Must have ingredients
    final hasIngredients = data.containsKey('recipeIngredient') || 
        data.containsKey('ingredients') || 
        data.containsKey('extendedIngredients');
    
    // Or must have instructions/directions
    final hasInstructions = data.containsKey('recipeInstructions') || 
        data.containsKey('instructions') || 
        data.containsKey('directions') ||
        data.containsKey('steps');
    
    return hasIngredients || hasInstructions;
  }
  
  /// Extract YouTube video ID from various URL formats
  String? _extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    final host = uri.host.toLowerCase();
    
    // youtube.com/watch?v=VIDEO_ID
    if (host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    
    // youtu.be/VIDEO_ID
    if (host == 'youtu.be') {
      final path = uri.pathSegments;
      return path.isNotEmpty ? path.first : null;
    }
    
    // youtube.com/embed/VIDEO_ID
    if (host.contains('youtube.com') && uri.path.startsWith('/embed/')) {
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        return segments[1];
      }
    }
    
    return null;
  }
  
  /// Import recipe from YouTube video
  Future<RecipeImportResult> _importFromYouTube(String videoId, String sourceUrl) async {
    try {
      // Fetch the video page to get description and metadata
      final videoPageUrl = 'https://www.youtube.com/watch?v=$videoId';
      final response = await http.get(
        Uri.parse(videoPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch YouTube video: ${response.statusCode}');
      }
      
      // Decode response body - handle encoding errors gracefully
      String body;
      try {
        // Try automatic decoding (handles Content-Type charset)
        body = response.body;
      } on FormatException {
        // If automatic decoding fails due to encoding, try UTF-8 with error tolerance
        try {
          body = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (_) {
          // Last resort: use Latin-1 (never fails, but may produce wrong characters)
          body = latin1.decode(response.bodyBytes);
        }
      }
      
      // Extract video title from page
      String? title;
      final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(body);
      if (titleMatch != null) {
        title = _decodeUnicodeEscapes(titleMatch.group(1) ?? '');
      }
      
      // Try to get title from og:title as fallback
      if (title == null || title.isEmpty) {
        final ogTitleMatch = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(body);
        title = ogTitleMatch?.group(1);
      }
      
      // Extract channel name
      String? channelName;
      final channelMatch = RegExp(r'"ownerChannelName":\s*"([^"]+)"').firstMatch(body);
      if (channelMatch != null) {
        channelName = _decodeUnicodeEscapes(channelMatch.group(1) ?? '');
      }
      
      // Extract video description
      String? description;
      // Try to find description in the initial player response JSON
      final descMatch = RegExp(r'"shortDescription":\s*"((?:[^"\\]|\\.)*)"').firstMatch(body);
      if (descMatch != null) {
        description = _decodeUnicodeEscapes(descMatch.group(1) ?? '');
      }
      
      // Extract thumbnail
      String? thumbnail;
      final thumbMatch = RegExp(r'"thumbnails":\s*\[\s*\{\s*"url":\s*"([^"]+)"').firstMatch(body);
      if (thumbMatch != null) {
        thumbnail = thumbMatch.group(1);
      }
      // Fallback to standard thumbnail URL
      thumbnail ??= 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      
      // Extract chapters from description (timestamp lines)
      final chapters = _extractYouTubeChapters(description ?? '');
      
      // Try to fetch and parse transcript/captions with timestamps
      List<TranscriptSegment> transcriptSegments = [];
      try {
        final (segments, _) = await _fetchYouTubeTranscriptWithTimestamps(videoId, body);
        transcriptSegments = segments;
      } catch (e) {
        // Transcript fetch failed, will fall back to description parsing
      }
      
      // Parse the description for ingredients
      final parsedDescription = _parseYouTubeDescription(description ?? '');
      
      // Build directions from chapters + transcript
      List<String> directions = [];
      
      if (chapters.isNotEmpty && transcriptSegments.isNotEmpty) {
        // Use chapters to slice transcript into steps
        directions = _buildDirectionsFromChapters(chapters, transcriptSegments);
      } else if (chapters.isNotEmpty) {
        // Just use chapter titles if no transcript
        directions = chapters.map((c) => c.title).toList();
      } else {
        // Fall back to description parsing
        directions = parsedDescription['directions'] ?? [];
      }
      
      // Build ingredients list
      final rawIngredientStrings = (parsedDescription['ingredients'] as List<String>?) ?? [];
      final ingredients = rawIngredientStrings
          .map((s) => _parseIngredientString(s))
          .where((i) => i.name.isNotEmpty)
          .toList();
      
      // Clean recipe name - remove common YouTube suffixes
      final String recipeName = _cleanYouTubeTitle(title ?? 'YouTube Recipe');
      
      // Detect course from title
      final detectedCourse = _detectCourseFromTitle(recipeName);
      
      // Build time string from parsed times - extract numeric values and sum
      String? recipeTime;
      final prepTime = parsedDescription['prepTime'] as String?;
      final cookTime = parsedDescription['cookTime'] as String?;
      final totalTime = parsedDescription['totalTime'] as String?;
      
      if (totalTime != null) {
        recipeTime = _normalizeTimeString(totalTime);
      } else if (prepTime != null || cookTime != null) {
        final prepMinutes = _extractMinutes(prepTime);
        final cookMinutes = _extractMinutes(cookTime);
        final totalMinutes = prepMinutes + cookMinutes;
        if (totalMinutes > 0) {
          if (totalMinutes >= 60) {
            final hours = totalMinutes ~/ 60;
            final mins = totalMinutes % 60;
            recipeTime = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
          } else {
            recipeTime = '$totalMinutes min';
          }
        }
      }
      
      // Build notes with channel attribution
      String notes = 'Source: YouTube video by ${channelName ?? "Unknown"}';
      if (parsedDescription['notes'] != null) {
        notes += '\n\n${parsedDescription["notes"]}';
      }
      
      // Determine if we have enough data
      final hasIngredients = ingredients.isNotEmpty;
      final hasDirections = directions.isNotEmpty;
      
      // Create raw ingredient data for review, filtering out empty entries
      final rawIngredients = rawIngredientStrings.map((raw) {
        final parsed = _parseIngredientString(raw);
        final bakerPct = _extractBakerPercent(raw);
        
        // For section-only items (parsed name is empty but has section),
        // keep the empty name so the review screen can display it as a section header
        final isSectionOnly = parsed.name.isEmpty && parsed.section != null;
        
        return RawIngredientData(
          original: raw,
          amount: parsed.amount,
          unit: parsed.unit,
          preparation: parsed.preparation,
          bakerPercent: bakerPct != null ? '$bakerPct%' : null,
          name: isSectionOnly ? '' : (parsed.name.isNotEmpty ? parsed.name : raw),
          looksLikeIngredient: parsed.name.isNotEmpty,
          isSection: parsed.section != null,
          sectionName: parsed.section,
        );
      })
      // Filter out empty entries - must have alphanumeric in name OR have a section
      .where((i) => (i.name.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(i.name)) || i.sectionName != null)
      .toList();
      
      // Calculate confidence based on what was successfully parsed
      // Higher confidence when we found structured data
      final nameConf = title != null && title.isNotEmpty ? 0.85 : 0.3;
      final courseConf = detectedCourse != null ? 0.8 : 0.5;
      final ingredientsConf = hasIngredients 
          ? (ingredients.length >= 3 ? 0.85 : 0.7) // More ingredients = more confidence
          : 0.0;
      final directionsConf = hasDirections 
          ? (transcriptSegments.isNotEmpty ? 0.85 : 0.7) 
          : 0.0;
      final timeConf = recipeTime != null ? 0.9 : 0.0;
      
      return RecipeImportResult(
        name: recipeName,
        course: detectedCourse ?? 'Mains',
        time: recipeTime,
        ingredients: ingredients,
        directions: directions,
        notes: notes,
        imageUrl: thumbnail,
        rawIngredients: rawIngredients,
        rawDirections: directions,
        detectedCourses: [detectedCourse ?? 'Mains'],
        nameConfidence: nameConf,
        courseConfidence: courseConf,
        ingredientsConfidence: ingredientsConf,
        directionsConfidence: directionsConf,
        timeConfidence: timeConf,
        sourceUrl: sourceUrl,
        source: RecipeSource.url,
      );
    } catch (e) {
      throw Exception('Failed to import YouTube video: $e');
    }
  }
  
  /// Decode unicode escape sequences like \u0026 in YouTube JSON
  String _decodeUnicodeEscapes(String text) {
    return text.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) {
        final code = int.tryParse(match.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    ).replaceAll(r'\n', '\n').replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
  }
  
  /// Clean YouTube video title to extract recipe name
  String _cleanYouTubeTitle(String title) {
    var cleaned = title;
    
    // Remove common patterns
    final patterns = [
      RegExp(r'\s*[|\-–—]\s*YouTube\s*$', caseSensitive: false),
      RegExp(r'\s*\|\s*[^|]+$'), // Remove "| Channel Name" suffix
      RegExp(r'\s*[-–—]\s*(?:Full\s+)?Recipe\s*$', caseSensitive: false),
      RegExp(r'^\s*(?:How\s+to\s+(?:Make|Cook|Prepare)\s+)', caseSensitive: false),
      RegExp(r'\s*\((?:Easy|Simple|Quick|Best|Homemade|The\s+Best)(?:\s+Recipe)?\)\s*', caseSensitive: false),
      RegExp(r'\s*(?:Recipe|Tutorial|Video)\s*$', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    return cleaned.trim();
  }
  
  /// Detect recipe course from title keywords
  String? _detectCourseFromTitle(String title) {
    final lowerTitle = title.toLowerCase();
    
    // Smoking/BBQ course keywords
    if (RegExp(r'\b(?:smoked|smoking|smoker|bbq|barbecue|barbeque|low\s*and\s*slow|pellet\s*grill)\b').hasMatch(lowerTitle)) {
      return 'Smoking';
    }
    
    // Drinks course keywords (check early - spirits in title = likely a drink recipe)
    if (RegExp(r'\b(?:cocktail|smoothie|juice|lemonade|drink|beverage|mocktail|sangria|punch|milkshake|frappe|martini|margarita|mojito|daiquiri|manhattan|negroni|old\s*fashioned|highball|sour|fizz|collins|spritz|mimosa|bellini|cosmopolitan|mai\s*tai|pina\s*colada|bloody\s*mary|paloma|vodka|gin|rum|tequila|whiskey|whisky|bourbon|scotch|brandy|cognac|mezcal)\b').hasMatch(lowerTitle)) {
      return 'Drinks';
    }
    
    // Modernist keywords
    if (RegExp(r'\b(?:modernist|molecular|spherification|gelification|sous\s*vide|foam|caviar|agar|xanthan)\b').hasMatch(lowerTitle)) {
      return 'Modernist';
    }
    
    // Breads course keywords
    if (RegExp(r'\b(?:bread|focaccia|ciabatta|baguette|brioche|sourdough|rolls?|buns?|loaf|loaves|naan|pita|flatbread|bagels?|croissants?|pretzels?|challah|dough)\b').hasMatch(lowerTitle)) {
      return 'Breads';
    }
    
    // Desserts course keywords
    if (RegExp(r'\b(?:cake|cookie|cookies|brownie|pie|tart|dessert|sweet|chocolate|cheesecake|cupcake|muffin|donut|doughnut|pastry|pastries|pudding|ice\s*cream|sorbet|flan|custard|macarons?|tiramisu|mousse|crème\s*brûlée|pavlova|baklava|cinnamon\s*rolls?)\b').hasMatch(lowerTitle)) {
      return 'Desserts';
    }
    
    // Soups course keywords
    if (RegExp(r'\b(?:soup|stew|chowder|bisque|broth|consommé|gazpacho|minestrone|pho|ramen|chili)\b').hasMatch(lowerTitle)) {
      return 'Soup';
    }
    
    // Sides course keywords
    if (RegExp(r'\b(?:salad|slaw|coleslaw|side\s*dish|mashed|roasted\s*(?:vegetables?|veggies|potatoes)|french\s*fries|fries|wedges|gratin|pilaf|rice\s*dish)\b').hasMatch(lowerTitle)) {
      return 'Sides';
    }
    
    // Sauces course keywords
    if (RegExp(r'\b(?:sauce|gravy|dressing|dip|aioli|mayo|mayonnaise|ketchup|mustard|vinaigrette|pesto|salsa|guacamole|hummus|relish|chutney|coulis)\b').hasMatch(lowerTitle)) {
      return 'Sauces';
    }
    
    // Brunch course keywords
    if (RegExp(r'\b(?:brunch|breakfast|pancake|waffle|french\s*toast|eggs?\s*benedict|omelette|omelet|frittata|quiche|hash|scrambled|poached\s*eggs?)\b').hasMatch(lowerTitle)) {
      return 'Brunch';
    }
    
    // Apps (appetizers) course keywords
    if (RegExp(r'\b(?:appetizer|starter|tapas|antipasto|bruschetta|crostini|canapé|spring\s*rolls?|egg\s*rolls?|dumplings?|wontons?|samosa|empanada|arancini|croquette)\b').hasMatch(lowerTitle)) {
      return 'Apps';
    }
    
    // Pickles course keywords
    if (RegExp(r'\b(?:pickle|pickled|ferment|kimchi|sauerkraut|preserve|preserves|canning|jam|jelly|marmalade)\b').hasMatch(lowerTitle)) {
      return 'Pickles';
    }
    
    // Rubs course keywords
    if (RegExp(r'\b(?:rub|seasoning|spice\s*mix|spice\s*blend|marinade)\b').hasMatch(lowerTitle)) {
      return 'Rubs';
    }
    
    return null; // Let it default to Mains
  }
  
  /// Parse YouTube video description to extract ingredients and directions
  Map<String, dynamic> _parseYouTubeDescription(String description) {
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'directions': <String>[],
      'notes': null,
      'prepTime': null,
      'cookTime': null,
      'totalTime': null,
    };
    
    if (description.isEmpty) return result;
    
    // Split into lines
    final lines = description.split('\n');
    
    // State machine to track which section we're in
    String? currentSection;
    final ingredients = <String>[];
    final directions = <String>[];
    final notes = <String>[];
    String? prepTime;
    String? cookTime;
    String? totalTime;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Extract time information before other processing
      final timeMatch = RegExp(
        r'^(prep|cook|total|bake|rise|rest|chill)\s*(?:time)?\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (timeMatch != null) {
        final timeType = timeMatch.group(1)!.toLowerCase();
        final timeValue = timeMatch.group(2)!.trim();
        if (timeType == 'prep') {
          prepTime = timeValue;
        } else if (timeType == 'cook' || timeType == 'bake') {
          cookTime = timeValue;
        } else if (timeType == 'total') {
          totalTime = timeValue;
        }
        // Don't add to notes - we'll use the structured time field
        continue;
      }
      
      // Strip common decorative characters for section header detection
      final strippedLine = line.replaceAll(RegExp(r'^[•\-*#▶►▸→]+\s*|\s*[•\-*#◀◄◂←]+$'), '').trim();
      final lowerLine = strippedLine.toLowerCase();
      
      // Check for section headers
      if (_isIngredientSectionHeader(lowerLine)) {
        currentSection = 'ingredients';
        continue;
      } else if (_isDirectionSectionHeader(lowerLine)) {
        currentSection = 'directions';
        continue;
      } else if (_isNotesSectionHeader(lowerLine)) {
        currentSection = 'notes';
        continue;
      } else if (_isIgnorableSection(lowerLine)) {
        currentSection = 'ignore';
        continue;
      } else if (_isTimestampSectionHeader(lowerLine)) {
        // Timestamps/Chapters section typically contains step-by-step directions
        currentSection = 'directions';
        continue;
      }
      
      // Skip links, timestamps, and other non-content lines
      if (_isIgnorableLine(line)) continue;
      
      // Handle yield info separately (add to notes)
      if (_isYieldInfo(line)) {
        notes.add(line);
        continue;
      }
      
      // If we haven't hit a section header yet, try to auto-detect
      if (currentSection == null) {
        if (_looksLikeIngredient(line)) {
          currentSection = 'ingredients';
        } else if (_looksLikeDirection(line)) {
          currentSection = 'directions';
        } else {
          // Could be intro text - add to notes
          notes.add(line);
          continue;
        }
      }
      
      // Smart section assignment - check what the line actually looks like
      final looksLikeIng = _looksLikeIngredient(line);
      final looksLikeDir = _looksLikeDirection(line);
      
      // Add to appropriate section with smart switching
      switch (currentSection) {
        case 'ingredients':
          if (looksLikeIng) {
            ingredients.add(line);
          } else if (looksLikeDir && !looksLikeIng) {
            // Switched to directions without a header
            currentSection = 'directions';
            directions.add(_cleanDirectionLine(line));
          }
          break;
        case 'directions':
          // Check if this line is actually an ingredient (switch back)
          if (looksLikeIng && !_isTimestampedStep(line)) {
            // This looks like an ingredient, not a direction
            currentSection = 'ingredients';
            ingredients.add(line);
          } else if (looksLikeDir) {
            directions.add(_cleanDirectionLine(line));
          } else if (_isTimestampedStep(line)) {
            // Timestamped step - extract the title
            directions.add(_cleanDirectionLine(line));
          } else if (line.length > 30 && !looksLikeIng) {
            // Once in directions section, longer lines are likely directions
            // Skip obvious non-direction lines
            if (!line.contains('...') && !line.startsWith('http') && 
                !RegExp(r'^[A-Z][A-Z\s]+$').hasMatch(line)) {
              directions.add(_cleanDirectionLine(line));
            }
          }
          break;
        case 'notes':
          notes.add(line);
          break;
        case 'ignore':
          // Skip this section
          break;
        case null:
          // No section yet - this shouldn't happen but handle it
          if (looksLikeIng) {
            currentSection = 'ingredients';
            ingredients.add(line);
          } else if (looksLikeDir) {
            currentSection = 'directions';
            directions.add(_cleanDirectionLine(line));
          } else {
            notes.add(line);
          }
          break;
      }
    }
    
    result['ingredients'] = ingredients;
    result['directions'] = directions;
    if (notes.isNotEmpty) {
      result['notes'] = notes.join('\n');
    }
    result['prepTime'] = prepTime;
    result['cookTime'] = cookTime;
    result['totalTime'] = totalTime;
    
    return result;
  }
  
  bool _isIngredientSectionHeader(String line) {
    return RegExp(r'^(ingredients?|what you.?ll need|you.?ll need|shopping list)[:\s]*$', caseSensitive: false).hasMatch(line) ||
           line == 'ingredients' || line == 'ingredient';
  }
  
  bool _isDirectionSectionHeader(String line) {
    return RegExp(r'^(directions?|instructions?|method|steps?|how to (?:make|cook|prepare)|procedure)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isNotesSectionHeader(String line) {
    return RegExp(r'^(notes?|tips?|variations?)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isIgnorableSection(String line) {
    return RegExp(r'^(follow me|subscribe|social|links?|connect|my (?:gear|equipment|kitchen|tools|setup|camera)|affiliate|music|credits?|shop|merch|merchandise|sponsors?|business|contact|about me|faq|disclaimer)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  /// Check if line is a timestamps/chapters section header (contains directions)
  bool _isTimestampSectionHeader(String line) {
    return RegExp(r'^(chapters?|timestamps?)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isIgnorableLine(String line) {
    // Separator lines (dashes, equals, underscores, box drawing chars)
    if (RegExp(r'^[─━═—–\-_=]{3,}\s*$').hasMatch(line)) {
      return true;
    }
    // ALL CAPS lines that look like section headers (e.g., "OTHER VIDEOS YOU'LL ENJOY")
    if (line.length > 10 && line.length < 60) {
      final upperCount = line.replaceAll(RegExp(r'[^A-Z]'), '').length;
      final letterCount = line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (letterCount > 5 && upperCount / letterCount > 0.8) {
        return true;
      }
    }
    // Lines starting with emoji hearts/symbols followed by ALL CAPS
    if (RegExp(r'^[♥♡★☆●○◆◇▶►▸❤️💕🔥👇👆📺🎥🎬📹🍳🍴🍽️\s]+[A-Z]{2,}').hasMatch(line)) {
      return true;
    }
    // URLs anywhere in the line
    if (line.contains('http://') || line.contains('https://') || line.startsWith('www.') || line.contains('.com/') || line.contains('.co/')) {
      return true;
    }
    // Social media handles
    if (RegExp(r'^[@#]').hasMatch(line)) {
      return true;
    }
    // Amazon affiliate patterns
    if (RegExp(r'amzn\.to|amazon\.com|a]inks|affiliate|commission', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Social media and promo boilerplate
    if (RegExp(r'subscribe|follow me|check out my|filmed with|music by|instagram|facebook|twitter|tiktok|patreon|merch|merchandise|shop my|use code|discount|sponsored|#ad\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Equipment/gear list sections
    if (RegExp(r'^my\s+(?:gear|equipment|kitchen|tools|camera|setup)|i\s+use\s+(?:this|these)|what i\s+(?:film|shoot|use)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Business inquiries / contact info
    if (RegExp(r'business\s*(?:inquir|email)|contact\s*me|for\s*(?:inquir|collaborat)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Section header "chapters" or "timestamps" alone
    if (RegExp(r'^chapters?\s*$|^timestamps?\s*$', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // NOTE: We do NOT filter "timestamp lines" like "Mixing dough – 00:55" 
    // because we want to extract those as directions
    return false;
  }
  
  bool _looksLikeIngredient(String line) {
    // First, exclude timestamp lines like "Mixing dough – 00:55"
    if (_isTimestampedStep(line)) {
      return false;
    }
    // Exclude numbered direction steps like "1. Stir the flour" or "1) Mix ingredients"
    if (RegExp(r'^\d+[.):]\s+[A-Za-z]').hasMatch(line)) {
      return false;
    }
    // Contains measurement units
    if (RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml|l|pound|gram|ounce|teaspoon|tablespoon)s?\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Starts with a number followed by a unit (not just a bare number which could be a step)
    if (RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?\s*(?:cup|tbsp|tsp|oz|lb|g|kg|ml|l)s?\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Starts with a fraction like 1/4 or unicode fractions
    if (RegExp(r'^(?:\d+\s+)?(?:\d+/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])\s').hasMatch(line)) {
      return true;
    }
    // Baker's percentage format: "Flour, 100% – 600g" or "Water, 75%"
    if (RegExp(r'\d+%\s*[–-]?\s*\d*', caseSensitive: false).hasMatch(line) && line.length < 80) {
      return true;
    }
    // Format like "Ingredient Name – amount" (with en-dash) but NOT timestamp format
    // Must have a measurement-like value after the dash, not just digits (which could be time)
    if (RegExp(r'^[A-Za-z][^–-]*[–-]\s*\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml|%)', caseSensitive: false).hasMatch(line) && line.length < 80) {
      return true;
    }
    // Short line with common ingredient words
    if (line.length < 60 && RegExp(r'\b(?:salt|pepper|butter|oil|garlic|onion|flour|sugar|water|milk|cream|egg|chicken|beef|pork|yeast|olive|rosemary|herbs?)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // "as needed" or "to taste" patterns
    if (RegExp(r'\b(?:as needed|to taste|optional|for topping|for garnish)\b', caseSensitive: false).hasMatch(line) && line.length < 60) {
      return true;
    }
    return false;
  }
  
  bool _looksLikeDirection(String line) {
    // Numbered step
    if (RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Timestamped step like "Mixing the dough – 00:55" or "Step name - 1:23"
    if (_isTimestampedStep(line)) {
      return true;
    }
    // Starts with cooking action verb (expanded list)
    if (RegExp(r'^(?:preheat|heat|mix|combine|add|stir|whisk|fold|pour|place|put|cook|bake|roast|fry|sauté|boil|simmer|reduce|let|allow|serve|garnish|season|taste|check|remove|transfer|set|cover|wrap|chill|refrigerate|freeze|blend|process|pulse|slice|dice|chop|mince|grate|shred|knead|proof|rise|ferment|dimple|top|cut|use|form|make|prepare|work|bring|turn|roll|shape|flatten|stretch|pull|push|press|spread|brush|drizzle|sprinkle|dust|coat|dip|toss|flip|rotate|rest|cool|warm|melt|dissolve|cream|beat|whip|pipe|layer|assemble|arrange|portion|divide|measure|weigh|sift|strain|drain|rinse|wash|dry|pat|trim|peel|core|seed|pit|zest|juice|squeeze|crack|separate|break|tear|crumble|crush|grind|puree|mash|smash|score|slit)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Long sentence that sounds instructional (contains action verbs anywhere)
    if (line.length > 40 && RegExp(r'\b(?:until|minutes?|hours?|degrees?|°|constantly|occasionally|gently|carefully|slowly|thoroughly|completely|well|evenly)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Don't use length alone - too many false positives with intro paragraphs
    return false;
  }
  
  /// Check if line is yield/serving info like "(makes one 9x13 bread)"
  bool _isYieldInfo(String line) {
    return RegExp(r'^\(?\s*(?:makes?|yields?|serves?|for)\s+', caseSensitive: false).hasMatch(line);
  }
  
  /// Check if line is a timestamped step like "Mixing dough – 00:55"
  bool _isTimestampedStep(String line) {
    // Format: "Step description – MM:SS" or "Step description - M:SS"
    return RegExp(r'^[A-Za-z].+\s*[–-]\s*\d{1,2}:\d{2}(?::\d{2})?\s*$').hasMatch(line);
  }
  
  /// Extract step title from timestamped line
  String? _extractStepFromTimestamp(String line) {
    final match = RegExp(r'^(.+?)\s*[–-]\s*\d{1,2}:\d{2}(?::\d{2})?\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }
  
  /// Extract minutes from a time string like "15 minutes" or "1 hour 30 minutes"
  int _extractMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    
    int totalMinutes = 0;
    
    // Extract hours
    final hoursMatch = RegExp(r'(\d+)\s*(?:hours?|hrs?|h)\b', caseSensitive: false).firstMatch(timeStr);
    if (hoursMatch != null) {
      totalMinutes += (int.tryParse(hoursMatch.group(1)!) ?? 0) * 60;
    }
    
    // Extract minutes
    final minsMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?|m)\b', caseSensitive: false).firstMatch(timeStr);
    if (minsMatch != null) {
      totalMinutes += int.tryParse(minsMatch.group(1)!) ?? 0;
    }
    
    // If just a bare number, assume minutes
    if (totalMinutes == 0) {
      final bareNumber = RegExp(r'^(\d+)\s*$').firstMatch(timeStr.trim());
      if (bareNumber != null) {
        totalMinutes = int.tryParse(bareNumber.group(1)!) ?? 0;
      }
    }
    
    return totalMinutes;
  }
  
  /// Normalize a time string to a clean format
  String _normalizeTimeString(String timeStr) {
    final minutes = _extractMinutes(timeStr);
    if (minutes <= 0) return timeStr; // Can't parse, return as-is
    
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    } else {
      return '$minutes min';
    }
  }
  
  String _cleanDirectionLine(String line) {
    // First, try to extract step title from timestamp format
    final timestampStep = _extractStepFromTimestamp(line);
    if (timestampStep != null) {
      return timestampStep;
    }
    // Remove step numbers at the beginning
    var cleaned = line.replaceFirst(RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false), '');
    return cleaned.trim();
  }
  
  /// Check if a direction line should be skipped (junk content)
  bool _isJunkDirectionLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    
    // Skip markdown-style titles like **Title** (these are often recipe titles, not directions)
    if (RegExp(r'^\*\*[^*]+\*\*$').hasMatch(trimmed)) return true;
    
    // Skip "By AUTHOR NAME" lines (author bylines)
    if (RegExp(r'^By\s+[A-Z][A-Z\s]+$', caseSensitive: true).hasMatch(trimmed)) return true;
    if (RegExp(r'^By\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)*$').hasMatch(trimmed)) return true;
    
    // Skip standalone "Step X" headers (the content follows in another element)
    if (RegExp(r'^Step\s*\d+\.?$', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip navigation/UI elements
    if (trimmed.toLowerCase() == 'directions' ||
        trimmed.toLowerCase() == 'instructions' ||
        trimmed.toLowerCase() == 'method' ||
        trimmed.toLowerCase() == 'steps' ||
        trimmed.toLowerCase() == 'preparation') return true;
    
    // Skip very short lines that are likely headers
    if (trimmed.length < 5) return true;
    
    // Skip lines that are just numbers or punctuation
    if (RegExp(r'^[\d\s.,;:!?-]+$').hasMatch(trimmed)) return true;
    
    return false;
  }
  
  /// Extract chapters from YouTube description
  /// Format: "Chapter Title – MM:SS" or "MM:SS Chapter Title"
  List<YouTubeChapter> _extractYouTubeChapters(String description) {
    final chapters = <YouTubeChapter>[];
    final lines = description.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Format 1: "Title – MM:SS" or "Title - M:SS"
      var match = RegExp(r'^(.+?)\s*[–-]\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$').firstMatch(line);
      if (match != null) {
        final title = match.group(1)?.trim() ?? '';
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        final hours = int.tryParse(match.group(4) ?? '0') ?? 0;
        
        if (title.isNotEmpty && !_isIgnorableLine(title)) {
          chapters.add(YouTubeChapter(
            title: title,
            startSeconds: hours * 3600 + minutes * 60 + seconds,
          ),);
        }
        continue;
      }
      
      // Format 2: "MM:SS Title" or "M:SS Title"
      match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s+(.+)$').firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final hours = int.tryParse(match.group(3) ?? '0') ?? 0;
        final title = match.group(4)?.trim() ?? '';
        
        if (title.isNotEmpty && !_isIgnorableLine(title)) {
          chapters.add(YouTubeChapter(
            title: title,
            startSeconds: hours * 3600 + minutes * 60 + seconds,
          ),);
        }
      }
    }
    
    return chapters;
  }
  
  /// Fetch YouTube transcript with timestamps
  /// Returns tuple of (segments, debugInfo)
  Future<(List<TranscriptSegment>, String)> _fetchYouTubeTranscriptWithTimestamps(String videoId, String pageBody) async {
    try {
      final captionTrackMatch = RegExp(
        r'"captionTracks":\s*\[(.*?)\]',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (captionTrackMatch == null) {
        return (<TranscriptSegment>[], 'no captionTracks in page');
      }
      
      final captionTracksJson = captionTrackMatch.group(1) ?? '';
      
      String? captionUrl;
      String? langCode;
      String matchedType = '';
      
      // Simple approach: find baseUrl and languageCode separately
      // First, try to find English captions by looking for languageCode":"en" near a baseUrl
      
      // Check if there's an English caption track
      if (captionTracksJson.contains('"languageCode":"en"') || 
          captionTracksJson.contains('"vssId":".en"') ||
          captionTracksJson.contains('"vssId":"a.en"')) {
        langCode = 'en';
        matchedType = 'en';
      }
      
      // Extract the first baseUrl we can find
      final baseUrlMatch = RegExp(r'"baseUrl"\s*:\s*"([^"]+)"').firstMatch(captionTracksJson);
      if (baseUrlMatch != null) {
        captionUrl = _decodeUnicodeEscapes(baseUrlMatch.group(1)!);
        if (matchedType.isEmpty) matchedType = 'first';
      }
      
      // If no English found, try to extract any language code
      if (langCode == null) {
        final langMatch = RegExp(r'"languageCode"\s*:\s*"([^"]+)"').firstMatch(captionTracksJson);
        if (langMatch != null) {
          langCode = langMatch.group(1);
          matchedType = 'lang-$langCode';
        }
      }
      
      if (captionUrl == null) {
        // Include a sample of what we found for debugging
        final sample = captionTracksJson.length > 100 
            ? captionTracksJson.substring(0, 100) 
            : captionTracksJson;
        return (<TranscriptSegment>[], 'no baseUrl found. Sample: $sample');
      }
      
      // Debug: check what's in the URL before we modify it
      final hasLangInUrl = captionUrl.contains('lang=');
      final langInUrlMatch = RegExp(r'lang=([a-zA-Z\-]+)').firstMatch(captionUrl);
      final langInUrl = langInUrlMatch?.group(1) ?? 'none';
      
      // Ensure the URL has the lang parameter
      if (langCode != null && !hasLangInUrl) {
        captionUrl = captionUrl.contains('?') 
            ? '$captionUrl&lang=$langCode' 
            : '$captionUrl?lang=$langCode';
      }
      
      // Debug info about URL
      final urlDebug = 'url_lang=$langInUrl, matchType=$matchedType';
      
      String? successBody;
      String usedMethod = '';
      String lastError = '';
      
      // Method 1: Try to find transcript engagement panel params
      // Look for engagement panel with transcript - try multiple patterns
      String? transcriptParams;
      String foundPattern = '';
      
      // Pattern 1: Look for transcript panel targetId and nearby params
      final panelMatch1 = RegExp(
        r'"targetId"\s*:\s*"engagement-panel-searchable-transcript"[^}]*?"params"\s*:\s*"([^"]+)"',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (panelMatch1 != null) {
        transcriptParams = panelMatch1.group(1);
        foundPattern = 'p1';
      }
      
      // Pattern 2: Look for transcriptEndpoint params
      if (transcriptParams == null) {
        final panelMatch2 = RegExp(
          r'"transcriptEndpoint"\s*:\s*\{[^}]*"params"\s*:\s*"([^"]+)"',
          dotAll: true,
        ).firstMatch(pageBody);
        if (panelMatch2 != null) {
          transcriptParams = panelMatch2.group(1);
          foundPattern = 'p2';
        }
      }
      
      // Pattern 3: Look for showTranscriptCommand or openTranscript patterns
      if (transcriptParams == null) {
        final panelMatch3 = RegExp(
          r'"(?:showTranscript|openTranscript)[^"]*"[^}]*?"params"\s*:\s*"([^"]+)"',
          dotAll: true,
        ).firstMatch(pageBody);
        if (panelMatch3 != null) {
          transcriptParams = panelMatch3.group(1);
          foundPattern = 'p3';
        }
      }
      
      // Pattern 4: Broader search - any params near "transcript" keyword
      if (transcriptParams == null) {
        // Search for transcript-related params in a 500 char window
        final transcriptSection = RegExp(
          r'transcript[^{]*\{[^}]{0,300}"params"\s*:\s*"([^"]+)"',
          caseSensitive: false,
        ).firstMatch(pageBody);
        if (transcriptSection != null) {
          transcriptParams = transcriptSection.group(1);
          foundPattern = 'p4';
        }
      }
      
      if (transcriptParams != null) {
        // Retry up to 3 times - YouTube API can be flaky
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final transcriptResponse = await http.post(
              Uri.parse('https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Origin': 'https://www.youtube.com',
                'Referer': 'https://www.youtube.com/watch?v=$videoId',
              },
              body: '{"context":{"client":{"clientName":"WEB","clientVersion":"2.20231219.04.00","hl":"en"}},"params":"$transcriptParams"}',
            );
            
            if (transcriptResponse.statusCode == 200 && transcriptResponse.body.isNotEmpty) {
              final segments = _parseYouTubeiTranscript(transcriptResponse.body);
              if (segments.isNotEmpty) {
                return (segments, 'youtubei($foundPattern): ${segments.length} segments');
              }
              lastError = 'youtubei($foundPattern): 0 segs';
            } else {
              lastError = 'youtubei($foundPattern): ${transcriptResponse.statusCode}';
            }
            
            // If failed, wait a bit before retry
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          } catch (e) {
            lastError = 'youtubei err: $e';
          }
        }
      } else {
        lastError = 'no panel params';
      }
      
      // Method 1b: If extracted params failed, try player API to get fresh caption URL
      if (lastError.isNotEmpty && !lastError.contains('segments')) {
        try {
          // Use innertube player API to get fresh caption tracks
          final playerResponse = await http.post(
            Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Origin': 'https://www.youtube.com',
            },
            body: '{"context":{"client":{"clientName":"WEB","clientVersion":"2.20231219.04.00","hl":"en"}},"videoId":"$videoId"}',
          );
          
          if (playerResponse.statusCode == 200) {
            // Extract caption URL from player response
            final captionMatch = RegExp(
              r'"captionTracks":\s*\[\s*\{[^}]*"baseUrl"\s*:\s*"([^"]+)"',
            ).firstMatch(playerResponse.body);
            
            if (captionMatch != null) {
              final freshCaptionUrl = _decodeUnicodeEscapes(captionMatch.group(1)!);
              // Add format parameter
              // Try without format first (default XML), then with json3
              for (final fmt in ['', '&fmt=json3']) {
                var urlToTry = freshCaptionUrl;
                if (fmt.isNotEmpty && !urlToTry.contains('fmt=')) {
                  urlToTry = '$urlToTry$fmt';
                }
                
                final captionResponse = await http.get(
                  Uri.parse(urlToTry),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  },
                );
                
                if (captionResponse.statusCode == 200 && captionResponse.body.isNotEmpty) {
                  // Try XML parsing first
                  final xmlSegments = _parseTranscriptXmlWithTimestamps(captionResponse.body);
                  if (xmlSegments.isNotEmpty) {
                    return (xmlSegments, 'player-xml: ${xmlSegments.length} segments');
                  }
                  // Try JSON parsing
                  final segments = _parseTranscriptJson(captionResponse.body);
                  if (segments.isNotEmpty) {
                    return (segments, 'player-json: ${segments.length} segments');
                  }
                }
              }
              // Debug: show sample of what we got
              final debugResponse = await http.get(Uri.parse(freshCaptionUrl));
              final sample = debugResponse.body.length > 80 
                  ? debugResponse.body.substring(0, 80) 
                  : debugResponse.body;
              lastError = '$lastError | player:0segs($sample)';
            } else {
              lastError = '$lastError | player:no-cap';
            }
          } else {
            lastError = '$lastError | player:${playerResponse.statusCode}';
          }
        } catch (e) {
          lastError = '$lastError | player:err';
        }
      }
      
      // Store youtubei result before trying timedtext
      final youtubeiResult = lastError;
      
      // Method 2: Try timedtext URLs as fallback
      final urlsToTry = <String>[
        captionUrl,  // Original extracted URL
        'https://www.youtube.com/api/timedtext?v=$videoId&lang=en&fmt=srv3',
      ];
      
      for (final baseUrl in urlsToTry) {
        try {
          final response = await http.get(
            Uri.parse(baseUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': '*/*',
              'Referer': 'https://www.youtube.com/watch?v=$videoId',
            },
          );
          
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            successBody = response.body;
            usedMethod = 'timedtext';
            break;
          } else {
            lastError = '$youtubeiResult | tt:${response.body.length}';
          }
        } catch (e) {
          lastError = 'timedtext err';
          continue;
        }
      }
      
      if (successBody == null || successBody.isEmpty) {
        // Show URL debug info to help diagnose
        return (<TranscriptSegment>[], 'all methods failed ($lastError)');
      }
      
      // Parse transcript - try XML first, then JSON
      var segments = _parseTranscriptXmlWithTimestamps(successBody);
      
      // If XML parsing failed, try JSON parsing
      if (segments.isEmpty && successBody.startsWith('{')) {
        segments = _parseTranscriptJson(successBody);
      }
      
      if (segments.isEmpty) {
        final bodyLen = successBody.length;
        final sample = bodyLen > 100 ? successBody.substring(0, 100) : successBody;
        return (<TranscriptSegment>[], 'no segments (len=$bodyLen). Sample: $sample');
      }
      
      return (segments, '$usedMethod: ${segments.length} segments');
    } catch (e) {
      return (<TranscriptSegment>[], 'exception: ${e.toString().substring(0, 50.clamp(0, e.toString().length))}');
    }
  }
  
  /// Parse YouTube transcript XML keeping timestamps
  List<TranscriptSegment> _parseTranscriptXmlWithTimestamps(String xml) {
    final segments = <TranscriptSegment>[];
    
    // Try multiple regex patterns to handle different YouTube XML formats
    
    // Pattern 1: Standard format <text start="123.45" dur="1.23">content</text>
    var textMatches = RegExp(
      r'<text\s+start="([^"]+)"[^>]*>(.*?)</text>',
      dotAll: true,
    ).allMatches(xml);
    
    // Pattern 2: If attributes are in different order or format
    if (textMatches.isEmpty) {
      textMatches = RegExp(
        r'<text[^>]*\sstart="([^"]+)"[^>]*>(.*?)</text>',
        dotAll: true,
      ).allMatches(xml);
    }
    
    // Pattern 3: More permissive - any text element with start attribute
    if (textMatches.isEmpty) {
      textMatches = RegExp(
        r'<text[^>]*start="(\d+\.?\d*)"[^>]*>(.*?)</text>',
        dotAll: true,
      ).allMatches(xml);
    }
    
    for (final match in textMatches) {
      final startStr = match.group(1) ?? '0';
      final startSeconds = double.tryParse(startStr) ?? 0;
      var text = match.group(2) ?? '';
      text = _decodeHtml(text);
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (text.isNotEmpty) {
        segments.add(TranscriptSegment(text: text, startSeconds: startSeconds));
      }
    }
    
    return segments;
  }
  
  /// Parse YouTube transcript JSON format (json3)
  List<TranscriptSegment> _parseTranscriptJson(String json) {
    final segments = <TranscriptSegment>[];
    
    try {
      // YouTube json3 format has events with segs containing utf8 text
      // Look for patterns like "tOffsetMs":123,"segs":[{"utf8":"text"}]
      final eventMatches = RegExp(
        r'"tOffsetMs"\s*:\s*(\d+).*?"segs"\s*:\s*\[(.*?)\]',
        dotAll: true,
      ).allMatches(json);
      
      for (final match in eventMatches) {
        final offsetMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        final startSeconds = offsetMs / 1000.0;
        final segsJson = match.group(2) ?? '';
        
        // Extract utf8 text from segs
        final textParts = <String>[];
        final utf8Matches = RegExp(r'"utf8"\s*:\s*"([^"]*)"').allMatches(segsJson);
        for (final tm in utf8Matches) {
          var text = tm.group(1) ?? '';
          text = _decodeUnicodeEscapes(text);
          text = _decodeHtml(text);
          if (text.isNotEmpty && text != '\n') {
            textParts.add(text);
          }
        }
        
        if (textParts.isNotEmpty) {
          final combinedText = textParts.join('').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (combinedText.isNotEmpty) {
            segments.add(TranscriptSegment(text: combinedText, startSeconds: startSeconds));
          }
        }
      }
    } catch (_) {
      // JSON parsing failed
    }
    
    return segments;
  }
  
  /// Build base64 params for YouTube transcript API
  /// Build transcript params for YouTube API
  /// Based on youtube-transcript library approach
  String _buildTranscriptParams(String videoId, {String lang = 'en'}) {
    // The params are a base64-encoded protobuf structure
    // Structure: \n + length + videoId + \x12 + length + "asr" + \x1a + length + lang
    // This requests auto-generated captions in the specified language
    
    final videoIdBytes = videoId.codeUnits;
    final langBytes = lang.codeUnits;
    const asr = 'asr'; // Auto-generated subtitles
    
    // Build the protobuf-like structure
    final buffer = <int>[
      0x0a, // Field 1 (video ID)
      videoIdBytes.length,
      ...videoIdBytes,
      0x12, // Field 2 (track kind)
      asr.length,
      ...asr.codeUnits,
      0x1a, // Field 3 (language)
      langBytes.length,
      ...langBytes,
    ];
    
    // Wrap in outer container
    final outer = <int>[
      0x0a, // Field 1
      buffer.length,
      ...buffer,
    ];
    
    // Base64 encode
    return base64Encode(outer);
  }
  
  /// Parse YouTube's internal transcript API response
  List<TranscriptSegment> _parseYouTubeiTranscript(String json) {
    final segments = <TranscriptSegment>[];
    
    try {
      // YouTubei transcript response has structure like:
      // actions[].updateEngagementPanelAction.content.transcriptRenderer
      //   .content.transcriptSearchPanelRenderer.body.transcriptSegmentListRenderer
      //   .initialSegments[].transcriptSegmentRenderer
      
      // Look for transcriptSegmentRenderer entries with timestamps
      final segmentMatches = RegExp(
        r'"transcriptSegmentRenderer"\s*:\s*\{[^}]*"startMs"\s*:\s*"?(\d+)"?[^}]*"snippet"\s*:\s*\{[^}]*"text"\s*:\s*"([^"]+)"',
        dotAll: true,
      ).allMatches(json);
      
      for (final match in segmentMatches) {
        final startMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        final text = _decodeUnicodeEscapes(match.group(2) ?? '');
        if (text.isNotEmpty) {
          segments.add(TranscriptSegment(
            text: _decodeHtml(text),
            startSeconds: startMs / 1000.0,
          ),);
        }
      }
      
      // Alternative pattern - sometimes the structure is different
      if (segments.isEmpty) {
        final altMatches = RegExp(
          r'"cueGroupRenderer".*?"simpleText"\s*:\s*"([^"]+)".*?"startOffset"\s*:\s*"?(\d+)"?',
          dotAll: true,
        ).allMatches(json);
        
        for (final match in altMatches) {
          final text = _decodeUnicodeEscapes(match.group(1) ?? '');
          final startMs = int.tryParse(match.group(2) ?? '0') ?? 0;
          if (text.isNotEmpty) {
            segments.add(TranscriptSegment(
              text: _decodeHtml(text),
              startSeconds: startMs / 1000.0,
            ),);
          }
        }
      }
    } catch (_) {
      // Parsing failed
    }
    
    return segments;
  }
  
  /// Build directions by slicing transcript based on chapter timestamps
  List<String> _buildDirectionsFromChapters(
    List<YouTubeChapter> chapters,
    List<TranscriptSegment> segments,
  ) {
    final directions = <String>[];
    
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final nextChapterStart = i + 1 < chapters.length 
          ? chapters[i + 1].startSeconds 
          : double.infinity;
      
      // Get transcript segments for this chapter
      final chapterSegments = segments.where((s) =>
          s.startSeconds >= chapter.startSeconds &&
          s.startSeconds < nextChapterStart,
      ).toList();
      
      if (chapterSegments.isEmpty) {
        // No transcript for this chapter, just use title
        directions.add(chapter.title);
        continue;
      }
      
      // Combine segment text
      var text = chapterSegments.map((s) => s.text).join(' ');
      
      // Clean up the text
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Capitalize first letter
      if (text.isNotEmpty) {
        text = text[0].toUpperCase() + text.substring(1);
      }
      
      // Add period if missing
      if (text.isNotEmpty && !text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?')) {
        text = '$text.';
      }
      
      directions.add(text);
    }
    
    return directions;
  }

  /// Fetch YouTube transcript/captions (legacy - keeping for compatibility)
  Future<List<String>> _fetchYouTubeTranscript(String videoId, String pageBody) async {
    try {
      // Find the captions track URL in the page response
      // YouTube embeds caption data in the initial page load
      final captionTrackMatch = RegExp(
        r'"captionTracks":\s*\[(.*?)\]',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (captionTrackMatch == null) {
        return [];
      }
      
      final captionTracksJson = '[${captionTrackMatch.group(1)}]';
      
      // Find English captions (prefer manual over auto-generated)
      String? captionUrl;
      try {
        // Extract baseUrl for English captions
        // Look for English manual captions first
        var urlMatch = RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"vssId":\s*"\.en"').firstMatch(captionTracksJson);
        // Fall back to auto-generated English
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"vssId":\s*"a\.en"').firstMatch(captionTracksJson);
        // Fall back to any English variant
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"languageCode":\s*"en"').firstMatch(captionTracksJson);
        // Fall back to first available track
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"').firstMatch(captionTracksJson);
        
        if (urlMatch != null) {
          captionUrl = _decodeUnicodeEscapes(urlMatch.group(1)!);
        }
      } catch (_) {
        return [];
      }
      
      if (captionUrl == null) return [];
      
      // Fetch the caption track
      final captionResponse = await http.get(
        Uri.parse(captionUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (captionResponse.statusCode != 200) return [];
      
      // Parse the XML transcript
      final transcript = _parseYouTubeTranscriptXml(captionResponse.body);
      
      // Convert transcript to recipe directions
      return _extractDirectionsFromTranscript(transcript);
    } catch (_) {
      return [];
    }
  }
  
  /// Parse YouTube transcript XML format
  List<String> _parseYouTubeTranscriptXml(String xml) {
    final segments = <String>[];
    
    // Extract text from <text> elements
    final textMatches = RegExp(r'<text[^>]*>([^<]*)</text>').allMatches(xml);
    
    for (final match in textMatches) {
      var text = match.group(1) ?? '';
      // Decode HTML entities
      text = _decodeHtml(text);
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        segments.add(text);
      }
    }
    
    return segments;
  }
  
  /// Extract recipe directions from transcript segments
  List<String> _extractDirectionsFromTranscript(List<String> segments) {
    if (segments.isEmpty) return [];
    
    // Combine segments into larger chunks (captions are often fragmented)
    final combinedText = segments.join(' ');
    
    // Split into sentences
    final sentences = combinedText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    
    // Filter to keep only sentences that look like cooking instructions
    final directions = <String>[];
    
    for (final sentence in sentences) {
      // Skip very short sentences (likely fragments)
      if (sentence.length < 15) continue;
      
      // Skip sentences that are clearly not instructions
      if (RegExp(r'\b(subscribe|comment|like|share|video|channel|patreon|sponsor)\b', caseSensitive: false).hasMatch(sentence)) {
        continue;
      }
      
      // Keep sentences with cooking-related content
      if (_looksLikeCookingInstruction(sentence)) {
        // Clean up the sentence
        var cleaned = sentence;
        // Capitalize first letter
        if (cleaned.isNotEmpty) {
          cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
        }
        // Ensure it ends with punctuation
        if (!RegExp(r'[.!?]$').hasMatch(cleaned)) {
          cleaned += '.';
        }
        directions.add(cleaned);
      }
    }
    
    // Limit to reasonable number of steps
    if (directions.length > 20) {
      // Try to consolidate into larger steps
      return _consolidateDirections(directions);
    }
    
    return directions;
  }
  
  bool _looksLikeCookingInstruction(String text) {
    final lower = text.toLowerCase();
    
    // Contains cooking verbs
    if (RegExp(r'\b(add|mix|stir|cook|heat|bake|roast|fry|boil|simmer|chop|dice|slice|cut|pour|combine|whisk|fold|season|taste|serve|place|put|remove|transfer|let|allow|wait|set|cover|preheat|refrigerate|chill|freeze)\b').hasMatch(lower)) {
      return true;
    }
    
    // Contains cooking equipment
    if (RegExp(r'\b(pan|pot|oven|bowl|skillet|baking|sheet|tray|blender|processor|mixer|whisk|spatula|knife|cutting board|thermometer)\b').hasMatch(lower)) {
      return true;
    }
    
    // Contains temperature or time references
    if (RegExp(r'\b(\d+\s*(?:degrees|°|minutes|mins|hours|hrs|seconds|secs))\b').hasMatch(lower)) {
      return true;
    }
    
    return false;
  }
  
  List<String> _consolidateDirections(List<String> directions) {
    // Group related directions into larger steps
    final consolidated = <String>[];
    var current = <String>[];
    
    for (final dir in directions) {
      current.add(dir);
      // Start a new step after ~3 sentences or when hitting a natural break
      if (current.length >= 3 || 
          RegExp(r'\b(then|next|now|after|finally|lastly)\b', caseSensitive: false).hasMatch(dir)) {
        consolidated.add(current.join(' '));
        current = [];
      }
    }
    
    if (current.isNotEmpty) {
      consolidated.add(current.join(' '));
    }
    
    return consolidated;
  }

  /// Legacy method for backwards compatibility - returns Recipe directly
  Future<Recipe?> importRecipeFromUrl(String url) async {
    final result = await importFromUrl(url);
    return result.toRecipe(_uuid.v4());
  }

  /// Check if text looks like binary, base64, or other encoded data
  /// This helps filter out garbage content from images, SVGs, or encoded scripts
  bool _looksLikeBinaryOrEncoded(String text) {
    // Check for high concentration of non-printable or unusual characters
    // (characters outside normal text range)
    int unusualCharCount = 0;
    for (final rune in text.runes) {
      // Characters outside printable ASCII range (excluding common Unicode letters)
      if ((rune < 32 && rune != 10 && rune != 13) || // control chars
          (rune > 126 && rune < 160) || // extended ASCII control
          (rune > 65535)) { // very high unicode
        unusualCharCount++;
      }
    }
    // If more than 5% unusual characters, it's likely binary
    if (unusualCharCount > text.length * 0.05) return true;
    
    // Check for base64 patterns (long strings without spaces)
    final wordsWithoutSpaces = text.split(RegExp(r'\s+'));
    for (final word in wordsWithoutSpaces) {
      // Very long "words" without spaces are likely encoded data
      if (word.length > 50 && !word.contains('http')) return true;
    }
    
    // Check for common encoded data markers
    if (text.contains('data:') ||
        text.contains('base64') ||
        text.contains('svg+xml') ||
        RegExp(r'[A-Za-z0-9+/]{60,}={1,2}$').hasMatch(text)) { // base64 pattern with trailing =
      return true;
    }
    
    return false;
  }

  /// Check if a string is a valid ingredient candidate
  bool _isValidIngredientCandidate(String text) {
    if (text.isEmpty || text.length < 5 || text.length > 150) return false;
    if (_looksLikeBinaryOrEncoded(text)) return false;
    
    final lower = text.toLowerCase();
    // Skip navigation/UI elements
    if (lower.contains('subscribe') ||
        lower.contains('http') ||
        lower.contains('click') ||
        lower.contains('menu') ||
        lower.contains('instagram') ||
        lower.contains('facebook') ||
        lower.contains('newsletter') ||
        lower.contains('function') ||
        lower.contains('script') ||
        lower.contains('copyright') ||
        lower.contains('privacy') ||
        lower.contains('cookie')) {
      return false;
    }
    
    return true;
  }

  /// Decode HTML entities and normalise text
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
    // Use _extractRawIngredients first to rejoin incorrectly split ingredients (e.g., Diffords comma splits)
    final rawIngredientStrings = _extractRawIngredients(data['recipeIngredient']);
    var ingredients = _parseIngredients(rawIngredientStrings);
    ingredients = _sortIngredientsByQuantity(ingredients);

    // Parse nutrition information if available
    final nutrition = _parseNutrition(data['nutrition']);

    // Determine course with drink detection
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    
    // For drinks, detect the base spirit and set as subcategory
    String? subcategory;
    if (course == 'Drinks') {
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
    // Use _extractRawIngredients first to rejoin incorrectly split ingredients (e.g., Diffords comma splits)
    // Support both JSON-LD format (recipeIngredient) and non-standard format (ingredients)
    var rawIngredientStrings = _extractRawIngredients(data['recipeIngredient']);
    // Fallback to non-standard keys if JSON-LD key not found
    if (rawIngredientStrings.isEmpty) {
      rawIngredientStrings = _extractRawIngredients(data['ingredients']);
    }
    // Parse from the already-rejoined raw strings, not the original JSON-LD
    var ingredients = _parseIngredients(rawIngredientStrings);
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
    // Support both JSON-LD format (recipeInstructions) and non-standard format (instructions)
    var directions = _parseInstructions(data['recipeInstructions']);
    var rawDirections = _extractRawDirections(data['recipeInstructions']);
    // Fallback to non-standard keys if JSON-LD key not found
    if (directions.isEmpty) {
      directions = _parseInstructions(data['instructions']);
      rawDirections = _extractRawDirections(data['instructions']);
    }
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
    
    // Extract equipment from JSON-LD 'tool' field or look for equipment in description/keywords
    final equipmentList = _extractEquipmentFromJsonLd(data);

    // For drinks, detect the base spirit
    String? subcategory;
    if (course == 'Drinks') {
      subcategory = _detectSpirit(ingredients);
      if (subcategory != null) {
        subcategory = Spirit.toDisplayName(subcategory);
      }
    }

    // Create raw ingredient data, filtering out empty entries
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      final bakerPct = _extractBakerPercent(raw);
      
      // For section-only items (parsed name is empty but has section),
      // keep the empty name so the review screen can display it as a section header
      final isSectionOnly = parsed.name.isEmpty && parsed.section != null;
      
      // Clean the fallback raw string by removing footnote markers (*, †, [1], etc.)
      final cleanedRaw = raw.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
      
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        preparation: parsed.preparation,
        bakerPercent: bakerPct != null ? '$bakerPct%' : null,
        name: isSectionOnly ? '' : (parsed.name.isNotEmpty ? parsed.name : cleanedRaw),
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    })
    // Filter out empty entries - must have alphanumeric in name OR have a section
    .where((i) => (i.name.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(i.name)) || i.sectionName != null)
    .toList();

    // Build notes - combine description with editor's note if present
    String notes = _decodeHtml(_parseString(data['description']) ?? '');
    // Check for editor's note in meta (Punch style)
    final meta = data['meta'];
    if (meta is Map) {
      final editorsNote = _parseString(meta['editors_note'] ?? meta['editorsNote']);
      if (editorsNote != null && editorsNote.isNotEmpty) {
        final editorNoteText = "Editor's Note: ${_decodeHtml(editorsNote)}";
        notes = notes.isNotEmpty ? '$notes\n\n$editorNoteText' : editorNoteText;
      }
    }
    
    return RecipeImportResult(
      name: name.isNotEmpty ? name : null,
      course: course,
      cuisine: cuisine,
      subcategory: subcategory,
      serves: serves,
      time: time,
      ingredients: ingredients,
      directions: directions,
      equipment: equipmentList,
      notes: notes,
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
      final result = <String>[];
      for (final item in value) {
        if (item is String) {
          final decoded = _decodeHtml(item.trim());
          if (decoded.isNotEmpty) result.add(decoded);
        } else if (item is Map) {
          // Handle nested ingredient objects
          // Saveur/WordPress ACF format: {ingredient: "name", quantity: "2", measurement: "cups"}
          if (item.containsKey('ingredient')) {
            final quantity = _parseString(item['quantity']) ?? '';
            final measurement = _parseString(item['measurement']) ?? '';
            final ingredientName = _parseString(item['ingredient']) ?? '';
            if (ingredientName.isNotEmpty) {
              final parts = <String>[];
              if (quantity.isNotEmpty) parts.add(quantity);
              if (measurement.isNotEmpty) parts.add(measurement);
              parts.add(ingredientName);
              result.add(_decodeHtml(parts.join(' ').trim()));
            }
          }
          // Saveur/WordPress ACF format with sections: {title: "Section", items: [...]} 
          // Items can contain {ingredient, quantity, measurement} objects
          else if (item.containsKey('items')) {
            final sectionTitle = _parseString(item['title'] ?? item['section_title']) ?? '';
            if (sectionTitle.isNotEmpty) {
              result.add('[$sectionTitle]'); // Add section header
            }
            final items = item['items'] ?? item['section_items'];
            if (items is List) {
              for (final subItem in items) {
                if (subItem is Map) {
                  // Handle {ingredient, quantity, measurement} format within items
                  if (subItem.containsKey('ingredient')) {
                    final quantity = _parseString(subItem['quantity']) ?? '';
                    final measurement = _parseString(subItem['measurement']) ?? '';
                    final ingredientName = _parseString(subItem['ingredient']) ?? '';
                    if (ingredientName.isNotEmpty) {
                      final parts = <String>[];
                      if (quantity.isNotEmpty) parts.add(quantity);
                      if (measurement.isNotEmpty) parts.add(measurement);
                      parts.add(ingredientName);
                      result.add(_decodeHtml(parts.join(' ').trim()));
                    }
                  } else {
                    // Fallback: try text/name field
                    final text = _parseString(subItem['text'] ?? subItem['name']) ?? '';
                    if (text.isNotEmpty) result.add(_decodeHtml(text));
                  }
                } else if (subItem is String) {
                  final decoded = _decodeHtml(subItem.trim());
                  if (decoded.isNotEmpty) result.add(decoded);
                }
              }
            }
          }
          // Standard JSON-LD or generic format with text field
          else {
            final text = _parseString(item['text'] ?? item['name']) ?? '';
            if (text.isNotEmpty) {
              result.add(_decodeHtml(text.trim()));
            }
          }
        } else {
          final decoded = _decodeHtml(item.toString().trim());
          if (decoded.isNotEmpty) result.add(decoded);
        }
      }
      
      // Post-process to rejoin incorrectly split ingredients
      // Some sites (like Diffords) incorrectly split ingredients on commas in their JSON-LD,
      // resulting in fragments like "(2", "1", ")" instead of "(2 sugar to 1 water, 65.0°Brix)"
      var items = _rejoinSplitIngredients(result);
      
      // Deduplicate ingredients (some sites like Saveur have same ingredient in HTML multiple times)
      items = _deduplicateIngredients(items);
      
      return items;
    }
    return [];
  }
  
  /// Deduplicate a list of ingredient strings while preserving order
  /// Some sites (like Saveur with MUI components) have the same ingredient in HTML multiple times
  /// This is section-aware: resets the "seen" set at each section header so legitimately
  /// repeated ingredients in different sections (e.g., "2 eggs" for cake and for creme anglaise)
  /// are preserved
  List<String> _deduplicateIngredients(List<String> items) {
    var seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      // Check if this is a section header - if so, reset the seen set
      // Section headers are formatted as [Section Name] or end with ":"
      final trimmed = item.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        seen = <String>{}; // Reset for new section
        result.add(item);
        continue;
      }
      if (trimmed.endsWith(':') && trimmed.length < 50 && !RegExp(r'\d').hasMatch(trimmed)) {
        // Looks like a section header (e.g., "For the filling:")
        seen = <String>{}; // Reset for new section
        result.add(item);
        continue;
      }
      
      // Normalize for comparison: lowercase, collapse whitespace
      final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) continue;
      if (seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(item);
    }
    return result;
  }
  
  /// Rejoin ingredient items that were incorrectly split (usually on commas)
  /// Detects fragments like "(2", "1", ")" and rejoins them with the previous complete ingredient
  List<String> _rejoinSplitIngredients(List<String> items) {
    if (items.length <= 1) return items;
    
    final result = <String>[];
    var buffer = '';
    int openParens = 0;
    
    for (final item in items) {
      // Count parentheses
      final openCount = item.split('(').length - 1;
      final closeCount = item.split(')').length - 1;
      
      // Check if this looks like a fragment that should be rejoined:
      // 1. Very short (like "1", ")", "(2")
      // 2. Just numbers, punctuation, degree symbols
      // 3. Just a parenthesis
      // 4. Starts with a number but no unit (like "65.0°Brix)" - partial measurement)
      // 5. We're currently inside unbalanced parentheses
      final looksLikeFragment = 
          item.length <= 3 ||
          RegExp(r'^[\d.,°\s]+$').hasMatch(item) ||
          RegExp(r'^[()]$').hasMatch(item) ||
          RegExp(r'^\d+\.?\d*°').hasMatch(item) ||  // Starts with degree measurement like "65.0°Brix"
          (item.startsWith(')') && buffer.isNotEmpty) ||  // Starts with closing paren
          (buffer.isNotEmpty && openParens > 0);
      
      // Also check if this item lacks typical ingredient structure
      // A valid ingredient usually starts with a number+unit or an ingredient name (letters)
      final lacksIngredientStructure = buffer.isNotEmpty && (
          !RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:ml|g|oz|tsp|tbsp|cup|dash|drop|cl|l|kg|lb|pound|ounce|teaspoon|tablespoon)s?\b', caseSensitive: false).hasMatch(item) &&
          !RegExp(r'^[A-Za-z][A-Za-z\s]{2,}').hasMatch(item) &&
          item.length < 15
      );
      
      if (buffer.isEmpty) {
        buffer = item;
        openParens = openCount - closeCount;
      } else if (looksLikeFragment || openParens > 0 || lacksIngredientStructure) {
        // This is a continuation - rejoin with comma (since that's likely how it was split)
        buffer = '$buffer, $item';
        openParens += openCount - closeCount;
      } else {
        // This is a new complete ingredient
        result.add(buffer);
        buffer = item;
        openParens = openCount - closeCount;
      }
    }
    
    // Don't forget the last item
    if (buffer.isNotEmpty) {
      result.add(buffer);
    }
    
    return result;
  }

  /// Extract equipment from JSON-LD data
  /// Schema.org Recipe can have 'tool' field for equipment
  List<String> _extractEquipmentFromJsonLd(Map data) {
    final equipment = <String>[];
    
    // Check 'tool' field (schema.org standard)
    final tool = data['tool'];
    if (tool != null) {
      if (tool is String && tool.isNotEmpty) {
        equipment.add(_decodeHtml(tool));
      } else if (tool is List) {
        for (final item in tool) {
          if (item is String && item.isNotEmpty) {
            equipment.add(_decodeHtml(item));
          } else if (item is Map) {
            final name = _parseString(item['name']) ?? _parseString(item['text']);
            if (name != null && name.isNotEmpty) {
              equipment.add(_decodeHtml(name));
            }
          }
        }
      }
    }
    
    // Check 'recipeEquipment' (non-standard but used by some sites)
    final recipeEquipment = data['recipeEquipment'];
    if (recipeEquipment != null) {
      if (recipeEquipment is String && recipeEquipment.isNotEmpty) {
        equipment.add(_decodeHtml(recipeEquipment));
      } else if (recipeEquipment is List) {
        for (final item in recipeEquipment) {
          if (item is String && item.isNotEmpty) {
            equipment.add(_decodeHtml(item));
          } else if (item is Map) {
            final name = _parseString(item['name']) ?? _parseString(item['text']);
            if (name != null && name.isNotEmpty) {
              equipment.add(_decodeHtml(name));
            }
          }
        }
      }
    }
    
    return equipment;
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
    if (allText.contains('drink') || allText.contains('cocktail') || allText.contains('beverage')) courses.add('Drinks');
    
    // Only add Veg'n if category explicitly mentions it (not just keywords like "Vegan" which are often dietary info)
    if (category.contains('vegetarian') || category.contains('vegan')) courses.add("Veg'n");
    
    // Always include Mains as default option
    if (courses.isEmpty) courses.add('Mains');
    
    return courses.toList()..sort();
  }

  /// Detect all possible cuisines from recipe data
  /// Only uses the recipeCuisine field - doesn't infer from keywords/name to avoid false positives
  List<String> _detectAllCuisines(Map data) {
    final cuisines = <String>{};
    final cuisine = _parseString(data['recipeCuisine'])?.toLowerCase() ?? '';
    if (cuisine.isEmpty) return [];
    
    // Check for cuisine indicators
    final cuisineIndicators = {
      'french': 'France', 'italian': 'Italy', 'spanish': 'Spain',
      'mexican': 'Mexico', 'chinese': 'China', 'japanese': 'Japan',
      'korean': 'Korea', 'thai': 'Thailand', 'vietnamese': 'Vietnam',
      'indian': 'India', 'greek': 'Greece', 'mediterranean': 'Mediterranean',
      'middle eastern': 'Middle East', 'moroccan': 'Morocco',
      'caribbean': 'Caribbean', 'brazilian': 'Brazil',
    };
    
    cuisineIndicators.forEach((indicator, cuisineName) {
      if (cuisine.contains(indicator)) {
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
    
    String? raw;
    if (value is String) {
      raw = _decodeHtml(value);
    } else if (value is num) {
      return value.toString();
    } else if (value is List && value.isNotEmpty) {
      raw = _decodeHtml(value.first.toString());
    }
    
    if (raw == null) return null;
    
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

  /// Parse cuisine - convert region names to country names
  String? _parseCuisine(dynamic value) {
    if (value == null) return null;
    
    final cuisine = _parseString(value);
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Map regions to countries
    final regionToCountry = {
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

  /// Convert text to Title Case (capitalize first letter of each word)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Keep short words lowercase unless they're the first word
      final lower = word.toLowerCase();
      if (lower == 'a' || lower == 'an' || lower == 'the' || lower == 'of' || 
          lower == 'in' || lower == 'on' || lower == 'at' || lower == 'to' ||
          lower == 'for' || lower == 'and' || lower == 'or' || lower == 'with') {
        return lower;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList().asMap().entries.map((e) {
      // Always capitalize first word
      if (e.key == 0 && e.value.isNotEmpty) {
        return e.value[0].toUpperCase() + e.value.substring(1);
      }
      return e.value;
    }).join(' ');
  }

  /// Normalize serves/yield string - strip common prefixes like "Servings: ", "Serves ", etc.
  String _normalizeServes(String text) {
    var cleaned = text.trim();
    // Strip common prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:Servings?|Serves?|Yield|Makes?)\s*:?\s*', caseSensitive: false), '');
    // Strip trailing labels like "servings" from "4 servings"
    cleaned = cleaned.replaceFirst(RegExp(r'\s+(?:servings?|portions?)$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Split garnish text intelligently - handles "X or Y" as separate items
  /// e.g., "orange or lemon peel" becomes ["Orange Peel", "Lemon Peel"]
  List<String> _splitGarnishText(String text) {
    if (text.isEmpty) return [];
    
    // First split by comma
    final commaSplit = text.split(RegExp(r',\s*'));
    final result = <String>[];
    
    for (final part in commaSplit) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Check for "X or Y" pattern where they share a common suffix
      // e.g., "orange or lemon peel" -> "orange peel", "lemon peel"
      final orMatch = RegExp(r'^(.+?)\s+or\s+(.+)$', caseSensitive: false).firstMatch(trimmed);
      if (orMatch != null) {
        final firstPart = orMatch.group(1)?.trim() ?? '';
        final secondPart = orMatch.group(2)?.trim() ?? '';
        
        // Check if second part has a suffix that should apply to first
        // e.g., "orange or lemon peel" - "peel" is the shared suffix
        final words = secondPart.split(' ');
        if (words.length > 1) {
          // Assume last word(s) are shared suffix
          final lastWord = words.last;
          // Check if first part is missing the suffix type word
          if (!firstPart.toLowerCase().contains(lastWord.toLowerCase())) {
            // Add the suffix to the first option
            result.add('$firstPart $lastWord');
            result.add(secondPart);
          } else {
            // Both are complete, add separately
            result.add(firstPart);
            result.add(secondPart);
          }
        } else {
          // Simple "X or Y" - both are complete items
          result.add(firstPart);
          result.add(secondPart);
        }
      } else {
        result.add(trimmed);
      }
    }
    
    return result.where((s) => s.isNotEmpty).toList();
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
      return _formatMinutes(totalMinutes);
    }
    
    return null;
  }

  int _parseDurationMinutes(dynamic value) {
    if (value == null) return 0;
    final str = value.toString().toLowerCase().trim();
    
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
    final str = value.toString();
    
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

  /// Format minutes as compact days/hours/minutes (e.g., 380 -> 6 hr 20 min)
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
    // Common patterns: "For the sauce:", "Sauce:", "Main Ingredients:", "[Section]", etc.
    String? currentSection;
    final result = <Ingredient>[];
    
    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;
      
      // First check for bracketed section format [Section Name] from _processIngredientListItems
      final bracketMatch = RegExp(r'^\[(.+)\]$').firstMatch(decoded);
      if (bracketMatch != null) {
        currentSection = bracketMatch.group(1)?.trim();
        continue;  // Skip to next item - this was just a section header
      }
      
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
            ),);
          } else {
            result.add(ingredient);
          }
        }
      }
    }
    
    return result;
  }

  /// Extract baker's percentage from ingredient string if present
  /// Returns the percentage value (e.g., "100", "75", "3.3") or null
  String? _extractBakerPercent(String text) {
    final match = RegExp(
      r'^[^,]+,\s*([\d.]+)%\s*[–—-]',  // en-dash, em-dash, or hyphen
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  /// Parse a single ingredient string into structured data
  Ingredient _parseIngredientString(String text) {
    var remaining = text;
    bool isOptional = false;
    final List<String> notesParts = [];
    String? amount;
    String? inlineSection;
    
    // Handle "Top up with [Ingredient]" format (Difford's style)
    // e.g., "Top up with Thomas Henry Soda Water" -> name: "Thomas Henry Soda Water", amount: "Top"
    final topUpWithMatch = RegExp(
      r'^Top\s+(?:up\s+)?with\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (topUpWithMatch != null) {
      final name = topUpWithMatch.group(1)?.trim() ?? '';
      return Ingredient.create(
        name: name,
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
        name: name,
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
        name: name,
        amount: amount,
        preparation: notes,
        bakerPercent: bakerPercent != null ? '$bakerPercent%' : null,
      );
    }
    
    // Handle "Name, amount unit (notes)" format
    // e.g., "00 Flour, 300g (10.5 oz. or about 2 Cups)"
    // e.g., "Egg Yolks, 5 each"
    // e.g., "Fine Sea Salt, 1/4 tsp. (or 1g)"
    // e.g., "EVOO, 1 tsp. (about 3g or 0.125 oz.)"
    final nameAmountMatch = RegExp(
      r'^([^,]+),\s*(\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?(?:\s*\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?)?)\s*(g|kg|ml|l|oz|lb|cup|cups|tbsp|tsp|each|whole|large|medium|small)?\.?\s*(?:\(([^)]+)\))?$',
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
        name: name,
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
        name: name,
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
        name: name,
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
        name: name.replaceAll(RegExp(r'\*+$'), '').trim(),
        amount: '$primaryAmt $primaryUnit',
        preparation: prepParts.join(', '),
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
      r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm)\.?)?\s+',
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
    }
    
    // Try standalone text fraction like "1/4 tsp" (without whole number)
    if (amount == null) {
      final textFractionMatch = RegExp(
        r'^(\d+/\d+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (textFractionMatch != null) {
        var fraction = textFractionMatch.group(1) ?? '';
        final unit = textFractionMatch.group(2)?.trim() ?? '';
        // Convert text fractions to unicode
        fraction = _fractionMap[fraction] ?? fraction;
        amount = fraction;
        if (unit.isNotEmpty) {
          amount = '$amount $unit';
        }
        remaining = remaining.substring(textFractionMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Handle "X to Y unit" range format (e.g., "1 to 2 teaspoons")
      final toRangeMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)\s+to\s+([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (toRangeMatch != null) {
        final start = toRangeMatch.group(1)?.trim() ?? '';
        final end = toRangeMatch.group(2)?.trim() ?? '';
        final unit = toRangeMatch.group(3)?.trim() ?? '';
        amount = '$start-$end';
        if (unit.isNotEmpty) {
          amount = '$amount $unit';
        }
        remaining = remaining.substring(toRangeMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Original pattern for simple amounts and ranges with dash/en-dash
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+|[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm)\.?)?\s+',
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
    // But don't split on commas that are inside parentheses
    int commaIndex = -1;
    int parenDepth = 0;
    for (int i = 0; i < remaining.length; i++) {
      final char = remaining[i];
      if (char == '(') parenDepth++;
      else if (char == ')') parenDepth--;
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
      name: remaining,
      amount: _normalizeFractions(amount),
      preparation: finalNotes,
      isOptional: isOptional,
      section: inlineSection,
    );
  }

  /// Normalize unit names to standard abbreviations
  /// e.g., "tablespoons" -> "Tbsp", "cups" -> "C", "teaspoons" -> "tsp"
  String _normalizeUnit(String unit) {
    final lower = unit.toLowerCase().replaceAll('.', '');
    switch (lower) {
      case 'cup':
      case 'cups':
        return 'C';
      case 'tablespoon':
      case 'tablespoons':
      case 'tbsp':
        return 'Tbsp';
      case 'teaspoon':
      case 'teaspoons':
      case 'tsp':
        return 'tsp';
      case 'ounce':
      case 'ounces':
      case 'oz':
        return 'oz';
      case 'pound':
      case 'pounds':
      case 'lb':
      case 'lbs':
        return 'lb';
      case 'gram':
      case 'grams':
      case 'g':
        return 'g';
      case 'kilogram':
      case 'kilograms':
      case 'kg':
        return 'kg';
      case 'milliliter':
      case 'milliliters':
      case 'ml':
        return 'ml';
      case 'liter':
      case 'liters':
      case 'l':
        return 'L';
      default:
        return unit;
    }
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
    
    // Don't sort if there are section headers - preserve original order
    // Section headers are ingredients with empty name but non-null section
    final hasSectionHeaders = ingredients.any((i) => i.name.isEmpty && i.section != null);
    if (hasSectionHeaders) {
      return ingredients; // Preserve original order when sections are present
    }
    
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
    var category = _parseString(data['recipeCategory'])?.toLowerCase();
    
    // Also check WordPress/Next.js nested category format: categories.nodes[].name
    final categoriesData = data['categories'];
    if (categoriesData is Map && categoriesData['nodes'] is List) {
      final categoryNames = (categoriesData['nodes'] as List)
          .whereType<Map>()
          .map((node) => _parseString(node['name'])?.toLowerCase() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      // Check for drink/cocktail category directly in nested categories
      if (categoryNames.any((c) => c.contains('drink') || c.contains('cocktail') || c.contains('beverage') || c == 'spirits' || c.contains('amaro'))) {
        return 'Drinks';
      }
      // If no standard category, use the nested categories for detection
      if (category == null || category.isEmpty) {
        category = categoryNames.join(' ');
      }
    }
    
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final description = _parseString(data['description'])?.toLowerCase() ?? '';
    final allText = '$category $keywords $name $description';
    
    // Check if this is from a cocktail site
    if (sourceUrl != null && _isCocktailSite(sourceUrl)) {
      return 'Drinks';
    }
    
    // Check for drink/cocktail indicators in the data
    if (_isDrinkRecipe(category, keywords, name, description)) {
      return 'Drinks';
    }
    
    // Check for modernist/molecular gastronomy indicators
    if (sourceUrl != null && _isModernistUrl(sourceUrl)) {
      return 'Modernist';
    }
    if (_isModernistContent(allText)) {
      return 'Modernist';
    }
    
    // Check category first (most reliable)
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
    
    // Check name and keywords for specific recipe types (before dietary indicators)
    // These are more specific than vegan/vegetarian which is just a dietary restriction
    if (name.contains('bread') || name.contains('sourdough') || name.contains('focaccia') || 
        name.contains('baguette') || name.contains('ciabatta') || name.contains('brioche')) {
      return 'Breads';
    }
    if (name.contains('soup') || name.contains('stew') || name.contains('chowder')) {
      return 'Soups';
    }
    if (name.contains('cake') || name.contains('cookie') || name.contains('brownie') || 
        name.contains('pie') || name.contains('dessert')) {
      return 'Desserts';
    }
    if (name.contains('sauce') || name.contains('dressing')) {
      return 'Sauces';
    }
    if (name.contains('pizza')) {
      return 'Pizzas';
    }
    
    // Vegan/vegetarian is a dietary restriction, not a course type
    // Only use it as a fallback if no specific course was detected
    // and only if it's explicitly a vegetarian/vegan dish (in category, not just keywords)
    if (category != null && (category.contains('vegetarian') || category.contains('vegan'))) {
      return "Veg'n";
    }
    
    return 'Mains'; // Default
  }
  
  /// Check if URL indicates a modernist/molecular gastronomy site
  bool _isModernistUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('modernist') || 
           lowerUrl.contains('molecular') ||
           lowerUrl.contains('chefsteps') ||
           lowerUrl.contains('technique');
  }
  
  /// Check if content indicates modernist/molecular gastronomy
  bool _isModernistContent(String text) {
    final lower = text.toLowerCase();
    const modernistKeywords = [
      'spherification', 'gelification', 'sous vide', 'immersion circulator',
      'agar', 'xanthan', 'sodium alginate', 'calcium chloride',
      'molecular gastronomy', 'modernist cuisine', 'hydrocolloid',
      'methylcellulose', 'lecithin', 'maltodextrin', 'transglutaminase',
    ];
    
    for (final keyword in modernistKeywords) {
      if (lower.contains(keyword)) return true;
    }
    return false;
  }

  /// Check if this is a drink/cocktail recipe based on content
  bool _isDrinkRecipe(String? category, String keywords, String name, String description) {
    final allText = '${category ?? ''} $keywords $name $description'.toLowerCase();
    
    // Cocktail/drink category indicators - use word boundaries to avoid false positives
    // e.g., "sour" should not match "sourdough"
    const drinkIndicators = [
      'cocktail', 'cocktails', 'drink', 'drinks', 'beverage', 'beverages',
      'martini', 'margarita', 'mojito', 'negroni', 'manhattan', 'daiquiri',
      'old fashioned', 'old-fashioned', 'highball', 'lowball',
      'fizz', 'collins', 'spritz', 'punch', 'shooter', 'shot',
      'mocktail', 'smoothie', 'shake', 'milkshake',
    ];
    
    // Indicators that need word boundary matching (avoid false positives)
    const wordBoundaryIndicators = [
      'sour',  // Don't match "sourdough"
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
    
    // Check word-boundary indicators with regex
    for (final indicator in wordBoundaryIndicators) {
      if (RegExp(r'\b' + indicator + r'\b').hasMatch(allText)) return true;
    }
    
    // Check spirit indicators in name/description (not just category)
    // These indicate the recipe IS a spirit/liqueur, not just uses one as ingredient
    for (final spirit in spiritIndicators) {
      if (name.contains(spirit) || (category != null && category.contains(spirit))) return true;
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

    // First try standard selectors
    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient',
    );
    
    var rawIngredientStrings = <String>[];
    for (final e in ingredientElements) {
      final text = _decodeHtml((e.text ?? '').trim());
      if (text.isNotEmpty) {
        rawIngredientStrings.add(text);
      }
    }
    
    // Try section-based parsing for equipment, yield, timing (always)
    // And for ingredients if standard selectors failed
    List<String> equipmentItems = [];
    String? yield;
    String? timing;
    
    final sectionResult = _parseHtmlBySections(document);
    equipmentItems = sectionResult['equipment'] ?? [];
    yield = sectionResult['yield'];
    timing = sectionResult['timing'];
    
    if (rawIngredientStrings.isEmpty) {
      rawIngredientStrings = sectionResult['ingredients'] ?? [];
    }
    
    // Parse ingredients with proper section handling
    var ingredients = _parseIngredients(rawIngredientStrings);
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    // First try standard direction selectors
    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction',
    );
    
    var directions = <String>[];
    for (final e in instructionElements) {
      final text = _decodeHtml((e.text ?? '').trim());
      if (text.isNotEmpty) {
        directions.add(text);
      }
    }
    
    // If standard selectors failed, try step-based parsing
    if (directions.isEmpty) {
      directions = _parseDirectionsBySections(document);
    }

    if (ingredients.isEmpty && directions.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktail = _isCocktailSite(sourceUrl);
    
    // Try to detect course from content
    String course;
    if (isCocktail) {
      course = 'Drinks';
    } else if (_isModernistRecipe(document, sourceUrl, rawIngredientStrings)) {
      course = 'Modernist';
    } else {
      course = 'Mains';
    }
    
    // For drinks, detect the base spirit
    String? subcategory;
    if (isCocktail) {
      final spiritCode = _detectSpirit(ingredients);
      if (spiritCode != null) {
        subcategory = Spirit.toDisplayName(spiritCode);
      }
    }

    // Build notes from equipment if found
    String? notes;
    if (equipmentItems.isNotEmpty) {
      notes = 'Equipment: ${equipmentItems.join(', ')}';
    }

    return Recipe.create(
      uuid: _uuid.v4(),
      name: _cleanRecipeName(title),
      course: course,
      subcategory: subcategory,
      serves: yield,
      time: timing,
      ingredients: ingredients,
      directions: directions,
      notes: notes,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }

  /// Fallback HTML parsing with confidence scoring
  RecipeImportResult? _parseFromHtmlWithConfidence(dynamic document, String sourceUrl, [String? rawHtmlBody]) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim();

    var rawIngredientStrings = <String>[];
    var rawDirections = <String>[];
    List<String> equipmentItems = [];
    List<String> stepImages = []; // Images found in direction steps
    String? glassType;
    List<String> garnishItems = [];
    String? yield;
    String? timing;
    String? htmlNotes;
    bool usedStructuredFormat = false; // Flag for higher confidence when using structured recipe plugins
    
    // Check for Shopify/Lyres-style embedded HTML in JSON (recipe-info divs in product description)
    // These sites embed HTML inside JSON strings with unicode escaping (\u003c for <)
    var bodyHtml = document.outerHtml;
    
    // Decode common unicode escapes that Shopify/Lyres uses
    bodyHtml = bodyHtml
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\"', '"');
    
    // Also try the literal unicode escape format (without backslash interpretation)
    bodyHtml = bodyHtml
        .replaceAll('\\u003c', '<')
        .replaceAll('\\u003e', '>')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('\\n', ' ')
        .replaceAll('\\"', '"');
    
    // Two-step approach for Lyres/Shopify embedded HTML:
    // Step 1: Find all recipe-info div sections
    final recipeInfoDivs = RegExp(
      r'<div[^>]*class="[^"]*recipe-info[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(bodyHtml);
    
    for (final divMatch in recipeInfoDivs) {
      final divContent = divMatch.group(1) ?? '';
      
      // Step 2: Extract h4 title from this div (handles <h4 class="title">Text</h4>)
      final h4Match = RegExp(
        r'<h4[^>]*>(.*?)</h4>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(divContent);
      
      if (h4Match == null) continue;
      
      // Strip any HTML tags from the h4 content to get plain text
      final h4RawContent = h4Match.group(1) ?? '';
      final h4Title = h4RawContent.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
      
      // Extract content after h4 - try ul first, then p tags
      final afterH4 = divContent.substring(h4Match.end);
      
      if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
        // For method, collect all <p> content
        final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final pMatch in pMatches) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty && rawDirections.isEmpty) {
            // Split by periods for multiple sentences if it's a single paragraph
            if (text.contains('. ')) {
              rawDirections.addAll(text.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim() + '.'));
            } else {
              rawDirections.add(text);
            }
          }
        }
      } else if (h4Title == 'glass' || h4Title == 'glassware') {
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null && glassType == null) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) glassType = text;
        }
      } else if (h4Title == 'garnish') {
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null && garnishItems.isEmpty) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) garnishItems = _splitGarnishText(text);
        }
      } else if (h4Title == 'ingredients' && rawIngredientStrings.isEmpty) {
        // Extract li items from the ul
        final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final li in liMatches) {
          final text = _decodeHtml((li.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
    }
    
    // Fallback: try the original simpler pattern if no matches found
    if (rawIngredientStrings.isEmpty && glassType == null && garnishItems.isEmpty && rawDirections.isEmpty) {
      final embeddedRecipeMatch = RegExp(
        r'recipe-info[^>]*>.*?<h4[^>]*>([^<]+)</h4>\s*(?:<ul>.*?</ul>|<p>([^<]+)</p>)',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(bodyHtml);
      
      if (embeddedRecipeMatch.isNotEmpty) {
        for (final match in embeddedRecipeMatch) {
          final h4Title = match.group(1)?.trim().toLowerCase() ?? '';
          // For ul-based content, extract from the full match
          final fullMatch = match.group(0) ?? '';
          final pContent = match.group(2)?.trim();
          
          if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
            if (pContent != null && pContent.isNotEmpty && rawDirections.isEmpty) {
              rawDirections.add(_decodeHtml(pContent));
            }
          } else if (h4Title == 'glass' || h4Title == 'glassware') {
            if (pContent != null && pContent.isNotEmpty && glassType == null) {
              glassType = _decodeHtml(pContent);
            }
          } else if (h4Title == 'garnish') {
            if (pContent != null && pContent.isNotEmpty && garnishItems.isEmpty) {
              garnishItems = _splitGarnishText(_decodeHtml(pContent));
            }
          } else if (h4Title == 'ingredients' && rawIngredientStrings.isEmpty) {
            // Extract li items from the ul
            final liMatches = RegExp(r'<li>([^<]+)</li>', caseSensitive: false).allMatches(fullMatch);
            for (final li in liMatches) {
              final text = _decodeHtml(li.group(1)?.trim() ?? '');
              if (text.isNotEmpty) rawIngredientStrings.add(text);
            }
          }
        }
      }
    }
    
    // Additional fallback for Lyres: search for standalone h4>Method followed by p anywhere in the HTML
    // This handles cases where Method is not inside a recipe-info div
    if (rawDirections.isEmpty) {
      final methodMatch = RegExp(
        r'<h4[^>]*>\s*Method\s*</h4>\s*<p[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(bodyHtml);
      if (methodMatch != null) {
        final text = _decodeHtml((methodMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
        if (text.isNotEmpty) {
          rawDirections.add(text);
        }
      }
    }
    
    // Check for "Cooked" recipe plugin format (WordPress plugin)
    // Uses classes like cooked-ing-amount, cooked-ing-name, cooked-dir-content
    final cookedIngredients = document.querySelectorAll('.cooked-single-ingredient.cooked-ingredient');
    
    if (cookedIngredients.isNotEmpty) {
      usedStructuredFormat = true; // Cooked plugin provides reliable structured data
      
      // Parse Cooked format ingredients
      for (final elem in cookedIngredients) {
        final amount = elem.querySelector('.cooked-ing-amount')?.text?.trim() ?? '';
        final unit = elem.querySelector('.cooked-ing-measurement')?.text?.trim() ?? '';
        final name = elem.querySelector('.cooked-ing-name')?.text?.trim() ?? '';
        
        if (name.isNotEmpty) {
          // Build the ingredient string
          String ingredientStr = '';
          if (amount.isNotEmpty) {
            ingredientStr = amount;
            if (unit.isNotEmpty) {
              ingredientStr += ' $unit';
            }
            ingredientStr += ' $name';
          } else {
            ingredientStr = name;
          }
          rawIngredientStrings.add(_decodeHtml(ingredientStr.trim()));
        }
      }
      
      // Parse Cooked format directions
      final cookedDirections = document.querySelectorAll('.cooked-single-direction.cooked-direction');
      for (final elem in cookedDirections) {
        // Get the content div which contains paragraphs
        final contentDiv = elem.querySelector('.cooked-dir-content');
        if (contentDiv != null) {
          // Get all paragraphs
          final paragraphs = contentDiv.querySelectorAll('p');
          for (final p in paragraphs) {
            final text = _decodeHtml((p.text ?? '').trim());
            if (text.isNotEmpty) {
              rawDirections.add(text);
            }
          }
          // If no paragraphs, try the content directly
          if (paragraphs.isEmpty) {
            final text = _decodeHtml((contentDiv.text ?? '').trim());
            if (text.isNotEmpty) {
              rawDirections.add(text);
            }
          }
        }
      }
      
      // Parse Cooked format time (prep/cook time)
      final prepTime = document.querySelector('.cooked-prep-time');
      final cookTime = document.querySelector('.cooked-cook-time');
      final totalTime = document.querySelector('.cooked-total-time');
      
      int totalMinutes = 0;
      
      // Extract time from cooked-time elements
      if (totalTime != null) {
        final timeText = totalTime.text ?? '';
        totalMinutes = _extractMinutes(timeText);
      } else {
        if (prepTime != null) {
          final prepText = prepTime.text ?? '';
          totalMinutes += _extractMinutes(prepText);
        }
        if (cookTime != null) {
          final cookText = cookTime.text ?? '';
          totalMinutes += _extractMinutes(cookText);
        }
      }
      
      if (totalMinutes > 0) {
        timing = '$totalMinutes min';
      }
    }
    
    // Check for AmazingFoodMadeEasy format EARLY - uses ingredient_dish_header for sections
    // Structure: ul.ingredient_list > li.category > h3.ingredient_dish_header for headers
    //            ul.ingredient_list > li.ingredient for ingredient items
    if (rawIngredientStrings.isEmpty) {
      // Try to find the ingredient list container
      var ingredientList = document.querySelector('ul.ingredient_list');
      ingredientList ??= document.querySelector('.ingredient_list');
      
      if (ingredientList != null) {
        usedStructuredFormat = true;
        
        // Iterate through all li children
        final allLiItems = ingredientList.querySelectorAll('li');
        for (final li in allLiItems) {
          final liClasses = li.attributes['class'] ?? '';
          
          // Check if this li contains an ingredient_dish_header (category row)
          if (liClasses.contains('category')) {
            // Look for the h3 header inside
            final headerElem = li.querySelector('h3');
            if (headerElem != null) {
              final sectionText = _decodeHtml((headerElem.text ?? '').trim());
              if (sectionText.isNotEmpty) {
                // Remove "For the " prefix if present
                var sectionName = sectionText;
                final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
                if (forTheMatch != null) {
                  sectionName = forTheMatch.group(1)?.trim() ?? sectionText;
                }
                rawIngredientStrings.add('[$sectionName]');
              }
            }
          }
          // Check if this is an ingredient item
          else if (liClasses.contains('ingredient')) {
            final text = _decodeHtml((li.text ?? '').trim());
            if (text.isNotEmpty) {
              rawIngredientStrings.add(text);
            }
          }
        }
      }
      
      // Fallback: Query for h3.ingredient_dish_header and li.ingredient separately
      if (rawIngredientStrings.isEmpty) {
        // Check if these elements exist anywhere in the document
        final sectionHeaders = document.querySelectorAll('h3.ingredient_dish_header');
        final ingredientItems = document.querySelectorAll('li.ingredient');
        
        if (sectionHeaders.isNotEmpty || ingredientItems.isNotEmpty) {
          usedStructuredFormat = true;
          
          // Process in document order - get parent container and iterate
          // Get all li elements that are either category or ingredient
          final allLis = document.querySelectorAll('li.category, li.ingredient');
          
          for (final li in allLis) {
            final liClasses = li.attributes['class'] ?? '';
            
            if (liClasses.contains('category')) {
              final h3 = li.querySelector('h3');
              if (h3 != null) {
                final text = _decodeHtml((h3.text ?? '').trim());
                if (text.isNotEmpty) {
                  var sectionName = text;
                  final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(text);
                  if (forTheMatch != null) {
                    sectionName = forTheMatch.group(1)?.trim() ?? text;
                  }
                  rawIngredientStrings.add('[$sectionName]');
                }
              }
            } else if (liClasses.contains('ingredient')) {
              final text = _decodeHtml((li.text ?? '').trim());
              if (text.isNotEmpty) {
                rawIngredientStrings.add(text);
              }
            }
          }
        }
      }
    }
    
    // If Cooked format didn't find ingredients, try schema.org Microdata format
    // (distinct from JSON-LD - uses itemtype/itemprop attributes in HTML)
    if (rawIngredientStrings.isEmpty) {
      // Look for Recipe microdata container
      final recipeContainer = document.querySelector('[itemtype*="schema.org/Recipe"], [itemtype*="Recipe"]');
      if (recipeContainer != null) {
        usedStructuredFormat = true;
        
        // Track if we got ingredients from meta content (often incomplete)
        var gotFromMetaContent = false;
        
        // Extract ingredients from microdata
        final microdataIngredients = recipeContainer.querySelectorAll('[itemprop="recipeIngredient"], [itemprop="ingredients"]');
        for (final e in microdataIngredients) {
          // Check for content attribute first (common for meta tags)
          final contentAttr = e.attributes['content'];
          if (contentAttr != null && contentAttr.isNotEmpty) {
            gotFromMetaContent = true;
            // Content might be comma-separated list of ingredients
            // But don't split on commas inside parentheses
            if (contentAttr.contains(',') && !contentAttr.contains('(')) {
              final parts = contentAttr.split(',');
              for (final part in parts) {
                final cleaned = _decodeHtml(part.trim());
                if (cleaned.isNotEmpty) {
                  rawIngredientStrings.add(cleaned);
                }
              }
            } else {
              rawIngredientStrings.add(_decodeHtml(contentAttr));
            }
          } else {
            final text = _decodeHtml((e.text ?? '').trim());
            if (text.isNotEmpty) {
              rawIngredientStrings.add(text);
            }
          }
        }
        
        // If we got ingredients from meta content, they're likely just names without quantities.
        // Try to find better detailed ingredients with quantities from HTML structure.
        if (gotFromMetaContent && rawIngredientStrings.isNotEmpty) {
          final hasQuantities = rawIngredientStrings.any((item) =>
            RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
          );
          
          if (!hasQuantities) {
            // Try to find detailed ingredients from HTML structure
            final sectionResult = _parseHtmlBySections(document);
            final detailedIngredients = sectionResult['ingredients'] as List<String>? ?? [];
            
            // Check if detailed ingredients have quantities
            final detailedHasQuantities = detailedIngredients.any((item) =>
              RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
            );
            
            if (detailedHasQuantities && detailedIngredients.length >= rawIngredientStrings.length) {
              // Use detailed ingredients instead
              rawIngredientStrings = detailedIngredients;
            }
          }
        }
        
        // Extract directions from microdata
        if (rawDirections.isEmpty) {
          final microdataInstructions = recipeContainer.querySelectorAll('[itemprop="recipeInstructions"]');
          for (final e in microdataInstructions) {
            // Check if it contains nested steps
            final nestedSteps = e.querySelectorAll('[itemprop="itemListElement"], [itemprop="step"], li, p');
            if (nestedSteps.isNotEmpty) {
              for (final step in nestedSteps) {
                final text = _decodeHtml((step.text ?? '').trim());
                if (text.isNotEmpty && text.length > 10) {
                  rawDirections.add(text);
                }
              }
            } else {
              final text = _decodeHtml((e.text ?? '').trim());
              if (text.isNotEmpty) {
                // Split by newlines or periods followed by capital letters
                final steps = text.split(RegExp(r'\n+|\. (?=[A-Z])'));
                for (final step in steps) {
                  if (step.trim().isNotEmpty && step.trim().length > 10) {
                    rawDirections.add(step.trim());
                  }
                }
              }
            }
          }
        }
        
        // Extract time from microdata
        if (timing == null) {
          final totalTimeEl = recipeContainer.querySelector('[itemprop="totalTime"]');
          final prepTimeEl = recipeContainer.querySelector('[itemprop="prepTime"]');
          final cookTimeEl = recipeContainer.querySelector('[itemprop="cookTime"]');
          
          if (totalTimeEl != null) {
            final timeContent = totalTimeEl.attributes['content'] ?? totalTimeEl.attributes['datetime'] ?? totalTimeEl.text;
            if (timeContent != null) {
              timing = _parseDuration(timeContent);
            }
          } else {
            int totalMins = 0;
            if (prepTimeEl != null) {
              final timeContent = prepTimeEl.attributes['content'] ?? prepTimeEl.attributes['datetime'] ?? prepTimeEl.text;
              if (timeContent != null) totalMins += _parseDurationMinutes(timeContent);
            }
            if (cookTimeEl != null) {
              final timeContent = cookTimeEl.attributes['content'] ?? cookTimeEl.attributes['datetime'] ?? cookTimeEl.text;
              if (timeContent != null) totalMins += _parseDurationMinutes(timeContent);
            }
            if (totalMins > 0) timing = _formatMinutes(totalMins);
          }
        }
        
        // Extract yield from microdata
        if (yield == null) {
          final yieldEl = recipeContainer.querySelector('[itemprop="recipeYield"]');
          if (yieldEl != null) {
            yield = _decodeHtml((yieldEl.text ?? '').trim());
          }
        }
      }
    }
    
    // Try popular recipe plugin formats
    if (rawIngredientStrings.isEmpty) {
      // Tasty Recipes plugin
      final tastyIngredients = document.querySelectorAll('.tasty-recipes-ingredients li, .tasty-recipes-ingredient');
      if (tastyIngredients.isNotEmpty) {
        usedStructuredFormat = true;
        for (final e in tastyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
      
      // Try Tasty Recipes directions
      if (rawDirections.isEmpty) {
        final tastyDirections = document.querySelectorAll('.tasty-recipes-instructions li, .tasty-recipes-instruction');
        for (final e in tastyDirections) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawDirections.add(text);
        }
      }
    }
    
    if (rawIngredientStrings.isEmpty) {
      // EasyRecipe plugin
      final easyIngredients = document.querySelectorAll('.ERSIngredients li, .easy-recipe-ingredients li');
      if (easyIngredients.isNotEmpty) {
        usedStructuredFormat = true;
        for (final e in easyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
      
      if (rawDirections.isEmpty) {
        final easyDirections = document.querySelectorAll('.ERSInstructions li, .easy-recipe-instructions li');
        for (final e in easyDirections) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawDirections.add(text);
        }
      }
    }
    
    if (rawIngredientStrings.isEmpty) {
      // Yummly / ZipList / other common formats
      final yummlyIngredients = document.querySelectorAll('.recipe-ingredients li, .recipe-ingred_txt, .ingredient-item, .Ingredient, .p-ingredient');
      if (yummlyIngredients.isNotEmpty) {
        for (final e in yummlyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
    }
    
    if (rawDirections.isEmpty && rawIngredientStrings.isNotEmpty) {
      // Try common instruction selectors
      final commonDirections = document.querySelectorAll('.recipe-instructions li, .recipe-procedure li, .instruction-item, .step-text, .p-instructions li, .Instruction');
      for (final e in commonDirections) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) rawDirections.add(text);
      }
    }
    
    // If still empty, try standard selectors
    if (rawIngredientStrings.isEmpty) {
      final ingredientElements = document.querySelectorAll(
        '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient',
      );
      
      for (final e in ingredientElements) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) {
          rawIngredientStrings.add(text);
        }
      }
    }
    
    // If standard selectors failed, try section-based parsing
    // This handles sites like Modernist Pantry that use headings + lists
    if (rawIngredientStrings.isEmpty) {
      final sectionResult = _parseHtmlBySections(document);
      rawIngredientStrings = sectionResult['ingredients'] ?? [];
      equipmentItems = sectionResult['equipment'] ?? [];
      glassType = sectionResult['glass'];
      garnishItems = sectionResult['garnish'] ?? [];
      yield = sectionResult['yield'];
      timing = sectionResult['timing'];
      htmlNotes = sectionResult['notes'] as String?;
      // Section-based parsing is semi-structured
      if (rawIngredientStrings.isNotEmpty) {
        usedStructuredFormat = true;
      }
    } else {
      // Even if we found ingredients via other methods, still extract equipment
      // This handles sites that have structured ingredients but also equipment sections
      final sectionResult = _parseHtmlBySections(document);
      if ((sectionResult['equipment'] as List?)?.isNotEmpty ?? false) {
        equipmentItems = sectionResult['equipment'] ?? [];
      }
      if (sectionResult['glass'] != null) {
        glassType = sectionResult['glass'];
      }
      if ((sectionResult['garnish'] as List?)?.isNotEmpty ?? false) {
        garnishItems = sectionResult['garnish'] ?? [];
      }
      if (yield == null && sectionResult['yield'] != null) {
        yield = sectionResult['yield'];
      }
      if (timing == null && sectionResult['timing'] != null) {
        timing = sectionResult['timing'];
      }
      if (htmlNotes == null && sectionResult['notes'] != null) {
        htmlNotes = sectionResult['notes'] as String?;
      }
    }
    
    // Parse ingredients - use _parseIngredients which properly handles section headers
    // by tracking them and applying to subsequent ingredients, rather than adding empty-name entries
    var ingredients = _parseIngredients(rawIngredientStrings);
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    // If Cooked format didn't find directions, try standard selectors
    if (rawDirections.isEmpty) {
      final instructionElements = document.querySelectorAll(
        '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction',
      );
      
      for (final e in instructionElements) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) {
          rawDirections.add(text);
        }
      }
    }
    
    // If standard selectors failed, try step-based parsing
    // This handles sites that use h3 headings for step names
    if (rawDirections.isEmpty) {
      rawDirections = _parseDirectionsBySections(document);
      // Section-based parsing with h3 headings is semi-structured
      if (rawDirections.isNotEmpty) {
        usedStructuredFormat = true;
      }
    }

    // Extract step images from direction content
    // Some sites (like AmazingFoodMadeEasy) embed images in direction paragraphs
    stepImages = _extractStepImages(document, sourceUrl);

    // If we still don't have ingredients or directions, try one more aggressive pass
    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      // Last resort: look for ANY lists that might contain recipe data
      // This is very permissive but better than failing completely
      final allLists = document.querySelectorAll('ul, ol');
      for (final list in allLists) {
        final items = list.querySelectorAll('li');
        if (items.length >= 2) {
          final itemTexts = <String>[];
          for (final e in items) {
            final text = _decodeHtml((e.text ?? '').trim());
            if (text.isNotEmpty && text.length < 200) { // Reasonable length for ingredients/directions
              itemTexts.add(text);
            }
          }
          
          // Check if items look like ingredients (have measurements/quantities)
          final hasMeasurements = itemTexts.any((item) => 
            // Standard measurement patterns
            RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram|gram)', caseSensitive: false).hasMatch(item) ||
            // Unicode fractions with units
            RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|lb|kg|g)?', caseSensitive: false).hasMatch(item) ||
            // Items with parentheses often contain measurements
            RegExp(r'\(.*\d+.*\)').hasMatch(item) ||
            // Plain numbers followed by ingredient words
            RegExp(r'^\d+\s+(?:large|medium|small|cloves?|bunch|can|jar|package|pkg|head|stalk|piece|slice|sprig)s?\b', caseSensitive: false).hasMatch(item) ||
            // Dash-separated ranges like "1-2 cups"
            RegExp(r'\d+\s*[-–]\s*\d+\s*(?:cup|tbsp|tsp|oz|g|ml)', caseSensitive: false).hasMatch(item) ||
            // Common food words with amounts
            RegExp(r'^\d+\s+\w+\s+(?:chicken|beef|pork|fish|onion|garlic|butter|oil|flour|sugar|salt|pepper|egg|milk|cream|cheese|tomato|potato|carrot|celery)', caseSensitive: false).hasMatch(item),
          );
          
          // Check if items look like directions (longer text, action verbs)
          final hasDirections = itemTexts.any((item) => 
            item.length > 30 && (
              RegExp(r'\b(?:put|place|add|mix|stir|heat|cook|bake|blend|pour|whisk|chop|dice|slice|mince|preheat|combine|fold|serve|remove|transfer|let|allow|season|taste)\b', caseSensitive: false).hasMatch(item) ||
              RegExp(r'^\d+[\.\)]').hasMatch(item) // Numbered steps
            )
          );
          
          if (hasMeasurements && itemTexts.length >= 2) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
          } else if (hasDirections && itemTexts.length >= 2 && rawDirections.isEmpty) {
            rawDirections = itemTexts;
          }
          
          if (rawIngredientStrings.isNotEmpty || rawDirections.isNotEmpty) {
            break;
          }
        }
      }
    }
    
    // Super aggressive fallback: scan ALL text content for ingredient-like patterns
    if (rawIngredientStrings.isEmpty) {
      // Look for definition lists (dl/dt/dd) which some sites use
      final defLists = document.querySelectorAll('dl');
      for (final dl in defLists) {
        final terms = dl.querySelectorAll('dt, dd');
        if (terms.length >= 2) {
          final itemTexts = <String>[];
          for (final term in terms) {
            final text = _decodeHtml((term.text ?? '').trim());
            if (text.isNotEmpty && text.length < 150) {
              itemTexts.add(text);
            }
          }
          // Check if any have measurement patterns
          final hasMeasurements = itemTexts.any((item) => 
            RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml)', caseSensitive: false).hasMatch(item),
          );
          if (hasMeasurements) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
            break;
          }
        }
      }
    }
    
    // Try table-based recipes (some sites use tables for ingredients)
    if (rawIngredientStrings.isEmpty) {
      final tables = document.querySelectorAll('table');
      for (final table in tables) {
        final rows = table.querySelectorAll('tr');
        if (rows.length >= 2) {
          final itemTexts = <String>[];
          for (final row in rows) {
            final cells = row.querySelectorAll('td, th');
            if (cells.isNotEmpty) {
              // Combine cells into a single ingredient string
              final cellTexts = <String>[];
              for (final cell in cells) {
                final text = _decodeHtml((cell.text ?? '').trim());
                if (text.isNotEmpty) cellTexts.add(text);
              }
              if (cellTexts.isNotEmpty) {
                itemTexts.add(cellTexts.join(' '));
              }
            }
          }
          // Check if any have measurement patterns
          final hasMeasurements = itemTexts.any((item) => 
            RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml)', caseSensitive: false).hasMatch(item),
          );
          if (hasMeasurements && itemTexts.length >= 2) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
            break;
          }
        }
      }
    }
    
    // Final fallback: scan entire body for ingredient-like content
    // This handles sites like Modernist Pantry that use plain text bullets or unusual formatting
    if (rawIngredientStrings.isEmpty) {
      final bodyText = document.body?.text ?? '';
      
      // Try multiple bullet/separator characters
      final bulletChars = ['•', '\u2022', '\u2023', '\u25E6', '·', '●', '○'];
      String? bulletChar;
      for (final bc in bulletChars) {
        if (bodyText.contains(bc)) {
          bulletChar = bc;
          break;
        }
      }
      
      if (bulletChar != null) {
        // Split by the found bullet character
        final allBulletItems = bodyText.split(bulletChar);
        final potentialIngredients = <String>[];
        
        for (var item in allBulletItems) {
          // Take only first line of each bullet item
          final firstNewline = item.indexOf('\n');
          if (firstNewline > 0) {
            item = item.substring(0, firstNewline);
          }
          item = _decodeHtml(item.trim());
          
          if (item.isEmpty || item.length < 3 || item.length > 150) continue;
          
          // Skip if it looks like binary or encoded data
          if (_looksLikeBinaryOrEncoded(item)) continue;
          
          // Skip obvious non-ingredient lines
          if (item.toLowerCase().contains('subscribe') || 
              item.toLowerCase().contains('http') ||
              item.toLowerCase().contains('click') ||
              item.toLowerCase().contains('menu') ||
              item.toLowerCase().contains('instagram') ||
              item.toLowerCase().contains('facebook')) continue;
          
          // Check if this looks like an ingredient (has a measurement or is a section header)
          final looksLikeIngredient = 
              RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg)', caseSensitive: false).hasMatch(item) ||
              RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]', caseSensitive: false).hasMatch(item) ||
              RegExp(r'\(\d+[^)]*\)', caseSensitive: false).hasMatch(item) || // Has parenthetical measurement
              item.endsWith(':'); // Section header like "Ingredients Black Garlic Honey:"
          
          if (looksLikeIngredient) {
            potentialIngredients.add(item);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // If still no ingredients, try line-by-line scanning for measurement patterns
      if (rawIngredientStrings.isEmpty) {
        final lines = bodyText.split('\n');
        final potentialIngredients = <String>[];
        bool inIngredientSection = false;
        
        for (var line in lines) {
          line = _decodeHtml(line.trim());
          if (line.isEmpty) continue;
          
          // Check if we're entering an ingredients section
          if (line.toLowerCase().contains('ingredient') && line.length < 50) {
            inIngredientSection = true;
            continue;
          }
          
          // Check if we're leaving the ingredients section
          if (inIngredientSection && 
              (line.toLowerCase().contains('equipment') ||
               line.toLowerCase().contains('direction') ||
               line.toLowerCase().contains('instruction') ||
               line.toLowerCase().contains('method') ||
               line.toLowerCase().contains('step') && line.length < 30)) {
            break;
          }
          
          if (inIngredientSection && line.length > 3 && line.length < 150) {
            // Skip if it looks like binary or encoded data
            if (_looksLikeBinaryOrEncoded(line)) continue;
            
            // Check if this looks like an ingredient
            final looksLikeIngredient = 
                RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg)', caseSensitive: false).hasMatch(line) ||
                RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]', caseSensitive: false).hasMatch(line) ||
                RegExp(r'\(\d+[^)]*(?:cup|tbsp|tsp|oz|g)\)', caseSensitive: false).hasMatch(line) ||
                line.endsWith(':');
            
            if (looksLikeIngredient) {
              potentialIngredients.add(line);
            }
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Ultimate fallback: find ALL lines with measurement patterns anywhere in the body
      // This works even without section headers or proper line breaks
      if (rawIngredientStrings.isEmpty) {
        // Use regex to find measurement patterns with context
        final measurementPattern = RegExp(
          r'(\d+\s*[gG](?:\s|\))|(?:\d+\s*)?(?:[½¼¾⅓⅔⅛⅜⅝⅞])\s*(?:cup|cups|tbsp|tsp)?|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|g)\b|\(\s*\d+[^)]*(?:cup|tbsp|tsp|oz|g)[^)]*\))',
          caseSensitive: false,
        );
        
        // Split body by potential line breaks or sentence endings
        final segments = bodyText.split(RegExp(r'\n|(?<=[.!?])\s+(?=[A-Z])'));
        final potentialIngredients = <String>[];
        
        for (var segment in segments) {
          segment = _decodeHtml(segment.trim());
          
          // Skip if too short or too long
          if (segment.length < 5 || segment.length > 200) continue;
          
          // Skip if it looks like base64 or binary data
          // Base64 has long strings without spaces and special char patterns
          if (_looksLikeBinaryOrEncoded(segment)) continue;
          
          // Skip if it looks like a direction/instruction (starts with verb)
          if (RegExp(r'^(put|place|add|mix|stir|pour|heat|cook|bake|preheat|combine|whisk|blend|let|allow)\b', caseSensitive: false).hasMatch(segment)) {
            continue;
          }
          
          // Skip navigation/social content
          if (segment.toLowerCase().contains('subscribe') ||
              segment.toLowerCase().contains('http') ||
              segment.toLowerCase().contains('click') ||
              segment.toLowerCase().contains('instagram') ||
              segment.toLowerCase().contains('facebook') ||
              segment.toLowerCase().contains('newsletter')) {
            continue;
          }
          
          // Check if segment contains a measurement pattern
          if (measurementPattern.hasMatch(segment)) {
            // Additional check: measurement should be near the start (first 60 chars)
            // This filters out sentences that mention measurements mid-way
            final match = measurementPattern.firstMatch(segment);
            if (match != null && match.start < 60) {
              potentialIngredients.add(segment);
            }
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Super simple bodyText pattern: just regex match "Xg (anything) Word" directly
      if (rawIngredientStrings.isEmpty) {
        final simplePattern = RegExp(
          r'(\d+\s*g\s*\([^)]+\)\s*[A-Za-z][A-Za-z\s]{1,30})',
          caseSensitive: false,
        );
        final matches = simplePattern.allMatches(bodyText);
        final potentialIngredients = <String>[];
        
        for (final match in matches) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Dead simple: find ANY text around gram measurements
      // This is the most lenient fallback - captures surrounding context of "###g" or "### g"
      if (rawIngredientStrings.isEmpty) {
        // Find positions of all gram measurements in text (allow optional space before g)
        final gramPattern = RegExp(r'\d+\s*g\b', caseSensitive: false);
        final gramMatches = gramPattern.allMatches(bodyText).toList();
        final potentialIngredients = <String>[];
        
        for (final match in gramMatches) {
          // Capture 50 chars after the gram measurement
          final start = match.start;
          final end = (match.end + 50).clamp(0, bodyText.length);
          var snippet = bodyText.substring(start, end).trim();
          
          // Skip if too short
          if (snippet.length < 5) continue;
          
          // Clean up - stop at newline or next measurement
          final newlineIdx = snippet.indexOf('\n');
          if (newlineIdx > 0 && newlineIdx < 60) snippet = snippet.substring(0, newlineIdx);
          
          // Only look for next gram if snippet is long enough
          if (snippet.length > 5) {
            final nextGramIdx = snippet.indexOf(RegExp(r'\d+\s*g', caseSensitive: false), 5);
            if (nextGramIdx > 0 && nextGramIdx < 60) snippet = snippet.substring(0, nextGramIdx);
          }
          
          snippet = _decodeHtml(snippet.trim());
          
          // Basic validation - should have letters (ingredient name)
          if (snippet.length >= 8 && 
              snippet.length <= 100 &&
              RegExp(r'[A-Za-z]{3,}').hasMatch(snippet) &&
              !_looksLikeBinaryOrEncoded(snippet)) {
            potentialIngredients.add(snippet);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
    }
    
    // Raw HTML fallback: search the raw HTML source for ingredient patterns
    // This runs independently of DOM parsing and handles sites where DOM fails
    if (rawIngredientStrings.isEmpty && rawHtmlBody != null) {
      // Strip HTML tags to get clean text from raw HTML
      final cleanHtml = rawHtmlBody
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'&bull;|&middot;|&#8226;|&#x2022;', caseSensitive: false), '•') // Preserve bullet entities as •
          .replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'&#\d+;'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      
      final potentialIngredients = <String>[];
      
      // Pattern 1: Look for "Xg (Y Unit) Name" format (like Modernist Pantry)
      // Example: "200g (½ Cup) Honey" or "240g (1 Cup) Milk"
      final metricWithConversion = RegExp(
        r'(\d+g?\s*\([^)]{2,20}\)\s*[A-Za-z][A-Za-z\s\-]{2,40}?)(?=\s*\d+g|\s*•|\s*$|[,.])',
        caseSensitive: false,
      );
      
      for (final match in metricWithConversion.allMatches(cleanHtml)) {
        final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
        if (_isValidIngredientCandidate(ingredient)) {
          potentialIngredients.add(ingredient);
        }
      }
      
      // Pattern 2: Standard measurements with ingredient names
      if (potentialIngredients.isEmpty) {
        final standardMeasurement = RegExp(
          r'(\d+(?:\.\d+)?\s*(?:g|kg|oz|lb|lbs|cup|cups|tbsp|tablespoons?|tsp|teaspoons?|ml|liters?|litres?)\s+[A-Za-z][A-Za-z\s\-,]{2,50})',
          caseSensitive: false,
        );
        
        for (final match in standardMeasurement.allMatches(cleanHtml)) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      // Pattern 3: Fractional measurements
      if (potentialIngredients.isEmpty) {
        final fractionalPattern = RegExp(
          r'([½¼¾⅓⅔⅛]\s*(?:cup|cups|tbsp|tsp|teaspoon|tablespoon)s?\s+[A-Za-z][A-Za-z\s\-,]{2,50})',
          caseSensitive: false,
        );
        
        for (final match in fractionalPattern.allMatches(cleanHtml)) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      // Pattern 4: Ultra-simple gram pattern - just find "Xg (" or "X g (" followed by anything
      // This is very lenient for sites like Modernist Pantry
      if (potentialIngredients.isEmpty) {
        // Find all instances of "### g (..." in the text (allow space before g)
        final simpleGramPattern = RegExp(r'(\d+\s*g\s*\([^)]+\)\s*\S+(?:\s+\S+){0,5})', caseSensitive: false);
        
        for (final match in simpleGramPattern.allMatches(cleanHtml)) {
          var ingredient = match.group(1)?.trim() ?? '';
          // Clean up - take only reasonable length
          if (ingredient.length > 80) {
            ingredient = ingredient.substring(0, 80);
            // Cut at last space to avoid partial words
            final lastSpace = ingredient.lastIndexOf(' ');
            if (lastSpace > 20) ingredient = ingredient.substring(0, lastSpace);
          }
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      if (potentialIngredients.length >= 2) {
        rawIngredientStrings = _processIngredientListItems(potentialIngredients);
      }
    }
    
    // Also try to extract directions from body text if still missing
    if (rawDirections.isEmpty && rawIngredientStrings.isNotEmpty) {
      final bodyText = document.body?.text ?? '';
      
      // Look for h3-style section headings in the text
      // Pattern: newline + "Create/Make/Prepare/Churn" at start of line
      final lines = bodyText.split('\n');
      String? currentStepTitle;
      final currentStepContent = <String>[];
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        // Check if this looks like a step heading
        final isStepHeading = RegExp(r'^(Create|Make|Prepare|Churn|Step\s*\d+)\b', caseSensitive: false).hasMatch(trimmed) &&
            trimmed.length < 80 &&
            !trimmed.contains('•');
        
        if (isStepHeading) {
          // Save previous step if any
          if (currentStepTitle != null && currentStepContent.isNotEmpty) {
            rawDirections.add('**$currentStepTitle**');
            rawDirections.addAll(currentStepContent);
          }
          currentStepTitle = trimmed;
          currentStepContent.clear();
        } else if (currentStepTitle != null) {
          // This is content for the current step
          if (trimmed.length > 20 && 
              !trimmed.contains('•') && 
              !trimmed.toLowerCase().contains('subscribe') &&
              !trimmed.toLowerCase().contains('http')) {
            currentStepContent.add(trimmed);
          }
        }
      }
      
      // Don't forget the last step
      if (currentStepTitle != null && currentStepContent.isNotEmpty) {
        rawDirections.add('**$currentStepTitle**');
        rawDirections.addAll(currentStepContent);
      }
    }
    
    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktailSite = _isCocktailSite(sourceUrl);
    
    // Try to detect course from title and content
    String course;
    double courseConfidence;
    final titleLower = (title ?? '').toLowerCase();
    final urlLower = sourceUrl.toLowerCase();
    
    if (isCocktailSite || _isDrinkRecipeByContent(titleLower, urlLower, rawIngredientStrings)) {
      course = 'Drinks';
      courseConfidence = isCocktailSite ? 0.95 : 0.75;  // High confidence for known cocktail sites
    } else if (_isSmokingRecipe(titleLower, urlLower, rawIngredientStrings)) {
      course = 'Smoking';
      courseConfidence = 0.8;
    } else if (_isModernistRecipe(document, sourceUrl, rawIngredientStrings)) {
      course = 'Modernist';
      courseConfidence = 0.75;
    } else if (_isBreadRecipe(titleLower, urlLower, rawIngredientStrings)) {
      course = 'Breads';
      courseConfidence = 0.75;
    } else if (_isDessertRecipe(titleLower, urlLower, rawIngredientStrings)) {
      course = 'Desserts';
      courseConfidence = 0.7;
    } else if (_isSoupRecipe(titleLower, urlLower)) {
      course = 'Soups';
      courseConfidence = 0.75;
    } else if (_isSauceRecipe(titleLower, urlLower)) {
      course = 'Sauces';
      courseConfidence = 0.7;
    } else if (_isSideRecipe(titleLower, urlLower)) {
      course = 'Sides';
      courseConfidence = 0.6;
    } else if (_isAppRecipe(titleLower, urlLower)) {
      course = 'Apps';
      courseConfidence = 0.65;
    } else {
      course = 'Mains';
      courseConfidence = 0.5; // Medium confidence - it's a reasonable default
    }
    
    // For drinks, detect the base spirit
    String? subcategory;
    final isDrink = isCocktailSite || course == 'Drinks';
    if (isDrink) {
      final spiritCode = _detectSpirit(ingredients);
      if (spiritCode != null) {
        subcategory = Spirit.toDisplayName(spiritCode);
      }
    }

    // Calculate confidence - structured formats (like Cooked plugin) are more reliable
    final baseConfidence = usedStructuredFormat ? 0.85 : 0.7;
    final nameConfidence = title != null && title.isNotEmpty ? baseConfidence : 0.0;
    
    // Filter out empty or whitespace-only ingredient strings before processing
    // Also filter out strings that are just punctuation or control characters
    // And deduplicate ingredients (some sites like Saveur return duplicates)
    final seenIngredients = <String>{};
    final filteredIngredientStrings = <String>[];
    for (final s in rawIngredientStrings) {
      final trimmed = s.trim();
      if (trimmed.isEmpty || !RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) continue;
      // Normalize for comparison (lowercase, collapse whitespace)
      final normalizedKey = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seenIngredients.contains(normalizedKey)) continue;
      seenIngredients.add(normalizedKey);
      filteredIngredientStrings.add(trimmed);
    }
    
    final ingredientsConfidence = filteredIngredientStrings.isNotEmpty 
        ? (ingredients.length / filteredIngredientStrings.length) * baseConfidence 
        : 0.0;
    final directionsConfidence = rawDirections.isNotEmpty 
        ? (usedStructuredFormat ? 0.85 : 0.6) 
        : 0.0;

    // Create raw ingredient data, filtering out empty entries
    final rawIngredients = filteredIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      final bakerPct = _extractBakerPercent(raw);
      
      // For section-only items (parsed name is empty but has section),
      // keep the empty name so the review screen can display it as a section header
      final isSectionOnly = parsed.name.isEmpty && parsed.section != null;
      
      // Clean the fallback raw string by removing footnote markers (*, †, [1], etc.)
      final cleanedRaw = raw.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
      
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        preparation: parsed.preparation,
        bakerPercent: bakerPct != null ? '$bakerPct%' : null,
        name: isSectionOnly ? '' : (parsed.name.isNotEmpty ? parsed.name : cleanedRaw),
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    })
    // Filter out empty entries - must have alphanumeric in name OR have a section
    .where((i) => (i.name.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(i.name)) || i.sectionName != null)
    .toList();

    // Build detected courses list - include the course we detected
    final detectedCourses = <String>[course];
    
    // Extract image from schema.org markup, og:image, or common recipe image selectors
    final String? imageUrl = _extractImageFromHtml(document);
    
    // Set confidence for optional fields when they have values
    final timeConfidence = timing != null && timing.isNotEmpty 
        ? (usedStructuredFormat ? 0.9 : 0.7) 
        : 0.0;
    
    // Normalize yield (strip "Servings: ", "Serves ", etc.)
    if (yield != null && yield.isNotEmpty) {
      yield = _normalizeServes(yield);
    }
    
    final servesConfidence = yield != null && yield.isNotEmpty 
        ? (usedStructuredFormat ? 0.9 : 0.7) 
        : 0.0;

    // Build image paths list: header image first, then step images
    List<String>? imagePaths;
    if (imageUrl != null || stepImages.isNotEmpty) {
      imagePaths = [
        if (imageUrl != null) imageUrl,
        ...stepImages,
      ];
    }

    // Filter out junk direction lines (markdown titles, author bylines, etc.)
    // and deduplicate
    final filteredDirections = <String>[];
    final seenDirections = <String>{};
    for (final dir in rawDirections) {
      if (_isJunkDirectionLine(dir)) continue;
      final cleaned = _cleanDirectionLine(dir);
      if (cleaned.isEmpty) continue;
      final normalizedKey = cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (seenDirections.contains(normalizedKey)) continue;
      seenDirections.add(normalizedKey);
      filteredDirections.add(cleaned);
    }

    return RecipeImportResult(
      name: title != null ? _cleanRecipeName(title) : null,
      course: course,
      subcategory: subcategory,
      serves: yield,
      imageUrl: imageUrl,
      time: timing,
      ingredients: ingredients,
      directions: filteredDirections,
      notes: htmlNotes,
      equipment: equipmentItems,
      glass: glassType,
      garnish: garnishItems,
      rawIngredients: rawIngredients,
      rawDirections: filteredDirections,
      detectedCourses: detectedCourses,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      timeConfidence: timeConfidence,
      servesConfidence: servesConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
      imagePaths: imagePaths,
    );
  }
  
  /// Extract directions from raw HTML body, handling Shopify/Lyres-style embedded JSON
  /// with unicode escapes. This is needed for supplement logic when JSON-LD is missing directions.
  List<String> _extractDirectionsFromRawHtml(dynamic document, String rawBody) {
    final directions = <String>[];
    
    // Decode unicode escapes that Shopify/Lyres uses (embedded HTML in JSON)
    var bodyHtml = rawBody
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\"', '"')
        .replaceAll('\\u003c', '<')
        .replaceAll('\\u003e', '>')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('\\n', ' ')
        .replaceAll('\\"', '"');
    
    // Pattern 1: Lyres-style recipe-info divs with h4 Method title
    final recipeInfoDivs = RegExp(
      r'<div[^>]*class="[^"]*recipe-info[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(bodyHtml);
    
    for (final divMatch in recipeInfoDivs) {
      final divContent = divMatch.group(1) ?? '';
      final h4Match = RegExp(
        r'<h4[^>]*>(.*?)</h4>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(divContent);
      
      if (h4Match == null) continue;
      
      final h4Title = (h4Match.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
      
      if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
        final afterH4 = divContent.substring(h4Match.end);
        final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final pMatch in pMatches) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) {
            // Split by periods if multiple sentences
            if (text.contains('. ')) {
              directions.addAll(text.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).map((s) {
                final trimmed = s.trim();
                return trimmed.endsWith('.') ? trimmed : '$trimmed.';
              }));
            } else {
              directions.add(text);
            }
          }
        }
        if (directions.isNotEmpty) return directions;
      }
    }
    
    // Pattern 2: Standalone h4>Method followed by p (not in recipe-info div)
    if (directions.isEmpty) {
      final methodMatch = RegExp(
        r'<h4[^>]*>\s*Method\s*</h4>\s*<p[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(bodyHtml);
      if (methodMatch != null) {
        final text = _decodeHtml((methodMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
        if (text.isNotEmpty) {
          directions.add(text);
        }
      }
    }
    
    // Pattern 3: DOM-based extraction for h2/h3 Method or Directions heading
    if (directions.isEmpty) {
      for (final heading in document.querySelectorAll('h2, h3, h4')) {
        final headingText = (heading.text?.trim() ?? '').toLowerCase();
        if (headingText == 'method' || headingText == 'directions' || headingText == 'instructions') {
          // Get next sibling elements for content
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            // Stop at next heading
            if (tagName.startsWith('h') && tagName.length == 2) break;
            
            if (tagName == 'p') {
              final text = _decodeHtml((sibling.text ?? '').trim());
              if (text.isNotEmpty) directions.add(text);
            } else if (tagName == 'ol' || tagName == 'ul') {
              for (final li in sibling.querySelectorAll('li')) {
                final text = _decodeHtml((li.text ?? '').trim());
                if (text.isNotEmpty) directions.add(text);
              }
            }
            sibling = sibling.nextElementSibling;
          }
          if (directions.isNotEmpty) break;
        }
      }
    }
    
    return directions;
  }
  
  /// Parse HTML by looking for section headings (h2, h3) followed by content
  /// This handles sites like Modernist Pantry that structure recipes with headings
  Map<String, dynamic> _parseHtmlBySections(dynamic document) {
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'equipment': <String>[],
      'glass': null,
      'garnish': <String>[],
      'yield': null,
      'timing': null,
      'notes': null,
    };
    
    // First try: look for headings with id="ingredients" (common WordPress pattern)
    // This is more reliable as it uses explicit IDs
    final ingredientHeadingById = document.querySelector('h2#ingredients, h3#ingredients, [id="ingredients"]');
    if (ingredientHeadingById != null) {
      final ingredients = _extractListItemsFromSection(ingredientHeadingById, document);
      if (ingredients.isNotEmpty) {
        result['ingredients'] = ingredients;
      }
    }
    
    // Also check for equipment by ID
    final equipmentHeadingById = document.querySelector('h2#equipment, h3#equipment, [id="equipment"]');
    if (equipmentHeadingById != null) {
      final equipment = _extractListItemsFromSection(equipmentHeadingById, document);
      if (equipment.isNotEmpty) {
        result['equipment'] = equipment;
      }
    }
    
    // Check for glass by ID
    final glassHeadingById = document.querySelector('h2#glass, h3#glass, [id="glass"], h2#glassware, h3#glassware, [id="glassware"]');
    if (glassHeadingById != null) {
      final glassList = _extractListItemsFromSection(glassHeadingById, document);
      if (glassList.isNotEmpty) {
        result['glass'] = glassList.first;
      } else {
        // May be text after heading instead of a list
        final nextElement = glassHeadingById.nextElementSibling;
        if (nextElement != null) {
          final glassText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (glassText.isNotEmpty) {
            result['glass'] = glassText;
          }
        }
      }
    }
    
    // Check for garnish by ID
    final garnishHeadingById = document.querySelector('h2#garnish, h3#garnish, [id="garnish"]');
    if (garnishHeadingById != null) {
      final garnish = _extractListItemsFromSection(garnishHeadingById, document);
      if (garnish.isNotEmpty) {
        result['garnish'] = garnish;
      }
    }
    
    // === DRINK-SPECIFIC PATTERNS ===
    
    // Pattern 1: Combined "Glass and Garnish" heading (Seedlip style)
    // First list item is glass, rest are garnish
    if (result['glass'] == null) {
      for (final heading in document.querySelectorAll('h2, h3')) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('glass') && headingText.contains('garnish')) {
          final items = _extractListItemsAfterHeading(heading, document);
          if (items.isNotEmpty) {
            // First item is glass type
            result['glass'] = items.first;
            // Rest are garnishes
            if (items.length > 1) {
              result['garnish'] = items.sublist(1);
            }
          }
          break;
        }
      }
    }
    
    // Pattern 2: H3 "Glass:" heading (Diffords style)
    // Also try looking for any element with text starting with "Glass:"
    // Diffords uses: <h3 class="m-0">Glass:</h3> <p>Serve in a <a>Glass Type</a></p>
    if (result['glass'] == null) {
      // First try h3 elements (including those with class="m-0")
      for (final h3 in document.querySelectorAll('h3')) {
        final h3Text = h3.text?.trim().toLowerCase() ?? '';
        if (h3Text == 'glass:' || h3Text == 'glass' || h3Text.startsWith('glass:')) {
          final nextElem = h3.nextElementSibling;
          if (nextElem != null) {
            // First try to get glass from link inside the paragraph
            final glassLink = nextElem.querySelector('a');
            if (glassLink != null) {
              final linkText = _decodeHtml(glassLink.text?.trim() ?? '');
              if (linkText.isNotEmpty) {
                result['glass'] = linkText;
                break;
              }
            }
            // Fallback to paragraph text
            var glassText = _decodeHtml(nextElem.text?.trim() ?? '');
            // Handle "Serve in a [Glass Type]" pattern
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(glassText);
            if (serveInMatch != null) {
              glassText = serveInMatch.group(1)?.trim() ?? glassText;
            }
            if (glassText.isNotEmpty) {
              result['glass'] = glassText;
            }
          }
          break;
        }
      }
    }
    
    // Pattern 2b: Diffords uses class="legacy-longform-heading" for "Glass:" label
    // Note: There may be multiple elements with this class (Glass:, Garnish:, etc.)
    if (result['glass'] == null) {
      final glassHeadings = document.querySelectorAll('.legacy-longform-heading');
      for (final glassHeading in glassHeadings) {
        final headingText = glassHeading.text?.trim().toLowerCase() ?? '';
        if (headingText == 'glass:') {
          // Check if there's a sibling paragraph or the parent has more content
          final parent = glassHeading.parent;
          if (parent != null) {
            // First try to get glass from link inside the parent
            final glassLink = parent.querySelector('a');
            if (glassLink != null) {
              final linkText = _decodeHtml(glassLink.text?.trim() ?? '');
              if (linkText.isNotEmpty) {
                result['glass'] = linkText;
                break;
              }
            }
            // Fallback to parent text
            var parentText = _decodeHtml(parent.text?.trim() ?? '');
            // Remove "Glass:" prefix
            parentText = parentText.replaceFirst(RegExp(r'^Glass:\s*', caseSensitive: false), '').trim();
            // Handle "Serve in a [Glass Type]" pattern
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(parentText);
            if (serveInMatch != null) {
              parentText = serveInMatch.group(1)?.trim() ?? parentText;
            }
            if (parentText.isNotEmpty) {
              result['glass'] = parentText;
              break;
            }
          }
        }
      }
    }
    
    // Pattern 3: Inline "Garnish:" span (Diffords style)
    // <p><span class="legacy-longform-heading">Garnish:</span> Raspberries</p>
    if ((result['garnish'] as List).isEmpty) {
      // Look for spans with class that might contain "Garnish:"
      final allSpans = document.querySelectorAll('span');
      for (final span in allSpans) {
        final spanText = span.text?.trim() ?? '';
        if (spanText.toLowerCase() == 'garnish:' || spanText.toLowerCase() == 'garnish') {
          // Get parent element text and extract garnish
          final parent = span.parent;
          if (parent != null) {
            var parentText = _decodeHtml(parent.text?.trim() ?? '');
            // Remove "Garnish:" prefix
            parentText = parentText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
            if (parentText.isNotEmpty) {
              // Split by comma for multiple garnishes, keep "or" options together
              final garnishes = _splitGarnishText(parentText);
              if (garnishes.isNotEmpty) {
                result['garnish'] = garnishes;
              }
            }
          }
          break;
        }
      }
    }
    
    // Pattern 3b: Look for paragraphs that start with "Garnish:" 
    if ((result['garnish'] as List).isEmpty) {
      for (final p in document.querySelectorAll('p')) {
        final pText = p.text?.trim() ?? '';
        if (pText.toLowerCase().startsWith('garnish:')) {
          var garnishText = pText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
          if (garnishText.isNotEmpty) {
            final garnishes = _splitGarnishText(garnishText);
            if (garnishes.isNotEmpty) {
              result['garnish'] = garnishes;
            }
          }
          break;
        }
      }
    }
    
    // Pattern 4: garn-glass class (Punch style)
    // <p class="garn-glass"><span>Garnish:</span> orange or lemon peel</p>
    if ((result['garnish'] as List).isEmpty || result['glass'] == null) {
      final garnGlass = document.querySelector('.garn-glass, .garnish-glass');
      if (garnGlass != null) {
        final fullText = _decodeHtml(garnGlass.text?.trim() ?? '');
        // Check for Garnish: pattern
        final garnishMatch = RegExp(r'Garnish:\s*(.+?)(?:\s*Glass:|$)', caseSensitive: false).firstMatch(fullText);
        if (garnishMatch != null && (result['garnish'] as List).isEmpty) {
          final garnishText = garnishMatch.group(1)?.trim() ?? '';
          if (garnishText.isNotEmpty) {
            final garnishes = _splitGarnishText(garnishText);
            result['garnish'] = garnishes;
          }
        }
        // Check for Glass: pattern
        final glassMatch = RegExp(r'Glass:\s*(.+?)(?:\s*Garnish:|$)', caseSensitive: false).firstMatch(fullText);
        if (glassMatch != null && result['glass'] == null) {
          result['glass'] = glassMatch.group(1)?.trim();
        }
      }
    }
    
    // Pattern 5: "Serve in a" text anywhere (common for cocktail sites)
    if (result['glass'] == null) {
      final allParagraphs = document.querySelectorAll('p');
      for (final p in allParagraphs) {
        final pText = p.text?.trim() ?? '';
        final serveInMatch = RegExp(r'Serve\s+in\s+(?:a\s+)?([A-Za-z][A-Za-z\s\-]+(?:glass|flute|coupe|tumbler|goblet|snifter|mug|cup))', caseSensitive: false).firstMatch(pText);
        if (serveInMatch != null) {
          result['glass'] = serveInMatch.group(1)?.trim();
          break;
        }
      }
    }
    
    // Pattern 6: Diffords-style table for ingredients (legacy-ingredients-table)
    // <table class="legacy-ingredients-table"><tr><td>amount</td><td>ingredient</td></tr></table>
    if ((result['ingredients'] as List).isEmpty) {
      final ingredientTable = document.querySelector('.legacy-ingredients-table, table.ingredients');
      if (ingredientTable != null) {
        final rows = ingredientTable.querySelectorAll('tr');
        final ingredients = <String>[];
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 2) {
            final amount = _decodeHtml(cells[0].text?.trim() ?? '');
            final name = _decodeHtml(cells[1].text?.trim() ?? '');
            if (name.isNotEmpty) {
              ingredients.add(amount.isNotEmpty ? '$amount $name' : name);
            }
          }
        }
        if (ingredients.isNotEmpty) {
          result['ingredients'] = ingredients;
        }
      }
    }
    
    // Pattern 7: Lyres.com style - recipe-info divs with h4 titles
    // <div class="recipe-info"><h4 class="title">Glass</h4><p>Old Fashioned</p></div>
    if (result['glass'] == null || (result['garnish'] as List).isEmpty) {
      final recipeInfoDivs = document.querySelectorAll('.recipe-info, div.recipe-info');
      for (final div in recipeInfoDivs) {
        final h4 = div.querySelector('h4, .title');
        if (h4 != null) {
          final titleText = h4.text?.trim().toLowerCase() ?? '';
          final p = div.querySelector('p');
          if (p != null) {
            final content = _decodeHtml(p.text?.trim() ?? '');
            if (content.isNotEmpty) {
              if (titleText == 'glass' && result['glass'] == null) {
                result['glass'] = content;
              } else if (titleText == 'garnish' && (result['garnish'] as List).isEmpty) {
                result['garnish'] = _splitGarnishText(content);
              }
            }
          }
        }
      }
    }
    
    // === END DRINK-SPECIFIC PATTERNS ===
    
    // Find all h2 headings and check their text
    final headings = document.querySelectorAll('h2');
    
    for (final heading in headings) {
      final headingText = heading.text?.trim().toLowerCase() ?? '';
      
      // Find the next sibling elements after this heading
      final nextElement = heading.nextElementSibling;
      
      if (headingText.contains('ingredient')) {
        // Parse ingredients from the list following this heading
        // First try standard list extraction
        var ingredients = _extractListItemsAfterHeading(heading, document);
        
        // If that failed, try extracting bullet-point text content
        if (ingredients.isEmpty) {
          ingredients = _extractBulletPointsAfterHeading(heading, document);
        }
        
        if (ingredients.isNotEmpty) {
          result['ingredients'] = ingredients;
        }
      } else if (headingText.contains('equipment')) {
        // Parse equipment from the list following this heading
        var equipment = _extractListItemsAfterHeading(heading, document);
        
        // If that failed, try extracting bullet-point text content
        if (equipment.isEmpty) {
          equipment = _extractBulletPointsAfterHeading(heading, document);
        }
        
        result['equipment'] = equipment;
      } else if (headingText.contains('glass') || headingText.contains('glassware')) {
        // Extract glass type from next paragraph or list
        if (result['glass'] == null) {
          var glassList = _extractListItemsAfterHeading(heading, document);
          if (glassList.isNotEmpty) {
            result['glass'] = glassList.first;
          } else if (nextElement != null) {
            final glassText = _decodeHtml(nextElement.text?.trim() ?? '');
            if (glassText.isNotEmpty) {
              result['glass'] = glassText;
            }
          }
        }
      } else if (headingText.contains('garnish')) {
        // Extract garnish list from the list following this heading
        if ((result['garnish'] as List).isEmpty) {
          var garnish = _extractListItemsAfterHeading(heading, document);
          if (garnish.isEmpty) {
            garnish = _extractBulletPointsAfterHeading(heading, document);
          }
          // If still empty but there's a next element with text, use that
          if (garnish.isEmpty && nextElement != null) {
            final garnishText = _decodeHtml(nextElement.text?.trim() ?? '');
            if (garnishText.isNotEmpty) {
              // Split by comma or newline in case multiple garnishes in one line
              garnish = garnishText.split(RegExp(r'[,\n]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          }
          result['garnish'] = garnish;
        }
      } else if (headingText.contains('yield') || headingText.contains('serves') || headingText.contains('serving')) {
        // Extract yield/serving info from next paragraph
        if (nextElement != null) {
          final yieldText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (yieldText.isNotEmpty) {
            result['yield'] = yieldText;
          }
        }
      } else if (headingText.contains('timing') || headingText.contains('time')) {
        // Extract timing info from next paragraph
        if (nextElement != null) {
          final timingText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (timingText.isNotEmpty) {
            // Try to parse the timing text
            result['timing'] = _parseTimingText(timingText);
          }
        }
      }
    }
    
    // If we didn't find ingredients with h2, try looking for H3 sub-sections within ingredient container
    // AmazingFoodMadeEasy uses: H2 "Ingredients for..." then H3 "For the X" sections with text ingredients
    if ((result['ingredients'] as List).isEmpty) {
      // Find h2 with "ingredient" and extract H3 subsections with their content
      for (final h2 in document.querySelectorAll('h2')) {
        final h2Text = h2.text?.trim().toLowerCase() ?? '';
        if (h2Text.contains('ingredient')) {
          final collectedItems = <String>[];
          
          // Walk through siblings after this H2 until next H2
          var sibling = h2.nextElementSibling;
          String? currentSection;
          
          while (sibling != null) {
            final siblingTag = sibling.localName?.toLowerCase();
            
            // Stop at next H2 (new major section)
            if (siblingTag == 'h2') break;
            
            // H3 is a sub-section header (e.g., "For the Sous Vide Pork Tenderloin")
            if (siblingTag == 'h3') {
              final sectionText = _decodeHtml(sibling.text?.trim() ?? '');
              // Check if this is a "For the X" section header, not instructions
              if (sectionText.isNotEmpty && 
                  !sectionText.toLowerCase().contains('instruction') &&
                  !sectionText.toLowerCase().contains('direction') &&
                  !sectionText.toLowerCase().contains('minutes') &&
                  !sectionText.toLowerCase().contains('hour')) {
                // Extract section name, removing "For the" prefix
                var sectionName = sectionText;
                final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
                if (forTheMatch != null) {
                  sectionName = forTheMatch.group(1)?.trim() ?? sectionText;
                }
                currentSection = sectionName;
                collectedItems.add('[$currentSection]');
              }
            }
            // Text content (paragraphs, divs) might contain ingredients
            else if (siblingTag == 'p' || siblingTag == 'div') {
              final text = _decodeHtml(sibling.text?.trim() ?? '');
              // Check if this line has measurements (ingredient line) or is a food item
              if (text.isNotEmpty && _couldBeIngredientLine(text)) {
                // Split by newlines in case multiple ingredients in one paragraph
                for (final line in text.split('\n')) {
                  final trimmed = line.trim();
                  if (trimmed.isNotEmpty && trimmed.length > 2) {
                    collectedItems.add(trimmed);
                  }
                }
              }
            }
            // Also handle ul/ol lists within sections (common pattern)
            else if (siblingTag == 'ul' || siblingTag == 'ol') {
              final listItems = sibling.querySelectorAll('li');
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty && text.length > 2) {
                  collectedItems.add(text);
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
          
          if (collectedItems.isNotEmpty) {
            result['ingredients'] = collectedItems;
            break;
          }
        }
      }
    }
    
    // If we didn't find ingredients with h2, try looking for lists with specific patterns
    if ((result['ingredients'] as List).isEmpty) {
      // Also check h3 headings (some sites use h3 for recipe sections)
      final h3Headings = document.querySelectorAll('h3');
      for (final heading in h3Headings) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('ingredient')) {
          var ingredients = _extractListItemsAfterHeading(heading, document);
          
          // If list extraction failed, try bullet point extraction
          if (ingredients.isEmpty) {
            ingredients = _extractBulletPointsAfterHeading(heading, document);
          }
          
          if (ingredients.isNotEmpty) {
            result['ingredients'] = ingredients;
            break;
          }
        }
      }
    }
    
    // If still no ingredients, try looking for lists with specific patterns
    if ((result['ingredients'] as List).isEmpty) {
      // Look for lists that contain ingredient-like items (amounts + names)
      final allLists = document.querySelectorAll('ul, ol');
      for (final list in allLists) {
        final items = list.querySelectorAll('li');
        final itemTexts = <String>[];
        for (final e in items) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) {
            itemTexts.add(text);
          }
        }
        
        // Check if this looks like an ingredient list (has quantities)
        // Enhanced pattern to match formats like "200g (½ Cup) Honey" or "60g (4 Tablespoons)"
        final hasQuantities = itemTexts.any((item) => 
          RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram)', caseSensitive: false).hasMatch(item) ||
          RegExp(r'[½¼¾⅓⅔⅛]\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon)', caseSensitive: false).hasMatch(item),
        );
        
        // Lower threshold - accept lists with 2+ items if they have quantities
        if (hasQuantities && itemTexts.length >= 2) {
          result['ingredients'] = _processIngredientListItems(itemTexts);
          break;
        }
      }
    }
    
    // Last resort: look for bold text patterns like "**Ingredients:**" followed by lists
    if ((result['ingredients'] as List).isEmpty) {
      // Look for strong/bold elements containing "ingredient"
      final boldElements = document.querySelectorAll('strong, b');
      for (final bold in boldElements) {
        final boldText = bold.text?.trim().toLowerCase() ?? '';
        if (boldText.contains('ingredient') && !boldText.contains('equipment')) {
          // Check if the bold is inside a list item - if so, get the parent list
          var parent = bold.parent;
          while (parent != null) {
            final parentTag = parent.localName?.toLowerCase();
            if (parentTag == 'ul' || parentTag == 'ol') {
              // Found the list - extract all items
              final listItems = parent.querySelectorAll('li');
              final itemTexts = <String>[];
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty) {
                  itemTexts.add(text);
                }
              }
              if (itemTexts.isNotEmpty) {
                result['ingredients'] = _processIngredientListItems(itemTexts);
                break;
              }
            } else if (parentTag == 'li') {
              // Bold is inside a list item - get the parent list
              var listParent = parent.parent;
              if (listParent != null) {
                final listTag = listParent.localName?.toLowerCase();
                if (listTag == 'ul' || listTag == 'ol') {
                  final listItems = listParent.querySelectorAll('li');
                  final itemTexts = <String>[];
                  for (final li in listItems) {
                    final text = _decodeHtml(li.text?.trim() ?? '');
                    if (text.isNotEmpty) {
                      itemTexts.add(text);
                    }
                  }
                  if (itemTexts.isNotEmpty) {
                    result['ingredients'] = _processIngredientListItems(itemTexts);
                    break;
                  }
                }
              }
              break;
            }
            parent = parent.parent;
          }
          
          // Also try to find a list after this bold element (if not inside a list)
          if ((result['ingredients'] as List).isEmpty) {
            var nextElement = bold.parent?.nextElementSibling ?? bold.nextElementSibling;
            while (nextElement != null) {
              final tagName = nextElement.localName?.toLowerCase();
              if (tagName == 'ul' || tagName == 'ol') {
                final listItems = nextElement.querySelectorAll('li');
                final itemTexts = <String>[];
                for (final li in listItems) {
                  final text = _decodeHtml(li.text?.trim() ?? '');
                  if (text.isNotEmpty) {
                    itemTexts.add(text);
                  }
                }
                if (itemTexts.isNotEmpty) {
                  result['ingredients'] = _processIngredientListItems(itemTexts);
                  break;
                }
              } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'strong' || tagName == 'b') {
                break;
              }
              nextElement = nextElement.nextElementSibling;
            }
          }
          
          if ((result['ingredients'] as List).isNotEmpty) break;
        }
      }
    }
    
    // Final fallback: Look for text blocks that contain bullet-point characters
    // This handles sites that use plain text with • or - characters as bullets
    if ((result['ingredients'] as List).isEmpty) {
      // Find all text-containing elements
      final textElements = document.querySelectorAll('p, div, span');
      for (final elem in textElements) {
        final text = elem.text?.trim() ?? '';
        
        // Check if this contains bullet-pointed items with ingredient-like content
        if (text.contains('•') || text.contains('- ')) {
          // Split by bullet characters
          final lines = text.split(RegExp(r'[•]\s*|\n+'));
          
          if (lines.length >= 3) {
            // Check if multiple lines have quantities (indicating ingredients)
            int quantityCount = 0;
            for (final line in lines) {
              if (RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram)', caseSensitive: false).hasMatch(line)) {
                quantityCount++;
              }
            }
            
            // If we found multiple quantity-containing lines, these are likely ingredients
            if (quantityCount >= 2) {
              final items = <String>[];
              for (var line in lines) {
                line = _decodeHtml(line.trim());
                if (line.isEmpty || line.length < 3) continue;
                if (line.toLowerCase().contains('click') ||
                    line.toLowerCase().contains('subscribe') ||
                    line.toLowerCase().contains('http')) continue;
                items.add(line);
              }
              
              if (items.isNotEmpty) {
                result['ingredients'] = _processIngredientListItems(items);
                break;
              }
            }
          }
        }
      }
    }
    
    // Normalize glass (title case)
    if (result['glass'] != null && (result['glass'] as String).isNotEmpty) {
      result['glass'] = _toTitleCase(result['glass'] as String);
    }
    
    // Normalize garnish (title case each item)
    final garnishList = result['garnish'] as List<String>;
    if (garnishList.isNotEmpty) {
      result['garnish'] = garnishList.map((g) => _toTitleCase(g)).toList();
    }
    
    // Normalize yield/serves (strip prefixes)
    if (result['yield'] != null && (result['yield'] as String).isNotEmpty) {
      result['yield'] = _normalizeServes(result['yield'] as String);
    }
    
    // Extract editor's notes from HTML
    // Pattern 1: Punch-style editors-note or editor-note classes
    // Punch uses various selectors including recipe__editors-note, recipe-editors-note, etc.
    final editorsNoteElem = document.querySelector(
      '.editors-note, .editor-note, .editors_note, .recipe-editor-note, '
      '.recipe__editors-note, .recipe-editors-note, '
      '[class*="editor"][class*="note"], '
      '.recipe-note, .recipe__note'
    );
    if (editorsNoteElem != null) {
      final noteText = _decodeHtml(editorsNoteElem.text?.trim() ?? '');
      if (noteText.isNotEmpty) {
        result['notes'] = noteText.toLowerCase().startsWith('editor') ? noteText : "Editor's Note: $noteText";
      }
    }
    
    // Pattern 2: Blockquote with editor's note indicator
    if (result['notes'] == null) {
      final blockquotes = document.querySelectorAll('blockquote');
      for (final bq in blockquotes) {
        final text = _decodeHtml(bq.text?.trim() ?? '');
        final lowerText = text.toLowerCase();
        if (lowerText.startsWith('editor') || lowerText.contains('editor\'s note')) {
          result['notes'] = text.startsWith('Editor') ? text : "Editor's Note: $text";
          break;
        }
      }
    }
    
    // Pattern 3: Heading containing "Editor's Note" followed by paragraph content (Punch style)
    // Punch uses: <h2>Editor's Note</h2> followed by <p> paragraphs
    if (result['notes'] == null) {
      final headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
      for (final heading in headings) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('editor') && headingText.contains('note')) {
          // Found "Editor's Note" heading - collect following paragraph text
          final paragraphs = <String>[];
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase();
            // Stop at next heading or non-paragraph element
            if (tagName != null && tagName.startsWith('h')) break;
            if (tagName == 'p') {
              final pText = _decodeHtml(sibling.text?.trim() ?? '');
              if (pText.isNotEmpty) {
                paragraphs.add(pText);
              }
            }
            sibling = sibling.nextElementSibling;
          }
          if (paragraphs.isNotEmpty) {
            result['notes'] = "Editor's Note:\n${paragraphs.join('\n\n')}";
            break;
          }
        }
      }
    }
    
    // Pattern 4: Italicized text at top of article with editor's note content
    if (result['notes'] == null) {
      final italics = document.querySelectorAll('em, i');
      for (final em in italics) {
        final text = _decodeHtml(em.text?.trim() ?? '');
        if (text.length > 50 && text.length < 500) {
          final lowerText = text.toLowerCase();
          // Check if it looks like an editor's note (mentions author, origin, etc.)
          if (lowerText.contains('originally appeared') || 
              lowerText.contains('this recipe') ||
              lowerText.contains('adapted from') ||
              lowerText.contains('excerpt from')) {
            result['notes'] = "Editor's Note: $text";
            break;
          }
        }
      }
    }
    
    return result;
  }
  
  /// Extract list items from a section identified by a heading with a specific ID
  /// This handles WordPress-style markup where paragraphs/comments separate heading from list
  List<String> _extractListItemsFromSection(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // Strategy 1: Look for h3/h4 sub-sections and ul/ol within the parent's wrapper
    // This preserves section structure by including sub-headings as section markers
    var parent = heading.parent;
    var searchLimit = 0;
    
    while (parent != null && searchLimit < 5) {
      final parentTag = parent.localName?.toLowerCase();
      
      // Find all h3, h4, ul, ol elements within the parent container to preserve order
      final elementsInParent = parent.querySelectorAll('h3, h4, ul, ol');
      final collectedItems = <String>[];
      var foundHeadingYet = false;
      
      for (final elem in elementsInParent) {
        // Skip elements that come before our main heading
        // Simple heuristic: check if this element is within the ingredient section
        final elemTag = elem.localName?.toLowerCase();
        
        if (elemTag == 'h3' || elemTag == 'h4') {
          final sectionText = _decodeHtml(elem.text?.trim() ?? '');
          if (sectionText.isNotEmpty && !sectionText.toLowerCase().contains('instruction') && !sectionText.toLowerCase().contains('direction')) {
            // Add as section marker with colon
            collectedItems.add('$sectionText:');
            foundHeadingYet = true;
          }
        } else if (elemTag == 'ul' || elemTag == 'ol') {
          final listItems = elem.querySelectorAll('li');
          for (final li in listItems) {
            final text = _decodeHtml(li.text?.trim() ?? '');
            if (text.isNotEmpty) {
              collectedItems.add(text);
            }
          }
        }
      }
      
      // Check if this looks like an ingredient list (has measurements)
      final hasQuantities = collectedItems.any((item) =>
        RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
      );
      
      if (hasQuantities && collectedItems.length >= 2) {
        return _processIngredientListItems(collectedItems);
      }
      
      parent = parent.parent;
      searchLimit++;
    }
    
    // Strategy 2: Skip over paragraph elements that may contain WP comments
    var nextElement = heading.nextElementSibling;
    var skippedCount = 0;
    
    while (nextElement != null && skippedCount < 10) {
      final tagName = nextElement.localName?.toLowerCase();
      
      if (tagName == 'ul' || tagName == 'ol') {
        // Found the list
        final listItems = nextElement.querySelectorAll('li');
        for (final li in listItems) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty) {
            items.add(text);
          }
        }
        // Continue to look for more lists after this one (for multiple sections)
      } else if (tagName == 'h2') {
        // Hit a major heading - stop completely
        break;
      } else if (tagName == 'h3' || tagName == 'h4') {
        // Sub-section heading - add as a section marker and continue
        final sectionText = _decodeHtml(nextElement.text?.trim() ?? '');
        if (sectionText.isNotEmpty) {
          // Add section header with trailing colon to mark it as a section
          items.add('$sectionText:');
        }
      } else if (tagName == 'p') {
        // Skip paragraph tags (might be WP comment wrappers)
        skippedCount++;
      } else if (tagName == 'div' || tagName == 'section') {
        // Check inside containers for lists and headings
        final nestedHeadings = nextElement.querySelectorAll('h3, h4');
        final nestedLists = nextElement.querySelectorAll('ul, ol');
        
        // Process headings and lists in order
        if (nestedHeadings.isNotEmpty || nestedLists.isNotEmpty) {
          // Get all h3, h4, ul, ol in document order
          final elements = nextElement.querySelectorAll('h3, h4, ul, ol');
          for (final elem in elements) {
            final elemTag = elem.localName?.toLowerCase();
            if (elemTag == 'h3' || elemTag == 'h4') {
              final sectionText = _decodeHtml(elem.text?.trim() ?? '');
              if (sectionText.isNotEmpty) {
                items.add('$sectionText:');
              }
            } else if (elemTag == 'ul' || elemTag == 'ol') {
              final listItems = elem.querySelectorAll('li');
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty) {
                  items.add(text);
                }
              }
            }
          }
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    return _processIngredientListItems(items);
  }
  
  /// Extract ingredients with section headers from HTML
  /// Handles sites like AmazingFoodMadeEasy that have structured HTML with sections
  /// but JSON-LD only has a flat ingredient list
  List<String> _extractIngredientsWithSections(dynamic document) {
    final ingredients = <String>[];
    
    // Try King Arthur Baking format: div.ingredient-section with p for section name and ul.list--bullets
    final kingArthurSections = document.querySelectorAll('.ingredient-section');
    if (kingArthurSections.isNotEmpty) {
      for (final section in kingArthurSections) {
        // Get section name from the first <p> child (not inside ul)
        // We need to find a <p> that is a direct child of the section div
        for (final child in section.children) {
          if (child.localName == 'p') {
            var sectionText = _decodeHtml((child.text ?? '').trim());
            // Remove trailing colon if present
            sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
            if (sectionText.isNotEmpty) {
              ingredients.add('[$sectionText]');
            }
            break; // Only get the first <p>
          }
        }
        
        // Get ingredients from ul li
        final items = section.querySelectorAll('ul li');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try Tasty.co format: div.ingredients__section with p.ingredient-section-name and li.ingredient
    final tastySections = document.querySelectorAll('.ingredients__section');
    if (tastySections.isNotEmpty) {
      for (final section in tastySections) {
        // Get section name from p.ingredient-section-name
        final sectionNameElem = section.querySelector('.ingredient-section-name');
        if (sectionNameElem != null) {
          var sectionText = _decodeHtml((sectionNameElem.text ?? '').trim());
          // Remove trailing colon if present
          sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
          if (sectionText.isNotEmpty) {
            ingredients.add('[$sectionText]');
          }
        }
        
        // Get ingredients from li.ingredient
        final items = section.querySelectorAll('li.ingredient');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try Serious Eats format: p.structured-ingredients__list-heading followed by ul.structured-ingredients__list
    final seriousEatsHeaders = document.querySelectorAll('.structured-ingredients__list-heading');
    if (seriousEatsHeaders.isNotEmpty) {
      for (final header in seriousEatsHeaders) {
        var sectionText = _decodeHtml((header.text ?? '').trim());
        // Remove trailing colon if present
        sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
        if (sectionText.isNotEmpty) {
          // Remove "For the" prefix if present
          final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
          if (forTheMatch != null) {
            sectionText = forTheMatch.group(1)?.trim() ?? sectionText;
          }
          ingredients.add('[$sectionText]');
        }
        
        // Get the ul sibling that follows this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul') {
            // Get all li elements
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
            break; // Found the ul, move to next section
          } else if (tagName == 'p' && sibling.attributes['class']?.contains('structured-ingredients__list-heading') == true) {
            break; // Next section header
          }
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try AmazingFoodMadeEasy format: ul.ingredient_list with li.category and li.ingredient
    var ingredientList = document.querySelector('ul.ingredient_list');
    ingredientList ??= document.querySelector('.ingredient_list');
    
    if (ingredientList != null) {
      final allLiItems = ingredientList.querySelectorAll('li');
      for (final li in allLiItems) {
        final liClasses = li.attributes['class'] ?? '';
        
        if (liClasses.contains('category')) {
          final headerElem = li.querySelector('h3');
          if (headerElem != null) {
            final sectionText = _decodeHtml((headerElem.text ?? '').trim());
            if (sectionText.isNotEmpty) {
              var sectionName = sectionText;
              final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
              if (forTheMatch != null) {
                sectionName = forTheMatch.group(1)?.trim() ?? sectionText;
              }
              ingredients.add('[$sectionName]');
            }
          }
        } else if (liClasses.contains('ingredient')) {
          final text = _decodeHtml((li.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try NYT Cooking format: h3 with class containing "ingredientgroup_name" followed by ul with li.ingredient
    final nytSectionHeaders = document.querySelectorAll('[class*="ingredientgroup_name"]');
    if (nytSectionHeaders.isNotEmpty) {
      for (final header in nytSectionHeaders) {
        var sectionText = _decodeHtml((header.text ?? '').trim());
        if (sectionText.isNotEmpty) {
          // Remove "For the" prefix if present
          final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
          if (forTheMatch != null) {
            sectionText = forTheMatch.group(1)?.trim() ?? sectionText;
          }
          ingredients.add('[$sectionText]');
        }
        
        // Get the ul sibling that follows this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul') {
            // Get all li elements (NYT uses class containing "ingredient")
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
            break; // Found the ul, move to next section
          } else if (tagName == 'h3' || tagName == 'h2') {
            break; // Next section header
          }
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try WPRM (WordPress Recipe Maker) format with ingredient groups
    final wprmGroups = document.querySelectorAll('.wprm-recipe-ingredient-group');
    if (wprmGroups.isNotEmpty) {
      for (final group in wprmGroups) {
        final groupName = group.querySelector('.wprm-recipe-group-name');
        if (groupName != null) {
          final sectionText = _decodeHtml((groupName.text ?? '').trim());
          if (sectionText.isNotEmpty) {
            ingredients.add('[$sectionText]');
          }
        }
        
        final items = group.querySelectorAll('.wprm-recipe-ingredient');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try generic section headers: h3 or h4 followed by ul/li
    final sectionHeaders = document.querySelectorAll('.ingredient-section-header, .ingredients h3, .ingredients h4');
    if (sectionHeaders.isNotEmpty) {
      for (final header in sectionHeaders) {
        final sectionText = _decodeHtml((header.text ?? '').trim());
        if (sectionText.isNotEmpty) {
          var sectionName = sectionText;
          final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(sectionText);
          if (forTheMatch != null) {
            sectionName = forTheMatch.group(1)?.trim() ?? sectionText;
          }
          ingredients.add('[$sectionName]');
        }
        
        // Get ingredients after this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul' || tagName == 'ol') {
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
          } else if (tagName == 'h3' || tagName == 'h4' || tagName == 'h2') {
            break; // Next section
          }
          
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try to find a specific ingredient container first (Saveur, etc.)
    // This avoids duplicate ingredients when the page has multiple copies for mobile/desktop views
    final ingredientContainerSelectors = [
      '#recipe-ingredients',           // Saveur uses id="recipe-ingredients"
      'ul.ingredients',                // Common pattern
      '.ingredients ul',               // ul inside .ingredients
      '.recipe-ingredients',           // Common class
      '[data-recipe-ingredients]',     // Data attribute pattern
    ];
    
    for (final selector in ingredientContainerSelectors) {
      // Use querySelector to get only the FIRST container
      final container = document.querySelector(selector);
      if (container != null) {
        final containerLis = container.querySelectorAll('li');
        if (containerLis.isNotEmpty) {
          for (final li in containerLis) {
            final liClasses = li.attributes['class'] ?? '';
            
            if (liClasses.contains('category')) {
              final h3 = li.querySelector('h3');
              if (h3 != null) {
                final text = _decodeHtml((h3.text ?? '').trim());
                if (text.isNotEmpty) {
                  var sectionName = text;
                  final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(text);
                  if (forTheMatch != null) {
                    sectionName = forTheMatch.group(1)?.trim() ?? text;
                  }
                  ingredients.add('[$sectionName]');
                }
              }
            } else {
              final text = _decodeHtml((li.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
          }
          
          if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
        }
      }
    }
    
    // Fallback: Query li.category and li.ingredient in document order
    // Apply deduplication to handle pages with multiple ingredient lists
    final allLis = document.querySelectorAll('li.category, li.ingredient');
    if (allLis.isNotEmpty) {
      for (final li in allLis) {
        final liClasses = li.attributes['class'] ?? '';
        
        if (liClasses.contains('category')) {
          final h3 = li.querySelector('h3');
          if (h3 != null) {
            final text = _decodeHtml((h3.text ?? '').trim());
            if (text.isNotEmpty) {
              var sectionName = text;
              final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(text);
              if (forTheMatch != null) {
                sectionName = forTheMatch.group(1)?.trim() ?? text;
              }
              ingredients.add('[$sectionName]');
            }
          }
        } else if (liClasses.contains('ingredient')) {
          final text = _decodeHtml((li.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
    }
    
    return _deduplicateIngredients(ingredients);
  }
  
  /// Extract list items that follow a heading element
  List<String> _extractListItemsAfterHeading(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // First try: look for ul immediately after the heading
    var nextElement = heading.nextElementSibling;
    while (nextElement != null) {
      final tagName = nextElement.localName?.toLowerCase();
      
      if (tagName == 'ul' || tagName == 'ol') {
        // Found a list - extract items
        final listItems = nextElement.querySelectorAll('li');
        for (final li in listItems) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty) {
            items.add(text);
          }
        }
        // Continue to look for more (might have sub-sections)
      } else if (tagName == 'h2') {
        // Hit a major heading - stop searching
        break;
      } else if (tagName == 'h3' || tagName == 'h4') {
        // Sub-section heading - add as section marker and continue
        final sectionText = _decodeHtml(nextElement.text?.trim() ?? '');
        if (sectionText.isNotEmpty) {
          items.add('$sectionText:');
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    // Second try: if heading has an id, look for lists in any wrapper after it
    if (items.isEmpty) {
      final headingId = heading.attributes['id'];
      if (headingId != null) {
        // Look for lists in parent's subsequent children
        final parent = heading.parent;
        if (parent != null) {
          var foundHeading = false;
          for (final child in parent.children) {
            if (child == heading) {
              foundHeading = true;
              continue;
            }
            if (foundHeading) {
              final tagName = child.localName?.toLowerCase();
              if (tagName == 'ul' || tagName == 'ol') {
                final listItems = child.querySelectorAll('li');
                for (final li in listItems) {
                  final text = _decodeHtml(li.text?.trim() ?? '');
                  if (text.isNotEmpty) {
                    items.add(text);
                  }
                }
                // Continue looking for more sections
              } else if (tagName == 'h2') {
                break;
              } else if (tagName == 'h3' || tagName == 'h4') {
                final sectionText = _decodeHtml(child.text?.trim() ?? '');
                if (sectionText.isNotEmpty) {
                  items.add('$sectionText:');
                }
              }
            }
          }
        }
      }
    }
    
    return _processIngredientListItems(items);
  }
  
  /// Extract items from bullet-point text content after a heading
  /// Handles sites like Modernist Pantry that use • characters instead of <ul>/<li>
  List<String> _extractBulletPointsAfterHeading(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // Look for content following the heading until the next h2/h3
    var nextElement = heading.nextElementSibling;
    
    while (nextElement != null) {
      final tagName = nextElement.localName?.toLowerCase();
      
      // Stop at next heading
      if (tagName == 'h2' || tagName == 'h3') break;
      
      // Get text content - try the element itself first
      var textContent = nextElement.text?.trim() ?? '';
      
      // If the element is a container (div, section), also try getting all child text
      if (textContent.isEmpty && (tagName == 'div' || tagName == 'section' || tagName == 'article')) {
        // Get all text from descendants
        final allText = <String>[];
        final descendants = nextElement.querySelectorAll('p, span, div, li');
        for (final desc in descendants) {
          final descText = desc.text?.trim() ?? '';
          if (descText.isNotEmpty) {
            allText.add(descText);
          }
        }
        textContent = allText.join('\n');
      }
      
      if (textContent.isNotEmpty) {
        // Split by common bullet point characters
        // Common patterns: • (bullet), - (dash at start of line), * (asterisk), or newlines
        // Use more careful splitting to avoid breaking ingredient text with dashes
        final lines = textContent.split(RegExp(r'[•]\s*|\n+|(?:^|\n)\s*[-\*]\s+'));
        
        for (var line in lines) {
          line = _decodeHtml(line.trim());
          
          // Also handle cases where bullet is at start of line
          if (line.startsWith('•') || line.startsWith('- ') || line.startsWith('* ')) {
            line = line.substring(line.indexOf(' ') + 1).trim();
          }
          
          // Skip empty lines and very short lines (likely fragments)
          if (line.isEmpty || line.length < 3) continue;
          
          // Skip obvious non-ingredient content (links, navigation, etc.)
          if (line.toLowerCase().contains('click') || 
              line.toLowerCase().contains('subscribe') ||
              line.toLowerCase().contains('http')) continue;
          
          items.add(line);
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    // If we didn't find anything using siblings, try a broader search
    // Look for any text containing • within the heading's parent section
    if (items.isEmpty) {
      final parent = heading.parent;
      if (parent != null) {
        final fullText = parent.text ?? '';
        // Find the section after "Ingredients" heading
        final headingText = heading.text?.trim() ?? '';
        final headingIndex = fullText.indexOf(headingText);
        if (headingIndex >= 0) {
          var afterHeading = fullText.substring(headingIndex + headingText.length);
          // Find the next major section (Equipment, Directions, etc.)
          final nextSectionMatch = RegExp(r'\n(Equipment|Directions?|Instructions?|Method|Steps?|Timing|Yield)\b', caseSensitive: false).firstMatch(afterHeading);
          if (nextSectionMatch != null) {
            afterHeading = afterHeading.substring(0, nextSectionMatch.start);
          }
          // Now split by bullets
          final lines = afterHeading.split(RegExp(r'[•]\s*'));
          for (var line in lines) {
            line = _decodeHtml(line.trim());
            if (line.isEmpty || line.length < 3) continue;
            // Skip section-like headers that might have been caught
            if (RegExp(r'^(Equipment|Directions?|Instructions?|Method|Steps?|Timing|Yield)\b', caseSensitive: false).hasMatch(line)) continue;
            if (line.toLowerCase().contains('click') || 
                line.toLowerCase().contains('subscribe') ||
                line.toLowerCase().contains('http')) continue;
            items.add(line);
          }
        }
      }
    }
    
    return _processIngredientListItems(items);
  }
  
  /// Process ingredient list items - handles section headers within ingredients
  /// Detects patterns like "Ingredients for Sauce:" as section headers
  List<String> _processIngredientListItems(List<String> items) {
    final processed = <String>[];
    int sectionCount = 0;
    
    for (final item in items) {
      // Check if this is a section header - must:
      // 1. End with colon
      // 2. Not contain numbers (which would indicate an amount)
      // 3. Not be too long (section headers are typically short)
      // 4. Optionally start with "Ingredients" or "For"
      final isLikelySectionHeader = item.endsWith(':') && 
          !RegExp(r'\d').hasMatch(item) &&  // No numbers
          item.length < 60 &&  // Not too long
          !RegExp(r',\s').hasMatch(item);  // No commas (which indicate ingredient lists)
      
      final sectionHeaderMatch = isLikelySectionHeader ? RegExp(
        r'^(?:Ingredients?\s+(?:for\s+)?|For\s+(?:the\s+)?)?(.+?)[:]\s*$',
        caseSensitive: false,
      ).firstMatch(item) : null;
      
      if (sectionHeaderMatch != null) {
        final sectionName = sectionHeaderMatch.group(1)?.trim() ?? item;
        sectionCount++;
        // Add all section headers - we'll use them for grouping
        processed.add('[${_capitalise(sectionName)}]');
      } else if (item.isNotEmpty) {
        processed.add(item);
      }
    }
    
    // If there was only one section header at the start, it's redundant - remove it
    if (sectionCount == 1 && processed.isNotEmpty && processed.first.startsWith('[') && processed.first.endsWith(']')) {
      processed.removeAt(0);
    }
    
    return processed;
  }
  
  /// Extract recipe image from HTML document
  /// Checks schema.org markup, Open Graph meta tags, and common recipe image selectors
  String? _extractImageFromHtml(dynamic document) {
    // Helper to get image URL from various attributes
    String? getImageUrl(dynamic element) {
      if (element == null) return null;
      // Try various attributes - sites use different ones for lazy loading
      final attrs = ['src', 'content', 'data-src', 'data-lazy-src', 'data-original', 'srcset'];
      for (final attr in attrs) {
        var value = element.attributes[attr];
        if (value != null && value.isNotEmpty) {
          // For srcset, take the first URL
          if (attr == 'srcset') {
            value = value.split(',').first.split(' ').first.trim();
          }
          // Skip placeholder images
          if (value.contains('data:image') || 
              value.contains('placeholder') ||
              value.contains('loading') ||
              value.contains('blank')) {
            continue;
          }
          return value;
        }
      }
      return null;
    }
    
    // 1. Try schema.org Recipe image (itemprop="image")
    final schemaImg = document.querySelector('[itemscope][itemtype*="Recipe"] [itemprop="image"]');
    if (schemaImg != null) {
      final url = getImageUrl(schemaImg);
      if (url != null) return url;
    }
    
    // 2. Try itemprop="image" directly (without parent scope check)
    final itempropImg = document.querySelector('[itemprop="image"]');
    if (itempropImg != null) {
      final url = getImageUrl(itempropImg);
      if (url != null) return url;
    }
    
    // 3. Try Open Graph image meta tag
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    
    // 4. Try Twitter card image
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null) {
      final content = twitterImage.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    
    // 5. Try preloaded image link (used by some sites like Seedlip)
    final preloadImage = document.querySelector('link[rel="preload"][as="image"]');
    if (preloadImage != null) {
      final href = preloadImage.attributes['href'];
      if (href != null && href.isNotEmpty && !href.contains('icon') && !href.contains('logo')) {
        return href;
      }
    }
    
    // 6. Try common recipe image class selectors
    final commonSelectors = [
      '.recipe-image img',
      '.recipe-photo img',
      '.wprm-recipe-image img',
      '.tasty-recipes-image img',
      '.snippet-image img',
      'article img',
      'picture source', // For picture elements with source tags
      'picture img',
    ];
    
    for (final selector in commonSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final url = getImageUrl(element);
        if (url != null && !url.contains('icon') && !url.contains('logo')) {
          return url;
        }
      }
    }
    
    return null;
  }
  
  /// Extract step images from direction/instruction content
  /// Handles sites like AmazingFoodMadeEasy that embed images in paragraphs
  List<String> _extractStepImages(dynamic document, String baseUrl) {
    final images = <String>[];
    final seenUrls = <String>{};
    
    // Helper to resolve relative URLs
    String resolveUrl(String src) {
      if (src.startsWith('http://') || src.startsWith('https://')) {
        return src;
      }
      if (src.startsWith('//')) {
        return 'https:$src';
      }
      // Relative URL - try to resolve against base
      try {
        final base = Uri.parse(baseUrl);
        return base.resolve(src).toString();
      } catch (_) {
        return src;
      }
    }
    
    // Look for images in direction/instruction sections
    final directionSelectors = [
      '.recipe-instructions img',
      '.instructions img',
      '.instructions img.body_image', // AmazingFoodMadeEasy
      '.directions img',
      '.recipe-procedure img',
      '[itemprop="recipeInstructions"] img',
      '.step-content img',
      '.instruction-step img',
      '.method img',
      // AmazingFoodMadeEasy uses paragraphs with embedded image links
      '.entry-content p a img',
      '.post-content p a img',
      'article p a img',
      // Direct images in content
      '.entry-content p img',
      '.post-content p img',
    ];
    
    for (final selector in directionSelectors) {
      final imgElements = document.querySelectorAll(selector);
      for (final img in imgElements) {
        // Get the src, checking data-src for lazy-loaded images too
        // Prefer data-src (full quality) over src (low quality placeholder)
        var src = img.attributes['data-src'] ?? 
                  img.attributes['data-lazy-src'] ??
                  img.attributes['src'];
        
        if (src == null || src.isEmpty) continue;
        
        // Skip icons, logos, and tiny images
        if (src.contains('icon') || 
            src.contains('logo') || 
            src.contains('avatar') ||
            src.contains('emoji') ||
            src.contains('1x1') ||
            src.contains('pixel') ||
            src.contains('low_quality')) continue; // Skip low quality placeholders
        
        // Skip if we've already seen this URL
        final resolvedUrl = resolveUrl(src);
        if (seenUrls.contains(resolvedUrl)) continue;
        seenUrls.add(resolvedUrl);
        
        images.add(resolvedUrl);
      }
    }
    
    // AmazingFoodMadeEasy: Look for a.image_href anchors with S3 URLs
    try {
      final imageHrefAnchors = document.querySelectorAll('a.image_href, .instructions a[href*="s3.amazonaws.com"]');
      for (final anchor in imageHrefAnchors) {
        final href = anchor.attributes['href'];
        if (href != null && href.isNotEmpty) {
          final resolvedUrl = resolveUrl(href);
          // Check if it's an image URL
          final lower = resolvedUrl.toLowerCase();
          if (lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp')) {
            if (!seenUrls.contains(resolvedUrl)) {
              seenUrls.add(resolvedUrl);
              images.add(resolvedUrl);
            }
          }
        }
      }
    } catch (_) {
      // Selector not supported
    }
    
    // Also look for images in anchor tags within content (common pattern)
    final anchorImgSelectors = [
      '.entry-content a[href*=".jpg"] img',
      '.entry-content a[href*=".png"] img',
      '.entry-content a[href*=".webp"] img',
      '.post-content a[href*=".jpg"] img',
      'article a[href*=".jpg"] img',
    ];
    
    for (final selector in anchorImgSelectors) {
      try {
        final anchors = document.querySelectorAll(selector);
        for (final anchor in anchors) {
          // Prefer the anchor href (usually full-size image)
          final parent = anchor.parent;
          if (parent != null && parent.localName?.toLowerCase() == 'a') {
            final href = parent.attributes['href'];
            if (href != null && href.isNotEmpty) {
              final resolvedUrl = resolveUrl(href);
              if (!seenUrls.contains(resolvedUrl)) {
                seenUrls.add(resolvedUrl);
                images.add(resolvedUrl);
              }
              continue;
            }
          }
          
          // Fall back to img src
          var src = anchor.attributes['src'] ?? anchor.attributes['data-src'];
          if (src != null && src.isNotEmpty) {
            final resolvedUrl = resolveUrl(src);
            if (!seenUrls.contains(resolvedUrl)) {
              seenUrls.add(resolvedUrl);
              images.add(resolvedUrl);
            }
          }
        }
      } catch (_) {
        // Selector might not be supported
      }
    }
    
    // Helper to check if URL is a valid step image
    bool isValidImageUrl(String url) {
      if (url.isEmpty) return false;
      final lower = url.toLowerCase();
      // Must have image extension or be S3/cloudfront URL
      final hasImageExt = lower.contains('.jpg') || 
          lower.contains('.jpeg') || 
          lower.contains('.png') || 
          lower.contains('.webp') ||
          lower.contains('.gif');
      final isS3 = lower.contains('s3.amazonaws.com') || lower.contains('cloudfront');
      if (!hasImageExt && !isS3) return false;
      // Skip icons, logos, avatars, tiny images
      if (lower.contains('icon') || 
          lower.contains('logo') || 
          lower.contains('avatar') ||
          lower.contains('emoji') ||
          lower.contains('1x1') ||
          lower.contains('pixel') ||
          lower.contains('badge') ||
          lower.contains('button') ||
          lower.contains('book-cover') ||
          lower.contains('headshot')) return false;
      return true;
    }
    
    // AmazingFoodMadeEasy embeds images as anchor tags with S3 URLs
    // Look for anchors with image hrefs
    try {
      final allAnchors = document.querySelectorAll('a[href*="s3.amazonaws.com"], a[href*=".jpg"], a[href*=".png"]');
      for (final anchor in allAnchors) {
        final href = anchor.attributes['href'];
        if (href != null && isValidImageUrl(href)) {
          final resolvedUrl = resolveUrl(href);
          if (!seenUrls.contains(resolvedUrl)) {
            seenUrls.add(resolvedUrl);
            images.add(resolvedUrl);
          }
        }
      }
    } catch (_) {
      // Selector not supported
    }
    
    // Also look for image links in raw HTML content (markdown-style image references)
    // Pattern: [alt text](https://...image.jpg)
    try {
      final bodyHtml = document.body?.innerHtml ?? '';
      final markdownImagePattern = RegExp(
        r'\[([^\]]+)\]\((https?://[^\s\)]+\.(?:jpg|jpeg|png|webp|gif))\)',
        caseSensitive: false,
      );
      for (final match in markdownImagePattern.allMatches(bodyHtml)) {
        final imageUrl = match.group(2);
        if (imageUrl != null && isValidImageUrl(imageUrl)) {
          if (!seenUrls.contains(imageUrl)) {
            seenUrls.add(imageUrl);
            images.add(imageUrl);
          }
        }
      }
    } catch (_) {
      // Error parsing HTML
    }
    
    // AmazingFoodMadeEasy: Images appear between H3 direction headings
    // Look for H3 headings that look like steps, then find images before/after them
    try {
      final h3Elements = document.querySelectorAll('h3');
      for (final h3 in h3Elements) {
        final h3Text = h3.text?.toLowerCase() ?? '';
        
        // Skip non-direction headings
        if (h3Text.contains('ingredient') || h3Text.contains('equipment')) continue;
        
        // Look for images in siblings before/after this H3
        // Check previous siblings
        var sibling = h3.previousElementSibling;
        for (int i = 0; i < 3 && sibling != null; i++) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          // Found an image or figure
          if (tagName == 'img') {
            final src = sibling.attributes['src'] ?? sibling.attributes['data-src'];
            if (src != null && isValidImageUrl(src)) {
              final resolvedUrl = resolveUrl(src);
              if (!seenUrls.contains(resolvedUrl)) {
                seenUrls.add(resolvedUrl);
                images.add(resolvedUrl);
              }
            }
          } else if (tagName == 'figure' || tagName == 'p' || tagName == 'div') {
            // Check for images inside
            final innerImgs = sibling.querySelectorAll('img');
            for (final img in innerImgs) {
              final src = img.attributes['src'] ?? img.attributes['data-src'];
              if (src != null && isValidImageUrl(src)) {
                final resolvedUrl = resolveUrl(src);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
            // Also check for anchor links to images
            final innerAnchors = sibling.querySelectorAll('a');
            for (final anchor in innerAnchors) {
              final href = anchor.attributes['href'];
              if (href != null && isValidImageUrl(href)) {
                final resolvedUrl = resolveUrl(href);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
          }
          
          // Stop if we hit another H3
          if (tagName == 'h3') break;
          
          sibling = sibling.previousElementSibling;
        }
        
        // Check next siblings for images too
        sibling = h3.nextElementSibling;
        for (int i = 0; i < 3 && sibling != null; i++) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          // Stop if we hit another H3 (that's the next step)
          if (tagName == 'h3') break;
          
          // Found an image or figure
          if (tagName == 'img') {
            final src = sibling.attributes['src'] ?? sibling.attributes['data-src'];
            if (src != null && isValidImageUrl(src)) {
              final resolvedUrl = resolveUrl(src);
              if (!seenUrls.contains(resolvedUrl)) {
                seenUrls.add(resolvedUrl);
                images.add(resolvedUrl);
              }
            }
          } else if (tagName == 'figure' || tagName == 'p' || tagName == 'div') {
            // Check for images inside
            final innerImgs = sibling.querySelectorAll('img');
            for (final img in innerImgs) {
              final src = img.attributes['src'] ?? img.attributes['data-src'];
              if (src != null && isValidImageUrl(src)) {
                final resolvedUrl = resolveUrl(src);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
            // Also check for anchor links to images
            final innerAnchors = sibling.querySelectorAll('a');
            for (final anchor in innerAnchors) {
              final href = anchor.attributes['href'];
              if (href != null && isValidImageUrl(href)) {
                final resolvedUrl = resolveUrl(href);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
          }
          
          sibling = sibling.nextElementSibling;
        }
      }
    } catch (_) {
      // Error parsing H3 structure
    }
    
    return images;
  }
  
  /// Parse directions by looking for step-based structure (h3 headings or numbered sections)
  List<String> _parseDirectionsBySections(dynamic document) {
    final directions = <String>[];
    
    // Look for h3 headings that might be step titles
    final stepHeadings = document.querySelectorAll('h3');
    
    bool isFirstSection = true;
    
    for (final heading in stepHeadings) {
      final stepTitle = _decodeHtml(heading.text?.trim() ?? '');
      if (stepTitle.isEmpty) continue;
      
      // Skip if this looks like a non-recipe heading (navigation, etc.)
      if (_isNavigationHeading(stepTitle)) continue;
      
      // Skip if this looks like a step number prefix (e.g., "Step 1" with content in divs)
      final looksLikeStepNumber = RegExp(r'^Step\s*\d+$', caseSensitive: false).hasMatch(stepTitle);
      
      // For non-first sections, add the section title as its own direction step
      if (!isFirstSection && !looksLikeStepNumber) {
        // Add section header as a step (like "Create Ice Cream Base")
        directions.add('**$stepTitle**');
      }
      isFirstSection = false;
      
      // Collect text content after this heading until the next h3
      var nextElement = heading.nextElementSibling;
      
      while (nextElement != null) {
        final tagName = nextElement.localName?.toLowerCase();
        
        // Stop at the next step heading
        if (tagName == 'h3' || tagName == 'h2') break;
        
        // First try to extract nested paragraphs/divs
        bool foundNested = false;
        if (tagName == 'div' || tagName == 'ul' || tagName == 'ol') {
          final nestedDivs = nextElement.querySelectorAll('div, p, li');
          for (final nested in nestedDivs) {
            final text = _decodeHtml(nested.text?.trim() ?? '');
            if (text.isNotEmpty && text != ' ' && text.length > 15) {
              // Avoid duplicates
              if (directions.isEmpty || directions.last != text) {
                directions.add(text);
                foundNested = true;
              }
            }
          }
        }
        
        // If no nested elements found, try to split the text by paragraphs
        if (!foundNested && (tagName == 'div' || tagName == 'p' || tagName == 'span')) {
          // Get HTML content to preserve paragraph breaks
          final htmlContent = nextElement.innerHtml ?? '';
          
          // Split by br tags or double newlines to get separate paragraphs
          final paragraphs = htmlContent
              .replaceAll(RegExp(r'<br\s*/?>'), '\n\n')
              .replaceAll(RegExp(r'</p>\s*<p[^>]*>'), '\n\n')
              .split(RegExp(r'\n\s*\n'))
              .map((p) => _decodeHtml(p.replaceAll(RegExp(r'<[^>]+>'), '').trim()))
              .where((p) => p.isNotEmpty && p.length > 15)
              .toList();
          
          if (paragraphs.length > 1) {
            // Multiple paragraphs found, add each separately
            for (final para in paragraphs) {
              if (directions.isEmpty || directions.last != para) {
                directions.add(para);
              }
            }
          } else {
            // Single block of text - add as is
            final text = _decodeHtml(nextElement.text?.trim() ?? '');
            if (text.isNotEmpty && text != ' ' && text.length > 15) {
              directions.add(text);
            }
          }
        } else if (!foundNested && tagName == 'li') {
          // Handle list items
          final text = _decodeHtml(nextElement.text?.trim() ?? '');
          if (text.isNotEmpty && text.length > 15) {
            directions.add(text);
          }
        }
        
        nextElement = nextElement.nextElementSibling;
      }
    }
    
    // If no h3-based steps found, try looking for ordered lists or numbered paragraphs
    if (directions.isEmpty) {
      final orderedLists = document.querySelectorAll('ol');
      for (final ol in orderedLists) {
        final items = ol.querySelectorAll('li');
        for (final li in items) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty && text.length > 20) {
            directions.add(text);
          }
        }
        if (directions.isNotEmpty) break;
      }
    }
    
    return directions;
  }
  
  /// Check if text could be an ingredient line (more flexible than strict measurement matching)
  bool _couldBeIngredientLine(String text) {
    // Has standard measurements
    if (RegExp(r'\d+\s*(?:g|grams?|kg|oz|ounce|lb|pound|cup|cups|tbsp|tablespoon|tsp|teaspoon|ml|l)', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    // Starts with a number
    if (RegExp(r'^\d+\s+').hasMatch(text)) {
      return true;
    }
    // Starts with a fraction
    if (RegExp(r'^[½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(text)) {
      return true;
    }
    // Contains common food words (be permissive for paragraph-style ingredients)
    final lower = text.toLowerCase();
    const foodWords = [
      'salt', 'pepper', 'oil', 'butter', 'sugar', 'flour', 'water', 'milk',
      'chicken', 'beef', 'pork', 'fish', 'garlic', 'onion', 'tomato', 'cheese',
      'cream', 'sauce', 'stock', 'broth', 'vinegar', 'lemon', 'honey', 'eggs',
      'fresh', 'dried', 'chopped', 'minced', 'sliced', 'diced', 'ground',
    ];
    if (foodWords.any((word) => lower.contains(word))) {
      // Only if the line is reasonably short (not a full paragraph of text)
      return text.length < 150;
    }
    return false;
  }
  
  /// Check if a heading looks like navigation or non-recipe content
  bool _isNavigationHeading(String text) {
    final lower = text.toLowerCase();
    const navPatterns = [
      'menu', 'navigation', 'search', 'cart', 'login', 'sign in', 'sign up',
      'categories', 'related', 'popular', 'latest', 'subscribe', 'newsletter',
      'about', 'contact', 'privacy', 'terms', 'copyright', 'share', 'comment',
    ];
    return navPatterns.any((pattern) => lower.contains(pattern));
  }
  
  /// Parse timing text like "Active Time: 30 Minutes Total Time: 1 Hour"
  String? _parseTimingText(String text) {
    // Try to extract total time
    final totalMatch = RegExp(
      r'Total\s+Time[:\s]+(\d+)\s*(minutes?|mins?|hours?|hrs?|h)',
      caseSensitive: false,
    ).firstMatch(text);
    
    if (totalMatch != null) {
      final value = int.tryParse(totalMatch.group(1) ?? '') ?? 0;
      final unit = totalMatch.group(2)?.toLowerCase() ?? '';
      
      if (unit.startsWith('h')) {
        return '$value hr';
      } else {
        return '$value min';
      }
    }
    
    // Try to extract any time mention
    final anyTimeMatch = RegExp(
      r'(\d+)\s*(minutes?|mins?|hours?|hrs?|h)',
      caseSensitive: false,
    ).firstMatch(text);
    
    if (anyTimeMatch != null) {
      final value = int.tryParse(anyTimeMatch.group(1) ?? '') ?? 0;
      final unit = anyTimeMatch.group(2)?.toLowerCase() ?? '';
      
      if (unit.startsWith('h')) {
        return '$value hr';
      } else {
        return '$value min';
      }
    }
    
    return null;
  }
  
  /// Check if this looks like a modernist gastronomy recipe
  bool _isModernistRecipe(dynamic document, String sourceUrl, List<String> ingredients) {
    // Check URL for modernist indicators
    final lowerUrl = sourceUrl.toLowerCase();
    if (lowerUrl.contains('modernist') || 
        lowerUrl.contains('molecular') ||
        lowerUrl.contains('chefsteps') ||
        lowerUrl.contains('science') ||
        lowerUrl.contains('technique')) {
      return true;
    }
    
    // Check ingredients for modernist additives
    const modernistIngredients = [
      'agar', 'sodium alginate', 'calcium chloride', 'calcium lactate',
      'xanthan', 'lecithin', 'maltodextrin', 'tapioca maltodextrin',
      'methylcellulose', 'gellan', 'carrageenan', 'transglutaminase',
      'activa', 'foam magic', 'versawhip', 'ultra-tex', 'ultratex',
      'sodium citrate', 'sodium hexametaphosphate', 'isomalt',
      'liquid nitrogen', 'immersion circulator', 'sous vide',
      'cream whipper', 'isi whip', 'pressure cooker',
    ];
    
    final allText = ingredients.join(' ').toLowerCase();
    for (final ingredient in modernistIngredients) {
      if (allText.contains(ingredient)) {
        return true;
      }
    }
    
    // Check page content for technique keywords
    final bodyText = document.body?.text?.toLowerCase() ?? '';
    const techniqueKeywords = [
      'spherification', 'gelification', 'emulsification',
      'sous vide', 'pressure cooking', 'vacuum seal',
      'foam', 'gel', 'caviar', 'pearls',
    ];
    
    int matchCount = 0;
    for (final keyword in techniqueKeywords) {
      if (bodyText.contains(keyword)) matchCount++;
    }
    
    // If multiple technique keywords found, likely modernist
    return matchCount >= 2;
  }
  
  /// Detect if this is a bread/dough recipe
  bool _isBreadRecipe(String titleLower, String urlLower, List<String> ingredients) {
    // Check title for explicit bread keywords (not pasta/pizza/noodles which are mains)
    const breadKeywords = [
      'bread', 'dough', 'focaccia', 'baguette', 'ciabatta', 'sourdough', 
      'brioche', 'challah', 'bagel', 'pretzel', 'flatbread', 'naan',
      'pita', 'tortilla', 'croissant', 'danish',
    ];
    
    for (final keyword in breadKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    // Check ingredients for bread-making staples (flour + yeast = likely bread)
    final hasFlour = ingredients.any((i) => i.toLowerCase().contains('flour'));
    final hasYeast = ingredients.any((i) => i.toLowerCase().contains('yeast'));
    
    // Flour + yeast = likely bread
    if (hasFlour && hasYeast) return true;
    
    return false;
  }
  
  /// Detect if this is a dessert recipe
  bool _isDessertRecipe(String titleLower, String urlLower, List<String> ingredients) {
    const dessertKeywords = [
      'cake', 'cookie', 'brownie', 'pie', 'tart', 'pudding',
      'ice cream', 'gelato', 'sorbet', 'mousse', 'custard',
      'cheesecake', 'cupcake', 'muffin', 'scone', 'donut',
      'doughnut', 'macaron', 'meringue', 'souffle', 'creme',
      'chocolate', 'dessert', 'sweet', 'candy', 'fudge',
      'truffle', 'tiramisu', 'panna cotta', 'pavlova',
    ];
    
    for (final keyword in dessertKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is a soup recipe
  bool _isSoupRecipe(String titleLower, String urlLower) {
    const soupKeywords = [
      'soup', 'stew', 'chowder', 'bisque', 'broth', 'stock',
      'gazpacho', 'consomme', 'pho', 'ramen', 'minestrone',
      'goulash', 'chili', 'curry soup', 'tom yum', 'laksa',
    ];
    
    for (final keyword in soupKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is a sauce recipe
  bool _isSauceRecipe(String titleLower, String urlLower) {
    const sauceKeywords = [
      'sauce', 'gravy', 'aioli', 'mayonnaise', 'mayo', 'pesto',
      'vinaigrette', 'dressing', 'marinade', 'glaze', 'reduction',
      'coulis', 'salsa', 'chimichurri', 'gremolata', 'relish',
      'chutney', 'compote', 'jam', 'jelly', 'preserve',
    ];
    
    for (final keyword in sauceKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is a side dish recipe
  bool _isSideRecipe(String titleLower, String urlLower) {
    const sideKeywords = [
      'side', 'salad', 'slaw', 'rice', 'pilaf', 'risotto',
      'mashed', 'roasted vegetable', 'grilled vegetable',
      'coleslaw', 'potato salad', 'grain bowl',
    ];
    
    for (final keyword in sideKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is an appetizer recipe
  bool _isAppRecipe(String titleLower, String urlLower) {
    const appKeywords = [
      'appetizer', 'appetiser', 'starter', 'hors d\'oeuvre',
      'canape', 'bruschetta', 'crostini', 'dip', 'spread',
      'hummus', 'guacamole', 'ceviche', 'tartare', 'carpaccio',
      'spring roll', 'egg roll', 'samosa', 'empanada',
    ];
    
    for (final keyword in appKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is a smoking/BBQ recipe
  bool _isSmokingRecipe(String titleLower, String urlLower, List<String> ingredients) {
    // Check title/URL for smoking keywords
    const smokingKeywords = [
      'smoked', 'smoking', 'smoke ', 'smoker',
      'bbq', 'barbecue', 'barbeque',
      'low and slow', 'pellet grill',
    ];
    
    for (final keyword in smokingKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    // Check for wood types in ingredients (strong indicator of smoking)
    const woodTypes = [
      'hickory', 'mesquite', 'applewood', 'apple wood',
      'cherrywood', 'cherry wood', 'pecan', 'oak',
      'maple wood', 'alder', 'wood chips', 'wood chunks',
    ];
    
    final allIngredients = ingredients.join(' ').toLowerCase();
    for (final wood in woodTypes) {
      if (allIngredients.contains(wood)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Detect if this is a drink/cocktail recipe (content-based, for HTML parsing)
  bool _isDrinkRecipeByContent(String titleLower, String urlLower, List<String> ingredients) {
    // Check title/URL for drink keywords
    const drinkKeywords = [
      'cocktail', 'martini', 'margarita', 'mojito', 'daiquiri',
      'manhattan', 'negroni', 'old fashioned', 'highball',
      'sour', 'fizz', 'collins', 'spritz', 'punch',
      'sangria', 'mimosa', 'bellini', 'cosmopolitan',
      'mai tai', 'pina colada', 'bloody mary', 'paloma',
      'smoothie', 'milkshake', 'lemonade', 'iced tea',
      // Spirits and liqueurs as drink type indicators
      'amaro', 'digestif', 'aperitif', 'bitters', 'sharbat', 'shrub',
      'cordial', 'elixir', 'tonic', 'syrup recipe', 'simple syrup',
      'infusion', 'tincture', 'limoncello', 'nocino',
    ];
    
    for (final keyword in drinkKeywords) {
      if (titleLower.contains(keyword) || urlLower.contains(keyword)) {
        return true;
      }
    }
    
    // Check for spirit names in title (more specific)
    const spirits = [
      'vodka', 'gin', 'rum', 'tequila', 'whiskey', 'whisky',
      'bourbon', 'scotch', 'brandy', 'cognac', 'mezcal',
      'liqueur', 'vermouth', 'amaretto', 'kahlua', 'baileys',
      'chartreuse', 'campari', 'aperol', 'fernet', 'grappa',
    ];
    
    // Only match spirits in title (not ingredients, as spirits can be cooking ingredients)
    for (final spirit in spirits) {
      if (titleLower.contains(spirit)) {
        return true;
      }
    }
    
    return false;
  }
}

// Provider for URL recipe importer
final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
