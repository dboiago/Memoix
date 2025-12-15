import 'dart:convert';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../features/import/models/recipe_import_result.dart';
import '../../../features/recipes/models/recipe.dart';
import 'recipe_parser_strategy.dart';
import 'ingredient_parser.dart';

// ============================================================================
// SITE CONFIG DEFINITIONS
// ============================================================================
// These define extraction patterns for common site structures.
// The StandardWebStrategy will try each config and use the first that works.

enum ExtractionMode {
  /// Container has sections as children, each with header + ingredient list
  containerWithSections,
  /// Headers are siblings followed by ingredient lists
  siblingHeaderList,
  /// Single list with mixed category and ingredient items
  mixedList,
}

class SiteConfig {
  final String? containerSelector;
  final String? sectionSelector;
  final String? headerSelector;
  final String ingredientSelector;
  final ExtractionMode mode;
  final bool headerIsDirectChild;
  final String? headerChildTag;

  const SiteConfig({
    this.containerSelector,
    this.sectionSelector,
    this.headerSelector,
    required this.ingredientSelector,
    required this.mode,
    this.headerIsDirectChild = false,
    this.headerChildTag,
  });
}

/// Site configurations for ingredient extraction
/// These cover common WordPress plugins, recipe platforms, and generic patterns
const _siteConfigs = <String, SiteConfig>{
  // King Arthur Baking
  'kingarthur': SiteConfig(
    sectionSelector: '.ingredient-section',
    headerIsDirectChild: true,
    headerChildTag: 'p',
    ingredientSelector: 'ul li',
    mode: ExtractionMode.containerWithSections,
  ),
  // Tasty.co
  'tasty': SiteConfig(
    sectionSelector: '.ingredients__section',
    headerSelector: '.ingredient-section-name',
    ingredientSelector: 'li.ingredient',
    mode: ExtractionMode.containerWithSections,
  ),
  // Serious Eats
  'seriouseats': SiteConfig(
    headerSelector: '.structured-ingredients__list-heading',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  // AmazingFoodMadeEasy
  'amazingfood': SiteConfig(
    containerSelector: 'ul.ingredient_list, .ingredient_list',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li.ingredient',
    mode: ExtractionMode.mixedList,
  ),
  // NYT Cooking
  'nyt': SiteConfig(
    headerSelector: '[class*="ingredientgroup_name"]',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  // WordPress Recipe Maker (WPRM) - very popular plugin
  'wprm': SiteConfig(
    sectionSelector: '.wprm-recipe-ingredient-group',
    headerSelector: '.wprm-recipe-group-name',
    ingredientSelector: '.wprm-recipe-ingredient',
    mode: ExtractionMode.containerWithSections,
  ),
  // Tasty Recipes plugin
  'tasty-recipes': SiteConfig(
    sectionSelector: '.tasty-recipes-ingredients-body',
    headerSelector: 'h4, .tasty-recipes-ingredients-header',
    ingredientSelector: 'li',
    mode: ExtractionMode.containerWithSections,
  ),
  // EasyRecipe plugin
  'easyrecipe': SiteConfig(
    containerSelector: '.ERSIngredients, .easy-recipe-ingredients',
    ingredientSelector: 'li',
    mode: ExtractionMode.mixedList,
  ),
  // Cooked plugin
  'cooked': SiteConfig(
    sectionSelector: '.cooked-recipe-ingredients',
    headerSelector: '.cooked-heading',
    ingredientSelector: '.cooked-single-ingredient',
    mode: ExtractionMode.containerWithSections,
  ),
  // Recipe Card Blocks by FLAVOR
  'flavor-recipecard': SiteConfig(
    sectionSelector: '.recipe-card-ingredients',
    headerSelector: 'h4',
    ingredientSelector: 'li',
    mode: ExtractionMode.containerWithSections,
  ),
  // Yummly / ZipList / common generic
  'yummly-ziplist': SiteConfig(
    containerSelector: '.recipe-ingredients, .ingredient-list',
    ingredientSelector: 'li, .recipe-ingred_txt, .ingredient-item',
    mode: ExtractionMode.mixedList,
  ),
  // Schema.org microdata format
  'microdata': SiteConfig(
    containerSelector: '[itemtype*="Recipe"]',
    ingredientSelector: '[itemprop="recipeIngredient"]',
    mode: ExtractionMode.mixedList,
  ),
  // Generic headers in .ingredients container
  'generic-headers': SiteConfig(
    containerSelector: '.ingredients',
    headerSelector: 'h3, h4',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  // Generic container-based extraction
  'generic-container': SiteConfig(
    containerSelector: '#recipe-ingredients, ul.ingredients, .ingredients ul, .recipe-ingredients, [data-recipe-ingredients]',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li:not(.category)',
    mode: ExtractionMode.mixedList,
  ),
};

// ============================================================================
// SQUARESPACE STRATEGY
// ============================================================================
// Handles Squarespace-based recipe sites (e.g., starchefs.com)

class SquarespaceRecipeStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  SquarespaceRecipeStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    if (document == null) return 0.0;
    
    final hasSqsContent = document.querySelector('.sqs-html-content') != null;
    final hasSqsBlock = document.querySelector('[data-sqsp-text-block-content]') != null;
    
    if (hasSqsContent || hasSqsBlock) {
      final bodyText = document.body?.text.toUpperCase() ?? '';
      if (bodyText.contains('INGREDIENTS') && bodyText.contains('METHOD')) {
        return 0.9;
      }
      return 0.6; // Medium confidence for Squarespace pages
    }
    return 0.0;
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    if (document == null) return null;

    // Extract title
    final title = _extractTitle(document);
    
    // Extract subtitle (often contains dish description)
    final subtitle = document.querySelector('h3')?.text.trim();
    
    // Find INGREDIENTS and METHOD blocks by looking for h4 headers
    // StarChefs uses <h4><strong>INGREDIENTS:</strong></h4> and <h4><strong>METHOD:</strong></h4>
    Element? ingredientsBlock;
    Element? methodBlock;
    
    final h4Elements = document.querySelectorAll('h4');
    for (final h4 in h4Elements) {
      final h4Text = h4.text.toUpperCase().trim();
      if (h4Text.contains('INGREDIENTS')) {
        // Get the parent sqs-html-content block
        // Note: Element.parent returns Node?, so we need to check if it's an Element
        Node? current = h4.parent;
        while (current != null) {
          if (current is Element && current.classes.contains('sqs-html-content')) {
            ingredientsBlock = current;
            break;
          }
          current = current.parent;
        }
      } else if (h4Text.contains('METHOD') || 
                 h4Text.contains('DIRECTIONS') || 
                 h4Text.contains('INSTRUCTIONS')) {
        Node? current = h4.parent;
        while (current != null) {
          if (current is Element && current.classes.contains('sqs-html-content')) {
            methodBlock = current;
            break;
          }
          current = current.parent;
        }
      }
    }
    
    List<String> rawIngredients = [];
    List<String> directions = [];
    String? servings;
    
    if (ingredientsBlock != null) {
      rawIngredients = _parseSquarespaceBlock(ingredientsBlock, isIngredients: true);
    }
    
    if (methodBlock != null) {
      directions = _parseSquarespaceBlock(methodBlock, isIngredients: false);
    }
    
    // Try to extract yield/servings from page
    final yieldMatch = RegExp(r'Yield:\s*(\d+\s*servings?)', caseSensitive: false)
        .firstMatch(document.body?.text ?? '');
    if (yieldMatch != null) {
      servings = yieldMatch.group(1);
    }

    // Extract image
    final imageUrl = _extractImage(document);

    if (rawIngredients.isEmpty && directions.isEmpty) {
      return null;
    }

    return RecipeImportResult(
      name: title,
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: _ingParser.parseList(rawIngredients),
      directions: directions,
      serves: servings,
      imageUrl: imageUrl,
      notes: subtitle,
    );
  }

  String _extractTitle(Document document) {
    // Try h1 first
    final h1 = document.querySelector('h1');
    if (h1 != null && h1.text.trim().isNotEmpty) {
      return _ingParser.decodeHtml(h1.text.trim());
    }
    
    // Fallback to og:title
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) {
      return _ingParser.decodeHtml(ogTitle);
    }
    
    return 'Untitled Recipe';
  }

  String? _extractImage(Document document) {
    // Try og:image first
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) return ogImage;
    
    // Try first large image in content
    final img = document.querySelector('.sqs-html-content img, .content-wrapper img');
    return img?.attributes['src'];
  }

  /// Parses a Squarespace content block that uses <br> tags for line breaks
  /// and <strong> tags for section headers.
  /// 
  /// StarChefs format: `<strong>Section:<br></strong>content<br>content`
  /// The <br> is INSIDE the strong tag, so after split we get:
  /// - `<strong>Section:` (section header, partial)
  /// - `</strong>content` (closing tag + first content item)
  List<String> _parseSquarespaceBlock(Element block, {required bool isIngredients}) {
    final results = <String>[];
    
    // Find all <p> elements in the block
    final paragraphs = block.querySelectorAll('p');
    
    for (final p in paragraphs) {
      // Get inner HTML and split by <br> tags
      final html = p.innerHtml;
      final lines = html.split(RegExp(r'<br\s*/?>'));
      
      String? pendingSection;
      
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        // Pattern 1: Opening strong tag with section name (the <br> was inside)
        // e.g., "<strong>Short Ribs:" - we'll capture the section and wait for next line
        final openingSectionMatch = RegExp(r'^<strong>([^<:]+):\s*$', caseSensitive: false).firstMatch(line);
        if (openingSectionMatch != null) {
          final sectionName = openingSectionMatch.group(1)?.trim();
          if (sectionName != null && 
              sectionName.toUpperCase() != 'INGREDIENTS' && 
              sectionName.toUpperCase() != 'METHOD') {
            pendingSection = sectionName;
          }
          continue;
        }
        
        // Pattern 2: Closing strong tag followed by content
        // e.g., "</strong>¾ cup soy sauce" - emit section header then content
        final closingWithContentMatch = RegExp(r'^</strong>\s*(.*)$', caseSensitive: false).firstMatch(line);
        if (closingWithContentMatch != null) {
          // First emit the pending section header
          if (pendingSection != null) {
            if (isIngredients) {
              results.add('[$pendingSection]');
            } else {
              results.add('For the $pendingSection:');
            }
            pendingSection = null;
          }
          
          // Then emit the content if any
          final content = closingWithContentMatch.group(1)?.trim() ?? '';
          if (content.isNotEmpty) {
            final cleanContent = _stripHtmlTags(content);
            if (cleanContent.isNotEmpty) {
              results.add(cleanContent);
            }
          }
          continue;
        }
        
        // Pattern 3: Complete section header on one line: <strong>Section:</strong>
        final completeSectionMatch = RegExp(r'^<strong>([^<:]+):?\s*</strong>$', caseSensitive: false).firstMatch(line);
        if (completeSectionMatch != null) {
          final sectionName = completeSectionMatch.group(1)?.trim();
          if (sectionName != null && 
              sectionName.toUpperCase() != 'INGREDIENTS' && 
              sectionName.toUpperCase() != 'METHOD') {
            if (isIngredients) {
              results.add('[$sectionName]');
            } else {
              results.add('For the $sectionName:');
            }
          }
          continue;
        }
        
        // Pattern 4: Inline section header with content: <strong>Section:</strong>content
        final inlineSectionMatch = RegExp(r'^<strong>([^<:]+):\s*</strong>\s*(.*)$', caseSensitive: false).firstMatch(line);
        if (inlineSectionMatch != null) {
          final sectionName = inlineSectionMatch.group(1)?.trim();
          final content = inlineSectionMatch.group(2)?.trim() ?? '';
          
          if (sectionName != null && 
              sectionName.toUpperCase() != 'INGREDIENTS' && 
              sectionName.toUpperCase() != 'METHOD') {
            if (isIngredients) {
              results.add('[$sectionName]');
            } else {
              results.add('For the $sectionName:');
            }
          }
          
          if (content.isNotEmpty) {
            final cleanContent = _stripHtmlTags(content);
            if (cleanContent.isNotEmpty) {
              results.add(cleanContent);
            }
          }
          continue;
        }
        
        // Regular content line - strip HTML tags and add
        final cleanLine = _stripHtmlTags(line);
        if (cleanLine.isNotEmpty && 
            cleanLine.toUpperCase() != 'INGREDIENTS:' && 
            cleanLine.toUpperCase() != 'METHOD:') {
          results.add(cleanLine);
        }
      }
    }
    
    return results;
  }

  String _stripHtmlTags(String html) {
    // Remove HTML tags and decode entities
    var text = html.replaceAll(RegExp(r'<[^>]+>'), '');
    return _ingParser.decodeHtml(text).trim();
  }
}

// --- YouTube Strategy ---
// Uses youtube_explode_dart for robust metadata extraction.
// This handles YouTube API changes automatically via the maintained package.

class YouTubeStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  YouTubeStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    return _extractYouTubeVideoId(url) != null ? 1.0 : 0.0;
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    final videoIdStr = _extractYouTubeVideoId(url);
    if (videoIdStr == null) throw Exception('Could not extract YouTube Video ID');

    final youtube = yt.YoutubeExplode();
    try {
      // Get video metadata using the video ID string
      final video = await youtube.videos.get(videoIdStr);
      final title = _cleanYouTubeTitle(video.title);
      final description = video.description;
      final thumbnailUrl = video.thumbnails.highResUrl;
      final duration = video.duration;

      // Parse description for recipe content
      final parsedDesc = _parseYouTubeDescription(description);
      final rawIngredients = (parsedDesc['ingredients'] as List<String>? ?? []);
      final ingredients = _ingParser.parseList(rawIngredients);

      // Extract directions from description or try closed captions
      List<String> directions = parsedDesc['directions'] ?? [];
      
      // If no directions in description, try chapters
      if (directions.isEmpty) {
        final chapters = _extractYouTubeChapters(description);
        if (chapters.isNotEmpty) {
          directions = chapters;
        }
      }
      
      // If still no directions and we have few ingredients, try closed captions
      if (directions.isEmpty && ingredients.length < 3) {
        directions = await _extractFromClosedCaptions(youtube, videoIdStr);
      }

      // Format time from duration
      String? timeStr;
      if (duration != null) {
        final minutes = duration.inMinutes;
        if (minutes >= 60) {
          timeStr = '${minutes ~/ 60}h ${minutes % 60}m';
        } else {
          timeStr = '${minutes}m';
        }
      }

      return RecipeImportResult(
        name: title,
        source: RecipeSource.url,
        sourceUrl: url,
        ingredients: ingredients,
        directions: directions,
        notes: parsedDesc['notes'],
        time: timeStr,
        imageUrl: thumbnailUrl,
        nameConfidence: 0.9,
        ingredientsConfidence: ingredients.isNotEmpty ? 0.7 : 0.3,
        directionsConfidence: directions.isNotEmpty ? 0.7 : 0.3,
      );
    } finally {
      youtube.close();
    }
  }
  
  /// Extract YouTube video ID from URL
  String? _extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    // youtube.com/watch?v=VIDEO_ID
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    // youtu.be/VIDEO_ID
    if (uri.host == 'youtu.be') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  /// Try to extract recipe steps from closed captions
  Future<List<String>> _extractFromClosedCaptions(yt.YoutubeExplode youtube, String videoId) async {
    try {
      final manifest = await youtube.videos.closedCaptions.getManifest(videoId);
      final englishTracks = manifest.getByLanguage('en');
      
      if (englishTracks.isEmpty) {
        // Try first available track if no English
        if (manifest.tracks.isEmpty) return [];
        final firstTrack = manifest.tracks.first;
        final track = await youtube.videos.closedCaptions.get(firstTrack);
        return _extractStepsFromTrack(track);
      }
      
      final track = await youtube.videos.closedCaptions.get(englishTracks.first);
      return _extractStepsFromTrack(track);
    } catch (_) {
      return []; // Captions not available
    }
  }
  
  /// Extract cooking steps from a closed caption track
  List<String> _extractStepsFromTrack(yt.ClosedCaptionTrack track) {
    final steps = <String>[];
    final actionPattern = RegExp(
      r'^(add|mix|stir|pour|heat|cook|bake|preheat|combine|whisk|blend|chop|dice|slice|fold|simmer|boil|fry|grill|roast|season|serve)\b',
      caseSensitive: false,
    );
    
    for (final caption in track.captions) {
      final text = caption.text.trim();
      if (text.length > 20 && actionPattern.hasMatch(text)) {
        final step = text[0].toUpperCase() + text.substring(1);
        if (!steps.contains(step)) {
          steps.add(step);
        }
      }
    }
    
    return steps.take(15).toList();
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
      
      // Section header detection
      if (RegExp(r'^(ingredients?|shopping list)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'ingredients'; continue;
      } else if (RegExp(r'^(directions?|instructions?|method|steps?)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'directions'; continue;
      } else if (RegExp(r'^(notes?|tips?)[:\s]*$', caseSensitive: false).hasMatch(lower)) {
        currentSection = 'notes'; continue;
      }
      
      // Skip timestamp lines, URLs, and social links
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(line)) continue;
      if (line.contains('http://') || line.contains('https://')) continue;
      if (RegExp(r'(instagram|facebook|twitter|tiktok|subscribe|follow)', caseSensitive: false).hasMatch(lower)) continue;

      if (currentSection == 'ingredients') ingredients.add(line);
      else if (currentSection == 'directions') directions.add(line);
      else if (currentSection == 'notes') notes.add(line);
      else {
        // Auto-detect ingredient lines by measurement patterns
        if (RegExp(r'\d+\s*(?:cup|cups|tbsp|tsp|g|oz|ml|lb|kg)', caseSensitive: false).hasMatch(line)) {
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

  List<String> _extractYouTubeChapters(String description) {
    final chapters = <String>[];
    final lines = description.split('\n');
    for (var line in lines) {
      final match = RegExp(r'^(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)').firstMatch(line.trim());
      if (match != null) {
        chapters.add(match.group(2)!.trim());
      }
    }
    return chapters;
  }
}

// --- Standard Web Strategy ---
// Robust generic strategy that handles most recipe sites using:
// 1. JSON-LD (Schema.org Recipe)
// 2. Embedded JS frameworks (Next.js, Nuxt, Vite SSR)
// 3. Microdata (itemprop selectors)
// 4. HTML heuristics (common class/id patterns)

class StandardWebStrategy implements RecipeParserStrategy {
  final IngredientParser _ingParser;
  StandardWebStrategy(this._ingParser);

  @override
  double canParse(String url, Document? document, String? rawBody) {
    if (document == null) return 0.3;
    
    // Check for structured data presence to boost confidence
    final hasJsonLd = document.querySelector('script[type="application/ld+json"]') != null;
    final hasMicrodata = document.querySelector('[itemtype*="Recipe"]') != null;
    
    if (hasJsonLd || hasMicrodata) return 0.7;
    return 0.5; // Default fallback
  }

  @override
  Future<RecipeImportResult?> parse(String url, Document? document, String? rawBody) async {
    if (document == null) return null;

    RecipeImportResult? result;
    
    // 1. Try JSON-LD first (most reliable)
    result = _parseJsonLd(document, url);
    if (result != null) {
      // Check if we can enhance with HTML sections
      result = _enhanceWithHtmlSections(document, result);
    }

    // 2. Try embedded JS frameworks (Next.js, Nuxt, Vite SSR)
    if (result == null && rawBody != null) {
      result = _parseEmbeddedJs(rawBody, url);
    }

    // 3. Try microdata
    if (result == null) {
      result = _parseMicrodata(document, url);
    }

    // 4. HTML heuristic fallback
    if (result == null) {
      result = _parseHtmlFallback(document, url, rawBody);
    }
    
    if (result == null) return null;
    
    // 5. Enhance with cocktail metadata (glass, garnish) for drink recipes
    if (_isCocktailSite(url) || result.course == 'Drinks') {
      final cocktailData = _extractCocktailMetadata(document);
      final extractedGlass = cocktailData['glass'] as String?;
      final extractedGarnish = cocktailData['garnish'] as List<String>? ?? [];
      
      // Only update if we found metadata that's missing from result
      if ((result.glass == null && extractedGlass != null) || 
          (result.garnish.isEmpty && extractedGarnish.isNotEmpty)) {
        result = RecipeImportResult(
          name: result.name,
          course: result.course ?? 'Drinks',
          cuisine: result.cuisine,
          subcategory: result.subcategory,
          serves: result.serves,
          time: result.time,
          ingredients: result.ingredients,
          directions: result.directions,
          notes: result.notes,
          imageUrl: result.imageUrl,
          nutrition: result.nutrition,
          equipment: result.equipment,
          glass: extractedGlass ?? result.glass,
          garnish: extractedGarnish.isNotEmpty ? extractedGarnish : result.garnish,
          sourceUrl: result.sourceUrl,
          source: result.source,
          nameConfidence: result.nameConfidence,
          ingredientsConfidence: result.ingredientsConfidence,
          directionsConfidence: result.directionsConfidence,
          servesConfidence: result.servesConfidence,
          timeConfidence: result.timeConfidence,
          courseConfidence: result.courseConfidence,
          cuisineConfidence: result.cuisineConfidence,
        );
      }
    }
    
    return result;
  }

  // ========== JSON-LD Parsing ==========
  
  RecipeImportResult? _parseJsonLd(Document document, String url) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        // Handle encoding issues
        String scriptText = script.text;
        dynamic data;
        try {
          data = jsonDecode(scriptText);
        } on FormatException {
          // Try to fix common encoding issues
          final fixed = scriptText.replaceAll('\n', '\\n').replaceAll('\r', '');
          data = jsonDecode(fixed);
        }
        
        // Find Recipe object (handles @graph, arrays, nested)
        final recipeData = _findRecipeInJson(data);
        if (recipeData == null) continue;

        return _parseRecipeJson(recipeData, url, isJsonLd: true);
      } catch (_) { continue; }
    }
    return null;
  }

  /// Recursively find Recipe object in JSON-LD structure
  dynamic _findRecipeInJson(dynamic data, [int depth = 0]) {
    if (depth > 10) return null;
    
    if (data is Map<String, dynamic>) {
      // Check if this is a Recipe
      final type = data['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        return data;
      }
      
      // Check @graph
      if (data['@graph'] is List) {
        for (final item in data['@graph']) {
          final found = _findRecipeInJson(item, depth + 1);
          if (found != null) return found;
        }
      }
      
      // Recursively check values
      for (final value in data.values) {
        final found = _findRecipeInJson(value, depth + 1);
        if (found != null) return found;
      }
    } else if (data is List) {
      for (final item in data) {
        final found = _findRecipeInJson(item, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Parse a recipe JSON object (works for JSON-LD and embedded JS)
  RecipeImportResult? _parseRecipeJson(Map<String, dynamic> data, String url, {bool isJsonLd = false}) {
    // Extract name
    final name = _parseString(data['name'] ?? data['title'] ?? data['recipeName']);
    if (name == null || name.isEmpty) return null;
    
    // Extract ingredients with section support
    final rawIngs = _extractRawIngredients(data['recipeIngredient'] ?? data['ingredients']);
    
    // Extract directions
    final rawDirs = _extractDirections(data['recipeInstructions'] ?? data['instructions'] ?? data['directions'] ?? data['steps']);
    
    if (rawIngs.isEmpty && rawDirs.isEmpty) return null;
    
    // Parse ingredients
    final ingredients = _ingParser.parseList(rawIngs);
    
    // Extract other fields
    final serves = _parseString(data['recipeYield'] ?? data['yield'] ?? data['serves']);
    final time = _parseTime(data);
    final imageUrl = _parseImage(data['image']);
    final description = _parseString(data['description']);
    final cuisine = _parseString(data['recipeCuisine'] ?? data['cuisine']);
    final course = _guessCourse(data, url);
    
    // Nutrition
    NutritionInfo? nutrition;
    if (data['nutrition'] is Map) {
      nutrition = _parseNutrition(data['nutrition'] as Map<String, dynamic>);
    }
    
    // Equipment (not standard Schema.org but some sites include it)
    final equipment = _extractStringList(data['tool'] ?? data['equipment']);
    
    return RecipeImportResult(
      name: _ingParser.decodeHtml(name),
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: ingredients,
      directions: rawDirs,
      serves: serves,
      time: time,
      imageUrl: imageUrl,
      notes: description,
      cuisine: cuisine,
      course: course,
      nutrition: nutrition,
      equipment: equipment,
      nameConfidence: 0.95,
      ingredientsConfidence: rawIngs.isNotEmpty ? 0.9 : 0.0,
      directionsConfidence: rawDirs.isNotEmpty ? 0.9 : 0.0,
      servesConfidence: serves != null ? 0.8 : 0.0,
      timeConfidence: time != null ? 0.8 : 0.0,
      courseConfidence: course != null ? 0.7 : 0.3,
      cuisineConfidence: cuisine != null ? 0.8 : 0.0,
    );
  }

  /// Extract raw ingredients, handling various formats including sections
  List<String> _extractRawIngredients(dynamic data) {
    if (data == null) return [];
    if (data is String) return [data];
    
    if (data is List) {
      final results = <String>[];
      
      for (final item in data) {
        if (item is String) {
          results.add(item);
        } else if (item is Map) {
          // Handle sectioned ingredients (WordPress ACF, Great British Chefs, etc.)
          // Format: {groupName: "Sauce", items: [...]} or {section: "Sauce", ingredients: [...]}
          final sectionName = item['groupName'] ?? item['section'] ?? item['title'];
          final sectionItems = item['items'] ?? item['ingredients'] ?? item['unstructuredTextMetric'];
          
          if (sectionName != null && sectionItems != null) {
            results.add('[$sectionName]');
            if (sectionItems is List) {
              for (final si in sectionItems) {
                final text = si is String ? si : (si is Map ? (si['text'] ?? si['name'] ?? si['unstructuredTextMetric']) : si.toString());
                if (text != null) results.add(text.toString());
              }
            } else if (sectionItems is String) {
              results.add(sectionItems);
            }
          } else {
            // Regular ingredient object
            final text = item['text'] ?? item['name'] ?? item['unstructuredTextMetric'];
            if (text != null) results.add(text.toString());
          }
        }
      }
      return results;
    }
    return [];
  }

  /// Extract directions, handling HowToStep, HowToSection, etc.
  List<String> _extractDirections(dynamic data) {
    if (data == null) return [];
    if (data is String) return data.split(RegExp(r'\n+'));
    
    if (data is List) {
      final results = <String>[];
      
      for (final item in data) {
        if (item is String) {
          results.add(_cleanDirectionStep(item));
        } else if (item is Map) {
          // HowToSection - has itemListElement with steps
          if (item['@type'] == 'HowToSection' && item['itemListElement'] is List) {
            final sectionName = item['name'];
            if (sectionName != null) results.add('**$sectionName**');
            results.addAll(_extractDirections(item['itemListElement']));
          }
          // HowToStep
          else {
            final text = item['text'] ?? item['name'];
            if (text != null) results.add(_cleanDirectionStep(text.toString()));
          }
        }
      }
      return results;
    }
    return [];
  }

  String _cleanDirectionStep(String step) {
    // Remove step numbers at the beginning
    var cleaned = step.replaceFirst(RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false), '');
    return _ingParser.decodeHtml(cleaned.trim());
  }

  // ========== Embedded JS Parsing (Next.js, Nuxt, Vite SSR) ==========
  
  RecipeImportResult? _parseEmbeddedJs(String body, String url) {
    final patterns = <String, RegExp>{
      'next': RegExp(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true),
      'nuxt': RegExp(r'window\.__NUXT__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      'vite': RegExp(r'<script[^>]*id="vite-plugin-ssr_pageContext"[^>]*>(.*?)</script>', dotAll: true),
    };
    
    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(body);
      if (match == null) continue;
      
      final jsonStr = match.group(1);
      if (jsonStr == null || jsonStr.isEmpty) continue;
      
      try {
        final data = jsonDecode(jsonStr);
        if (data is! Map<String, dynamic>) continue;
        
        // Search for recipe data within the embedded JSON
        final recipeData = _findRecipeInEmbeddedData(data);
        if (recipeData != null) {
          return _parseRecipeJson(recipeData, url);
        }
      } catch (_) { continue; }
    }
    return null;
  }

  /// Find recipe data in embedded JS structures (different paths for different frameworks)
  Map<String, dynamic>? _findRecipeInEmbeddedData(Map<String, dynamic> data, [int depth = 0]) {
    if (depth > 10) return null;
    
    // Common paths for recipe data
    final commonPaths = [
      ['pageContext', 'pageProps', 'config'],  // Vite SSR
      ['pageContext', 'pageProps'],
      ['props', 'pageProps'],  // Next.js
      ['props', 'pageProps', 'recipe'],
      ['data'],  // Nuxt
      ['state', 'recipe'],
    ];
    
    for (final path in commonPaths) {
      dynamic current = data;
      for (final key in path) {
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is Map<String, dynamic> && _looksLikeRecipe(current)) {
        return current;
      }
    }
    
    // Recursive search
    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        if (_looksLikeRecipe(value)) return value;
        final found = _findRecipeInEmbeddedData(value, depth + 1);
        if (found != null) return found;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            if (_looksLikeRecipe(item)) return item;
            final found = _findRecipeInEmbeddedData(item, depth + 1);
            if (found != null) return found;
          }
        }
      }
    }
    return null;
  }

  bool _looksLikeRecipe(Map<String, dynamic> data) {
    final hasName = data.containsKey('name') || data.containsKey('title') || data.containsKey('recipeName');
    if (!hasName) return false;
    final hasIngredients = data.containsKey('recipeIngredient') || data.containsKey('ingredients');
    final hasInstructions = data.containsKey('recipeInstructions') || data.containsKey('instructions') || data.containsKey('directions');
    return hasIngredients || hasInstructions;
  }

  // ========== Microdata Parsing ==========
  
  RecipeImportResult? _parseMicrodata(Document document, String url) {
    final recipeElement = document.querySelector('[itemtype*="Recipe"]');
    if (recipeElement == null) return null;
    
    final name = recipeElement.querySelector('[itemprop="name"]')?.text.trim();
    if (name == null || name.isEmpty) return null;
    
    // Ingredients
    final ingElements = recipeElement.querySelectorAll('[itemprop="recipeIngredient"], [itemprop="ingredients"]');
    final rawIngs = ingElements.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
    
    // Directions
    final dirElements = recipeElement.querySelectorAll('[itemprop="recipeInstructions"]');
    List<String> directions = [];
    for (final el in dirElements) {
      // Check if it's a container with li children
      final liChildren = el.querySelectorAll('li');
      if (liChildren.isNotEmpty) {
        directions.addAll(liChildren.map((li) => _cleanDirectionStep(li.text.trim())));
      } else {
        directions.add(_cleanDirectionStep(el.text.trim()));
      }
    }
    
    if (rawIngs.isEmpty && directions.isEmpty) return null;
    
    // Other fields
    final serves = recipeElement.querySelector('[itemprop="recipeYield"]')?.text.trim();
    final imageUrl = recipeElement.querySelector('[itemprop="image"]')?.attributes['src'] ??
                     recipeElement.querySelector('[itemprop="image"]')?.attributes['content'];
    
    return RecipeImportResult(
      name: _ingParser.decodeHtml(name),
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: _ingParser.parseList(rawIngs),
      directions: directions,
      serves: serves,
      imageUrl: imageUrl,
      nameConfidence: 0.9,
      ingredientsConfidence: rawIngs.isNotEmpty ? 0.85 : 0.0,
      directionsConfidence: directions.isNotEmpty ? 0.85 : 0.0,
    );
  }

  // ========== HTML Parsing with Site Configs ==========
  
  RecipeImportResult? _parseHtmlFallback(Document document, String url, String? rawBody) {
    var rawIngredientStrings = <String>[];
    var rawDirections = <String>[];
    String? title = document.querySelector('h1')?.text.trim();
    title ??= document.querySelector('meta[property="og:title"]')?.attributes['content'];

    // 1. Try Site Configs (targeted plugin patterns)
    final configResult = _tryAllSiteConfigs(document);
    if (configResult != null && configResult.isNotEmpty) {
      rawIngredientStrings = configResult;
    }

    // 2. Try specific plugin selectors
    if (rawIngredientStrings.isEmpty) {
      // Cooked plugin
      final cooked = document.querySelectorAll('.cooked-single-ingredient');
      if (cooked.isNotEmpty) {
        rawIngredientStrings = cooked.map((e) => 
          '${e.querySelector('.cooked-ing-amount')?.text ?? ""} ${e.querySelector('.cooked-ing-name')?.text ?? ""}'.trim()
        ).where((s) => s.isNotEmpty).toList();
      }
      
      // Tasty Recipes
      if (rawIngredientStrings.isEmpty) {
        final tasty = document.querySelectorAll('.tasty-recipes-ingredients li, .tasty-recipes-ingredient');
        if (tasty.isNotEmpty) rawIngredientStrings = tasty.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
      }
      
      // Generic selectors
      if (rawIngredientStrings.isEmpty) {
        final generic = document.querySelectorAll('.recipe-ingredients li, .recipe-ingred_txt, .ingredient-item, [itemprop="recipeIngredient"]');
        if (generic.isNotEmpty) rawIngredientStrings = generic.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    // 3. Section-based parsing (H2/H3 with "Ingredients" followed by list)
    if (rawIngredientStrings.isEmpty) {
      rawIngredientStrings = _parseIngredientsBySections(document);
    }

    // 4. Aggressive fallback: scan all lists for ingredient-like lines
    if (rawIngredientStrings.isEmpty) {
      final allLists = document.querySelectorAll('ul li, ol li');
      for (final li in allLists) {
        final text = li.text.trim();
        if (_couldBeIngredientLine(text)) {
          rawIngredientStrings.add(text);
        }
      }
    }
    
    // 5. Bullet-point text fallback (e.g., Modernist Pantry uses • bullets in divs/spans)
    if (rawIngredientStrings.isEmpty && rawBody != null) {
      rawIngredientStrings = _extractBulletPointIngredients(rawBody);
    }

    // Directions parsing
    final dirSelectors = [
      '.wprm-recipe-instruction',
      '.tasty-recipes-instructions li',
      '[itemprop="recipeInstructions"] li',
      '.instructions li',
      '.directions li',
      '.recipe-directions li',
      '.recipe-procedure li',
      '.method li',
      '#directions li',
      '#instructions li',
    ];
    
    for (final sel in dirSelectors) {
      try {
        final els = document.querySelectorAll(sel);
        if (els.isNotEmpty) {
          rawDirections = els.map((e) => _cleanDirectionStep(e.text.trim())).where((s) => s.isNotEmpty).toList();
          break;
        }
      } catch (_) { continue; }
    }
    
    // Fallback: section-based directions
    if (rawDirections.isEmpty) {
      rawDirections = _parseDirectionsBySections(document);
    }

    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) return null;

    return RecipeImportResult(
      name: _ingParser.decodeHtml(title ?? 'Untitled Recipe'),
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: _ingParser.parseList(rawIngredientStrings),
      directions: rawDirections,
      imageUrl: _extractImageFromHtml(document),
      nameConfidence: title != null ? 0.7 : 0.3,
      ingredientsConfidence: rawIngredientStrings.isNotEmpty ? 0.6 : 0.0,
      directionsConfidence: rawDirections.isNotEmpty ? 0.6 : 0.0,
    );
  }

  /// Try all site configs and return ingredients if any match
  List<String>? _tryAllSiteConfigs(Document document) {
    for (final entry in _siteConfigs.entries) {
      final config = entry.value;
      Element container = document.documentElement!;
      
      if (config.containerSelector != null) {
        final found = document.querySelector(config.containerSelector!);
        if (found == null) continue;
        container = found;
      }

      final ingredients = <String>[];

      if (config.mode == ExtractionMode.containerWithSections) {
        if (config.sectionSelector != null) {
          final sections = container.querySelectorAll(config.sectionSelector!);
          for (final section in sections) {
            String? header;
            if (config.headerIsDirectChild && config.headerChildTag != null) {
              header = section.querySelector(config.headerChildTag!)?.text.trim();
            } else if (config.headerSelector != null) {
              header = section.querySelector(config.headerSelector!)?.text.trim();
            }
            if (header != null && header.isNotEmpty) ingredients.add('[$header]');
            
            final items = section.querySelectorAll(config.ingredientSelector);
            ingredients.addAll(items.map((e) => e.text.trim()).where((s) => s.isNotEmpty));
          }
        }
      } else if (config.mode == ExtractionMode.siblingHeaderList && config.headerSelector != null) {
        final headers = container.querySelectorAll(config.headerSelector!);
        for (final header in headers) {
          final headerText = header.text.trim();
          if (headerText.isNotEmpty) ingredients.add('[$headerText]');
          
          var sibling = header.nextElementSibling;
          while (sibling != null && (sibling.localName == 'ul' || sibling.localName == 'ol')) {
            ingredients.addAll(sibling.querySelectorAll('li').map((e) => e.text.trim()).where((s) => s.isNotEmpty));
            sibling = sibling.nextElementSibling;
          }
        }
      } else {
        final items = container.querySelectorAll(config.ingredientSelector);
        ingredients.addAll(items.map((e) => e.text.trim()).where((s) => s.isNotEmpty));
      }

      if (ingredients.isNotEmpty) return ingredients;
    }
    return null;
  }

  List<String> _parseIngredientsBySections(Document document) {
    final ingredients = <String>[];
    final headings = document.querySelectorAll('h2, h3, h4');
    
    for (final heading in headings) {
      final text = heading.text.toLowerCase();
      if (text.contains('ingredient')) {
        var sibling = heading.nextElementSibling;
        int attempts = 0;
        while (sibling != null && attempts < 5) {
          if (sibling.localName == 'ul' || sibling.localName == 'ol') {
            ingredients.addAll(sibling.querySelectorAll('li').map((e) => e.text.trim()).where((s) => s.isNotEmpty));
            break;
          }
          sibling = sibling.nextElementSibling;
          attempts++;
        }
      }
    }
    return ingredients;
  }

  List<String> _parseDirectionsBySections(Document document) {
    final directions = <String>[];
    final headings = document.querySelectorAll('h2, h3, h4');
    
    for (final heading in headings) {
      final text = heading.text.toLowerCase();
      if (text.contains('direction') || text.contains('instruction') || text.contains('method') || text.contains('step')) {
        var sibling = heading.nextElementSibling;
        int attempts = 0;
        while (sibling != null && attempts < 5) {
          if (sibling.localName == 'ul' || sibling.localName == 'ol') {
            directions.addAll(sibling.querySelectorAll('li').map((e) => _cleanDirectionStep(e.text.trim())).where((s) => s.isNotEmpty));
            break;
          } else if (sibling.localName == 'p') {
            final pText = sibling.text.trim();
            if (pText.isNotEmpty && pText.length > 20) {
              directions.add(_cleanDirectionStep(pText));
            }
          }
          sibling = sibling.nextElementSibling;
          attempts++;
        }
      }
    }
    return directions;
  }

  bool _couldBeIngredientLine(String text) {
    if (text.isEmpty || text.length > 150) return false;
    return RegExp(r'\d+\s*(?:g|oz|cup|tbsp|tsp|ml|lb|kg)', caseSensitive: false).hasMatch(text);
  }

  String? _extractImageFromHtml(Document document) {
    // Try Schema
    var img = document.querySelector('[itemtype*="Recipe"] [itemprop="image"]');
    if (img != null) return _getSrc(img);
    
    // Try OG
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) return ogImage;
    
    // Try common classes
    img = document.querySelector('.recipe-image img, .wprm-recipe-image img, .tasty-recipes-image img');
    return _getSrc(img);
  }

  String? _getSrc(Element? el) {
    if (el == null) return null;
    return el.attributes['src'] ?? el.attributes['data-src'] ?? el.attributes['content'];
  }
  
  /// Extract ingredients from bullet-point formatted text (e.g., "• 200g (1 Cup) Sugar")
  /// Used for sites like Modernist Pantry that don't use <li> tags
  List<String> _extractBulletPointIngredients(String rawBody) {
    final ingredients = <String>[];
    
    // Remove scripts and styles first
    var cleanHtml = rawBody
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&bull;|&middot;|&#8226;|&#x2022;', caseSensitive: false), '•')
        .replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&#\d+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    
    // Split by bullet character
    final parts = cleanHtml.split('•');
    
    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty || part.length < 5 || part.length > 150) continue;
      
      // Take only the first line if multiple lines
      final newlineIdx = part.indexOf('\n');
      if (newlineIdx > 0 && newlineIdx < part.length - 1) {
        part = part.substring(0, newlineIdx);
      }
      
      // Check if this looks like an ingredient (has measurement)
      if (_couldBeIngredientLine(part)) {
        // Check if this might be a section header (ends with :)
        if (part.endsWith(':')) {
          final sectionName = part.substring(0, part.length - 1).trim();
          // Only treat as section if it looks like one (starts with "Ingredients" or similar)
          if (sectionName.toLowerCase().contains('ingredient')) {
            ingredients.add('[$sectionName]');
          }
        } else {
          ingredients.add(_ingParser.decodeHtml(part));
        }
      }
    }
    
    return ingredients.length >= 2 ? ingredients : [];
  }

  // ========== Enhancement with HTML Sections ==========
  
  /// Enhance JSON-LD result with section headers from HTML (many sites have flat JSON-LD but sectioned HTML)
  RecipeImportResult? _enhanceWithHtmlSections(Document document, RecipeImportResult result) {
    // Check if HTML has section structure that JSON-LD is missing
    final sectionSelectors = [
      '.ingredient-group-header',
      '.wprm-recipe-group-name',
      '.ingredient-section-name',
      '[class*="ingredientgroup_name"]',
      '.structured-ingredients__list-heading',
      '.ingredient-section',
      'li.category',
    ];
    
    bool hasHtmlSections = false;
    for (final selector in sectionSelectors) {
      if (document.querySelector(selector) != null) {
        hasHtmlSections = true;
        break;
      }
    }
    
    if (!hasHtmlSections) return result;
    
    // Extract ingredients with sections from HTML
    final sectioned = _extractSectionedIngredients(document);
    if (sectioned.isEmpty) return result;
    
    // Re-parse with sections
    final ingredients = _ingParser.parseList(sectioned);
    if (ingredients.isEmpty) return result;
    
    return RecipeImportResult(
      name: result.name,
      course: result.course,
      cuisine: result.cuisine,
      subcategory: result.subcategory,
      serves: result.serves,
      time: result.time,
      ingredients: ingredients,
      directions: result.directions,
      notes: result.notes,
      imageUrl: result.imageUrl,
      nutrition: result.nutrition,
      equipment: result.equipment,
      glass: result.glass,
      garnish: result.garnish,
      sourceUrl: result.sourceUrl,
      source: result.source,
      nameConfidence: result.nameConfidence,
      ingredientsConfidence: 0.9, // Higher with sections
      directionsConfidence: result.directionsConfidence,
      servesConfidence: result.servesConfidence,
      timeConfidence: result.timeConfidence,
      courseConfidence: result.courseConfidence,
      cuisineConfidence: result.cuisineConfidence,
    );
  }

  /// Extract ingredients with section headers from HTML
  List<String> _extractSectionedIngredients(Document document) {
    final results = <String>[];
    
    // Strategy 1: WPRM groups
    final wprmGroups = document.querySelectorAll('.wprm-recipe-ingredient-group');
    if (wprmGroups.isNotEmpty) {
      for (final group in wprmGroups) {
        final header = group.querySelector('.wprm-recipe-group-name')?.text.trim();
        if (header != null && header.isNotEmpty) results.add('[$header]');
        for (final ing in group.querySelectorAll('.wprm-recipe-ingredient')) {
          final text = ing.text.trim();
          if (text.isNotEmpty) results.add(text);
        }
      }
      return results;
    }
    
    // Strategy 2: Structured ingredients (Serious Eats)
    final structuredLists = document.querySelectorAll('.structured-ingredients__list');
    if (structuredLists.isNotEmpty) {
      for (final list in structuredLists) {
        // Look for heading before the list
        final heading = list.previousElementSibling;
        if (heading != null && heading.localName == 'p' && heading.classes.contains('structured-ingredients__list-heading')) {
          results.add('[${heading.text.trim()}]');
        }
        for (final li in list.querySelectorAll('li')) {
          final text = li.text.trim();
          if (text.isNotEmpty) results.add(text);
        }
      }
      return results;
    }
    
    // Strategy 3: Generic section/group containers
    for (final selector in ['.ingredient-section', '.ingredients__section']) {
      final sections = document.querySelectorAll(selector);
      if (sections.isNotEmpty) {
        for (final section in sections) {
          final header = section.querySelector('h3, h4, p:first-child, .ingredient-section-name')?.text.trim();
          if (header != null && header.isNotEmpty) results.add('[$header]');
          for (final li in section.querySelectorAll('li')) {
            final text = li.text.trim();
            if (text.isNotEmpty) results.add(text);
          }
        }
        return results;
      }
    }
    
    return results;
  }

  // ========== Utility Methods ==========
  
  String? _parseString(dynamic data) {
    if (data == null) return null;
    if (data is String) return data.trim().isEmpty ? null : data.trim();
    if (data is List && data.isNotEmpty) return _parseString(data.first);
    if (data is num) return data.toString();
    return data.toString();
  }

  String? _parseImage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is List && data.isNotEmpty) return _parseImage(data.first);
    if (data is Map) return data['url'] as String? ?? data['contentUrl'] as String?;
    return null;
  }
  
  String? _parseTime(Map<String, dynamic> data) {
    // Try various time fields
    final totalTime = data['totalTime'] ?? data['cookTime'] ?? data['prepTime'] ?? data['time'];
    if (totalTime == null) return null;
    
    final str = totalTime.toString();
    
    // Parse ISO 8601 duration (PT30M, PT1H30M, etc.)
    final durationMatch = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(str);
    if (durationMatch != null) {
      final hours = int.tryParse(durationMatch.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(durationMatch.group(2) ?? '') ?? 0;
      
      if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
      if (hours > 0) return '${hours}h';
      if (minutes > 0) return '${minutes} min';
    }
    
    return str;
  }
  
  NutritionInfo? _parseNutrition(Map<String, dynamic> data) {
    final caloriesStr = _parseString(data['calories']);
    if (caloriesStr == null) return null;
    
    // Parse calories as int (extract number from string like "200 kcal")
    final caloriesNum = _parseNutritionNumber(caloriesStr);
    if (caloriesNum == null) return null;
    
    return NutritionInfo.create(
      servingSize: _parseString(data['servingSize']),
      calories: caloriesNum.round(),
      fatContent: _parseNutritionNumber(_parseString(data['fatContent'])),
      saturatedFatContent: _parseNutritionNumber(_parseString(data['saturatedFatContent'])),
      transFatContent: _parseNutritionNumber(_parseString(data['transFatContent'])),
      cholesterolContent: _parseNutritionNumber(_parseString(data['cholesterolContent'])),
      sodiumContent: _parseNutritionNumber(_parseString(data['sodiumContent'])),
      carbohydrateContent: _parseNutritionNumber(_parseString(data['carbohydrateContent'])),
      fiberContent: _parseNutritionNumber(_parseString(data['fiberContent'])),
      sugarContent: _parseNutritionNumber(_parseString(data['sugarContent'])),
      proteinContent: _parseNutritionNumber(_parseString(data['proteinContent'])),
    );
  }
  
  /// Parse a nutrition value that might be a number or string like "20 g"
  double? _parseNutritionNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    // Extract numeric portion from strings like "20 g", "150 kcal", "5.5g"
    final match = RegExp(r'([\d.]+)').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }
  
  List<String> _extractStringList(dynamic data) {
    if (data == null) return [];
    if (data is String) return [data];
    if (data is List) {
      return data.map((e) => e is String ? e : e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
  
  String? _guessCourse(Map<String, dynamic> data, String url) {
    // Check explicit category
    final category = data['recipeCategory'] ?? data['category'] ?? data['course'];
    if (category != null) {
      final cat = category is List ? category.first.toString() : category.toString();
      return _normalizeCourse(cat);
    }
    
    // Guess from URL or name
    final urlLower = url.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    
    if (urlLower.contains('/drink') || urlLower.contains('/cocktail') || name.contains('cocktail')) return 'Drinks';
    if (urlLower.contains('/dessert') || name.contains('cake') || name.contains('cookie')) return 'Desserts';
    if (urlLower.contains('/appetizer') || urlLower.contains('/starter')) return 'Apps';
    if (urlLower.contains('/soup')) return 'Soup';
    if (urlLower.contains('/salad')) return 'Sides';
    if (urlLower.contains('/bread')) return 'Breads';
    if (urlLower.contains('/breakfast') || urlLower.contains('/brunch')) return 'Brunch';
    
    return 'Mains'; // Default
  }
  
  String _normalizeCourse(String course) {
    final lower = course.toLowerCase().trim();
    if (lower.contains('main') || lower.contains('dinner') || lower.contains('entree')) return 'Mains';
    if (lower.contains('appetizer') || lower.contains('starter') || lower.contains('app')) return 'Apps';
    if (lower.contains('dessert') || lower.contains('sweet')) return 'Desserts';
    if (lower.contains('drink') || lower.contains('beverage') || lower.contains('cocktail')) return 'Drinks';
    if (lower.contains('soup')) return 'Soup';
    if (lower.contains('salad') || lower.contains('side')) return 'Sides';
    if (lower.contains('bread') || lower.contains('baking')) return 'Breads';
    if (lower.contains('breakfast') || lower.contains('brunch')) return 'Brunch';
    if (lower.contains('sauce') || lower.contains('dip')) return 'Sauces';
    return course; // Return as-is if no match
  }

  // ========== Cocktail Metadata Extraction ==========
  
  /// Extract glass and garnish from HTML for drink recipes
  /// Handles multiple patterns from different cocktail sites
  Map<String, dynamic> _extractCocktailMetadata(Document document) {
    String? glass;
    List<String> garnish = [];
    
    // Pattern 1: Combined "Glass and Garnish" heading (Seedlip style)
    for (final heading in document.querySelectorAll('h2, h3')) {
      final headingText = heading.text.toLowerCase().trim();
      if (headingText.contains('glass') && headingText.contains('garnish')) {
        final items = _extractListAfterHeading(heading);
        if (items.isNotEmpty) {
          glass = items.first;
          if (items.length > 1) garnish = items.sublist(1);
        }
        break;
      }
    }
    
    // Pattern 2: H3 "Glass:" heading (Diffords style)
    if (glass == null) {
      for (final h3 in document.querySelectorAll('h3')) {
        final h3Text = h3.text.toLowerCase().trim();
        if (h3Text == 'glass:' || h3Text == 'glass' || h3Text.startsWith('glass:')) {
          final nextElem = h3.nextElementSibling;
          if (nextElem != null) {
            // Try link inside paragraph first
            final glassLink = nextElem.querySelector('a');
            if (glassLink != null) {
              final linkText = _ingParser.decodeHtml(glassLink.text.trim());
              if (linkText.isNotEmpty) {
                glass = linkText;
                break;
              }
            }
            // Fallback to paragraph text
            var glassText = _ingParser.decodeHtml(nextElem.text.trim());
            // Handle "Serve in a [Glass Type]" pattern
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(glassText);
            if (serveInMatch != null) {
              glassText = serveInMatch.group(1)?.trim() ?? glassText;
            }
            if (glassText.isNotEmpty) glass = glassText;
          }
          break;
        }
      }
    }
    
    // Pattern 2b: Diffords legacy-longform-heading class for "Glass:"
    if (glass == null) {
      for (final heading in document.querySelectorAll('.legacy-longform-heading')) {
        final headingText = heading.text.toLowerCase().trim();
        if (headingText == 'glass:') {
          final parent = heading.parent;
          if (parent != null) {
            final glassLink = parent.querySelector('a');
            if (glassLink != null) {
              final linkText = _ingParser.decodeHtml(glassLink.text.trim());
              if (linkText.isNotEmpty) {
                glass = linkText;
                break;
              }
            }
            var parentText = _ingParser.decodeHtml(parent.text.trim());
            parentText = parentText.replaceFirst(RegExp(r'^Glass:\s*', caseSensitive: false), '').trim();
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(parentText);
            if (serveInMatch != null) {
              parentText = serveInMatch.group(1)?.trim() ?? parentText;
            }
            if (parentText.isNotEmpty) {
              glass = parentText;
              break;
            }
          }
        }
      }
    }
    
    // Pattern 3: Inline "Garnish:" span (Diffords style)
    if (garnish.isEmpty) {
      for (final span in document.querySelectorAll('span')) {
        final spanText = span.text.toLowerCase().trim();
        if (spanText == 'garnish:' || spanText == 'garnish') {
          final parent = span.parent;
          if (parent != null) {
            var parentText = _ingParser.decodeHtml(parent.text.trim());
            parentText = parentText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
            if (parentText.isNotEmpty) {
              garnish = _splitGarnishText(parentText);
            }
          }
          break;
        }
      }
    }
    
    // Pattern 3b: Paragraphs starting with "Garnish:"
    if (garnish.isEmpty) {
      for (final p in document.querySelectorAll('p')) {
        final pText = p.text.trim();
        if (pText.toLowerCase().startsWith('garnish:')) {
          var garnishText = pText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
          if (garnishText.isNotEmpty) {
            garnish = _splitGarnishText(garnishText);
          }
          break;
        }
      }
    }
    
    // Pattern 4: garn-glass class (Punch style)
    if (garnish.isEmpty || glass == null) {
      final garnGlass = document.querySelector('.garn-glass, .garnish-glass');
      if (garnGlass != null) {
        final fullText = _ingParser.decodeHtml(garnGlass.text.trim());
        final garnishMatch = RegExp(r'Garnish:\s*(.+?)(?:\s*Glass:|$)', caseSensitive: false).firstMatch(fullText);
        if (garnishMatch != null && garnish.isEmpty) {
          final garnishText = garnishMatch.group(1)?.trim() ?? '';
          if (garnishText.isNotEmpty) garnish = _splitGarnishText(garnishText);
        }
        final glassMatch = RegExp(r'Glass:\s*(.+?)(?:\s*Garnish:|$)', caseSensitive: false).firstMatch(fullText);
        if (glassMatch != null && glass == null) {
          glass = glassMatch.group(1)?.trim();
        }
      }
    }
    
    // Pattern 5: "Serve in a" text in paragraphs
    if (glass == null) {
      for (final p in document.querySelectorAll('p')) {
        final pText = p.text.trim();
        final serveInMatch = RegExp(
          r'Serve\s+in\s+(?:a\s+)?([A-Za-z][A-Za-z\s\-]+(?:glass|flute|coupe|tumbler|goblet|snifter|mug|cup))',
          caseSensitive: false
        ).firstMatch(pText);
        if (serveInMatch != null) {
          glass = serveInMatch.group(1)?.trim();
          break;
        }
      }
    }
    
    // Pattern 6: Diffords-style table (legacy-ingredients-table)
    // Also look for separate glass/garnish headings
    for (final heading in document.querySelectorAll('h2, h3')) {
      final headingText = heading.text.toLowerCase().trim();
      
      if (headingText.contains('glass') && glass == null) {
        final items = _extractListAfterHeading(heading);
        if (items.isNotEmpty) {
          glass = items.first;
        } else {
          final nextElem = heading.nextElementSibling;
          if (nextElem != null) {
            final glassText = _ingParser.decodeHtml(nextElem.text.trim());
            if (glassText.isNotEmpty) glass = glassText;
          }
        }
      }
      
      if (headingText.contains('garnish') && garnish.isEmpty) {
        var items = _extractListAfterHeading(heading);
        if (items.isEmpty) {
          final nextElem = heading.nextElementSibling;
          if (nextElem != null) {
            final garnishText = _ingParser.decodeHtml(nextElem.text.trim());
            if (garnishText.isNotEmpty) {
              items = garnishText.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            }
          }
        }
        garnish = items;
      }
    }
    
    // Pattern 7: Lyres.com style - recipe-info divs with h4 titles
    if (glass == null || garnish.isEmpty) {
      for (final div in document.querySelectorAll('.recipe-info, div.recipe-info')) {
        final h4 = div.querySelector('h4, .title');
        if (h4 != null) {
          final titleText = h4.text.toLowerCase().trim();
          final p = div.querySelector('p');
          if (p != null) {
            final content = _ingParser.decodeHtml(p.text.trim());
            if (content.isNotEmpty) {
              if (titleText == 'glass' && glass == null) glass = content;
              else if (titleText == 'garnish' && garnish.isEmpty) garnish = _splitGarnishText(content);
            }
          }
        }
      }
    }
    
    return {'glass': glass, 'garnish': garnish};
  }
  
  /// Extract list items following a heading
  List<String> _extractListAfterHeading(Element heading) {
    final results = <String>[];
    var sibling = heading.nextElementSibling;
    int attempts = 0;
    
    while (sibling != null && attempts < 5) {
      if (sibling.localName == 'ul' || sibling.localName == 'ol') {
        for (final li in sibling.querySelectorAll('li')) {
          final text = _ingParser.decodeHtml(li.text.trim());
          if (text.isNotEmpty) results.add(text);
        }
        break;
      }
      // Stop if we hit another heading
      if (['h1', 'h2', 'h3', 'h4'].contains(sibling.localName)) break;
      sibling = sibling.nextElementSibling;
      attempts++;
    }
    return results;
  }
  
  /// Split garnish text intelligently - handles "X or Y" as separate items
  List<String> _splitGarnishText(String text) {
    if (text.isEmpty) return [];
    
    final commaSplit = text.split(RegExp(r',\s*'));
    final result = <String>[];
    
    for (final part in commaSplit) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Handle "X or Y peel" pattern -> ["X peel", "Y peel"]
      final orMatch = RegExp(r'^(.+?)\s+or\s+(.+)$', caseSensitive: false).firstMatch(trimmed);
      if (orMatch != null) {
        final firstPart = orMatch.group(1)?.trim() ?? '';
        final secondPart = orMatch.group(2)?.trim() ?? '';
        
        final words = secondPart.split(' ');
        if (words.length > 1) {
          final lastWord = words.last;
          if (!firstPart.toLowerCase().contains(lastWord.toLowerCase())) {
            result.add('$firstPart $lastWord');
            result.add(secondPart);
          } else {
            result.add(firstPart);
            result.add(secondPart);
          }
        } else {
          result.add(firstPart);
          result.add(secondPart);
        }
      } else {
        result.add(trimmed);
      }
    }
    
    return result.where((s) => s.isNotEmpty).toList();
  }
  
  /// Check if URL or content suggests this is a cocktail/drink recipe
  bool _isCocktailSite(String url) {
    final cocktailDomains = [
      'diffordsguide.com', 'liquor.com', 'punchdrink.com', 'imbibemagazine.com',
      'seedlipdrinks.com', 'lyres.com', 'thecocktailproject.com', 'makedrinks.com',
      'absolutdrinks.com', 'cocktails.lovetoknow.com',
    ];
    final urlLower = url.toLowerCase();
    return cocktailDomains.any((domain) => urlLower.contains(domain)) ||
           urlLower.contains('/cocktail') || urlLower.contains('/drink');
  }
}
