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
  // Punch Drink - cocktail recipes with .ingredients-list class
  // Note: Uses simple 'li' selector; hidden elements are filtered in code
  'punchdrink': SiteConfig(
    containerSelector: '.ingredients-list',
    ingredientSelector: 'li',
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
  /// 
  /// ALSO handles StarChefs concatenated format where ingredients run together:
  /// `Short Ribs:¾ cup soy sauce1 teaspoon granulated onion` 
  /// We split on measurement patterns like "¾ cup" or "1 teaspoon"
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
              // Check if content is concatenated (multiple ingredients on one line)
              if (isIngredients) {
                results.addAll(_splitConcatenatedIngredients(cleanContent));
              } else {
                results.add(cleanContent);
              }
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
              if (isIngredients) {
                results.addAll(_splitConcatenatedIngredients(cleanContent));
              } else {
                results.add(cleanContent);
              }
            }
          }
          continue;
        }
        
        // Regular content line - strip HTML tags and add
        final cleanLine = _stripHtmlTags(line);
        if (cleanLine.isNotEmpty && 
            cleanLine.toUpperCase() != 'INGREDIENTS:' && 
            cleanLine.toUpperCase() != 'METHOD:') {
          if (isIngredients) {
            results.addAll(_splitConcatenatedIngredients(cleanLine));
          } else {
            results.add(cleanLine);
          }
        }
      }
    }
    
    return results;
  }
  
  /// Split concatenated ingredients that run together without separators.
  /// E.g., "¾ cup soy sauce1 teaspoon granulated onion" -> ["¾ cup soy sauce", "1 teaspoon granulated onion"]
  List<String> _splitConcatenatedIngredients(String text) {
    // Pattern to match start of a new ingredient (measurement at start)
    // This captures: ¾, ½, 1/2, 1, 2½, etc. followed by unit
    final measurementPattern = RegExp(
      r'(?<=[a-zA-Z\s])([½¼¾⅓⅔⅛⅜⅝⅞]|\d+[½¼¾⅓⅔⅛⅜⅝⅞]?|\d+/\d+)\s*(cup|cups|teaspoon|teaspoons|tsp|tablespoon|tablespoons|tbsp|ounce|ounces|oz|pound|pounds|lb|lbs|gram|grams|g|kg|ml|liter|liters|clove|cloves|can|cans|slice|slices|piece|pieces|pinch|dash|sprig|sprigs|bunch|head|stalk|stalks|inch)\b',
      caseSensitive: false,
    );
    
    // If no pattern matches, return as-is
    final matches = measurementPattern.allMatches(text).toList();
    if (matches.isEmpty) return [text];
    
    final results = <String>[];
    int lastEnd = 0;
    
    for (final match in matches) {
      // Add the text before this match (the previous ingredient)
      if (match.start > lastEnd) {
        final prevIngredient = text.substring(lastEnd, match.start).trim();
        if (prevIngredient.isNotEmpty) {
          results.add(prevIngredient);
        }
      }
      lastEnd = match.start;
    }
    
    // Add the last ingredient
    if (lastEnd < text.length) {
      final lastIngredient = text.substring(lastEnd).trim();
      if (lastIngredient.isNotEmpty) {
        results.add(lastIngredient);
      }
    }
    
    return results.isEmpty ? [text] : results;
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

      // Extract recipe time from description (NOT video duration)
      // Prefer totalTime, otherwise combine prep + cook times
      String? timeStr = parsedDesc['totalTime'] as String?;
      if (timeStr == null) {
        final prepTime = parsedDesc['prepTime'] as String?;
        final cookTime = parsedDesc['cookTime'] as String?;
        if (prepTime != null && cookTime != null) {
          // Combine prep and cook times
          timeStr = _combineTimes(prepTime, cookTime);
        } else {
          // Use whichever is available
          timeStr = cookTime ?? prepTime;
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
    final result = <String, dynamic>{
      'ingredients': <String>[], 
      'directions': <String>[], 
      'notes': null,
      'prepTime': null,
      'cookTime': null,
      'totalTime': null,
    };
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
      
      // Extract time patterns like "Prep time: 15 min", "Cook time: 30 minutes", etc.
      final timePatterns = [
        RegExp(r'(?:total\s*time|ready\s*in)[:\s]*(\d+\s*(?:hour|hr|h|minute|min|m)(?:s|\s*\d+\s*(?:minute|min|m)s?)?)', caseSensitive: false),
        RegExp(r'(?:cook\s*time|cooking\s*time|bake\s*time)[:\s]*(\d+\s*(?:hour|hr|h|minute|min|m)(?:s|\s*\d+\s*(?:minute|min|m)s?)?)', caseSensitive: false),
        RegExp(r'(?:prep\s*time|preparation\s*time)[:\s]*(\d+\s*(?:hour|hr|h|minute|min|m)(?:s|\s*\d+\s*(?:minute|min|m)s?)?)', caseSensitive: false),
      ];
      
      for (var i = 0; i < timePatterns.length; i++) {
        final match = timePatterns[i].firstMatch(line);
        if (match != null) {
          final timeValue = _normalizeTimeString(match.group(1) ?? '');
          if (i == 0 && result['totalTime'] == null) result['totalTime'] = timeValue;
          if (i == 1 && result['cookTime'] == null) result['cookTime'] = timeValue;
          if (i == 2 && result['prepTime'] == null) result['prepTime'] = timeValue;
        }
      }
      
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
  
  /// Normalize time string to consistent format (e.g., "30 min", "1h 30m")
  String _normalizeTimeString(String time) {
    final lower = time.toLowerCase().trim();
    
    // Parse hours and minutes
    final hourMatch = RegExp(r'(\d+)\s*(?:hour|hr|h)').firstMatch(lower);
    final minMatch = RegExp(r'(\d+)\s*(?:minute|min|m)').firstMatch(lower);
    
    final hours = hourMatch != null ? int.tryParse(hourMatch.group(1) ?? '0') ?? 0 : 0;
    final minutes = minMatch != null ? int.tryParse(minMatch.group(1) ?? '0') ?? 0 : 0;
    
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes} min';
    return time.trim();
  }

  /// Parse time string into total minutes
  int? _parseTimeToMinutes(String time) {
    final lower = time.toLowerCase().trim();
    final hourMatch = RegExp(r'(\d+)\s*(?:hour|hr|h)').firstMatch(lower);
    final minMatch = RegExp(r'(\d+)\s*(?:minute|min|m)').firstMatch(lower);
    
    final hours = hourMatch != null ? int.tryParse(hourMatch.group(1) ?? '0') ?? 0 : 0;
    final minutes = minMatch != null ? int.tryParse(minMatch.group(1) ?? '0') ?? 0 : 0;
    
    final total = hours * 60 + minutes;
    return total > 0 ? total : null;
  }

  /// Combine prep and cook times into a single total time string
  String _combineTimes(String prepTime, String cookTime) {
    final prepMinutes = _parseTimeToMinutes(prepTime) ?? 0;
    final cookMinutes = _parseTimeToMinutes(cookTime) ?? 0;
    final totalMinutes = prepMinutes + cookMinutes;
    
    if (totalMinutes <= 0) return cookTime; // Fallback to cook time string
    
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes} min';
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
    
    // Extract ingredients with section support (including Tasty.co ingredient_sections)
    final rawIngs = _extractRawIngredients(
      data['recipeIngredient'] ?? data['ingredients'] ?? data['ingredient_sections']
    );
    
    // Extract directions
    final rawDirs = _extractDirections(data['recipeInstructions'] ?? data['instructions'] ?? data['directions'] ?? data['steps']);
    
    if (rawIngs.isEmpty && rawDirs.isEmpty) return null;
    
    // Parse ingredients
    final ingredients = _ingParser.parseList(rawIngs);
    
    // Extract other fields
    final serves = _parseString(data['recipeYield'] ?? data['yield'] ?? data['serves'] ?? data['yieldTextOverride']);
    final time = _parseTime(data);
    final imageUrl = _parseImage(data['image']);
    // Strip HTML from description (some sites like Saveur have HTML in description)
    final rawDescription = _parseString(data['description']);
    final description = rawDescription != null ? _stripHtml(rawDescription) : null;
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
      String? lastGroupName;  // Track GBC-style section names
      
      for (final item in data) {
        if (item is String) {
          results.add(item);
        } else if (item is Map) {
          // Great British Chefs format: each ingredient has groupName for section
          // Format: {groupName: "Section", unstructuredTextMetric: "1.5kg lamb shoulder"}
          // Check this FIRST because GBC items may have an 'ingredient' key too (nested object)
          if (item.containsKey('unstructuredTextMetric') || item.containsKey('linkTextMetric')) {
            final groupName = item['groupName']?.toString();
            final ingredientText = item['unstructuredTextMetric']?.toString() ?? 
                                   item['linkTextMetric']?.toString() ?? '';
            
            // Add section header if this is a new group
            if (groupName != null && groupName.isNotEmpty && groupName != lastGroupName) {
              results.add('[${_cleanSectionHeader(groupName)}]');
              lastGroupName = groupName;
            }
            
            if (ingredientText.isNotEmpty) {
              results.add(ingredientText.trim());
            }
            continue;
          }
          
          // Handle sectioned ingredients (WordPress ACF, Tasty.co, etc.)
          // Tasty.co format: {name: "Birria", ingredients: [{name: "salt", primary_unit: {quantity: "1/4", display: "cup"}, ...}, ...]}
          // Other formats: {groupName: "Sauce", items: [...]} or {section: "Sauce", ingredients: [...]}
          final sectionName = item['groupName'] ?? item['section'] ?? item['title'] ?? 
                             (item.containsKey('ingredients') && item.containsKey('name') ? item['name'] : null);
          final sectionItems = item['items'] ?? item['ingredients'];
          
          if (sectionName != null && sectionItems != null && sectionItems is List) {
            // This is a section with grouped ingredients
            results.add('[${_cleanSectionHeader(sectionName.toString())}]');
            for (final si in sectionItems) {
              final ingText = _formatIngredientItem(si);
              if (ingText != null && ingText.isNotEmpty) results.add(ingText);
            }
          } else {
            // Regular ingredient object (not a section)
            final ingText = _formatIngredientItem(item);
            if (ingText != null && ingText.isNotEmpty) results.add(ingText);
          }
        }
      }
      return results;
    }
    return [];
  }
  
  /// Format a single ingredient item from various object formats
  String? _formatIngredientItem(dynamic item) {
    if (item is String) return item;
    if (item is! Map) return item?.toString();
    
    // Tasty.co format: {name: "salt", primary_unit: {quantity: "1/4", display: "cup"}, metric_unit: {...}, extra_comment: "plus 1 tbsp"}
    if (item.containsKey('primary_unit') || item.containsKey('metric_unit')) {
      final buffer = StringBuffer();
      
      // Get quantity and unit from primary_unit
      final primaryUnit = item['primary_unit'];
      if (primaryUnit is Map) {
        final qty = primaryUnit['quantity'];
        final unit = primaryUnit['display'];
        if (qty != null) buffer.write(qty);
        if (unit != null) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(unit);
        }
      }
      
      // Add ingredient name
      final name = item['name'];
      if (name != null) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(name);
      }
      
      // Add extra comment (e.g., "plus 1 tablespoon")
      final extra = item['extra_comment'];
      if (extra != null && extra.toString().isNotEmpty) {
        buffer.write(', ');
        buffer.write(extra);
      }
      
      return buffer.toString();
    }
    
    // Saveur/WordPress ACF format: {ingredient: "name", quantity: "2", measurement: "cups"}
    // Note: 'ingredient' must be a String, not an object
    if (item.containsKey('ingredient') && item['ingredient'] is String) {
      final quantity = item['quantity']?.toString() ?? '';
      final measurement = item['measurement']?.toString() ?? '';
      final ingredientName = item['ingredient']?.toString() ?? '';
      if (ingredientName.isNotEmpty) {
        final parts = <String>[];
        if (quantity.isNotEmpty) parts.add(quantity);
        if (measurement.isNotEmpty) parts.add(measurement);
        parts.add(ingredientName);
        return parts.join(' ').trim();
      }
    }
    
    // Standard formats: {text: "..."} or {name: "..."}
    final text = item['text'] ?? item['name'] ?? item['unstructuredTextMetric'];
    return text?.toString();
  }

  /// Extract directions, handling HowToStep, HowToSection, etc.
  List<String> _extractDirections(dynamic data) {
    if (data == null) return [];
    if (data is String) return data.split(RegExp(r'\n+'));
    
    // Handle single object (some sites have a single HowToStep instead of array)
    if (data is Map) {
      final results = <String>[];
      final text = data['text'] ?? data['display_text'] ?? data['name'];
      if (text != null) results.add(_cleanDirectionStep(text.toString()));
      return results;
    }
    
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
          // HowToStep (standard) or Tasty.co format (display_text)
          else {
            final text = item['text'] ?? item['display_text'] ?? item['name'];
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
    // Check for various ingredient formats (standard, Tasty.co sections, etc.)
    final hasIngredients = data.containsKey('recipeIngredient') || 
                           data.containsKey('ingredients') ||
                           data.containsKey('ingredient_sections');
    final hasInstructions = data.containsKey('recipeInstructions') || 
                            data.containsKey('instructions') || 
                            data.containsKey('directions');
    return hasIngredients || hasInstructions;
  }

  // ========== Microdata Parsing ==========
  
  RecipeImportResult? _parseMicrodata(Document document, String url) {
    // Try multiple selectors to find recipe element (some sites use different formats)
    var recipeElement = document.querySelector('[itemtype*="schema.org/Recipe"]');
    recipeElement ??= document.querySelector('[itemtype*="Recipe"]');
    if (recipeElement == null) return null;
    
    final name = recipeElement.querySelector('[itemprop="name"]')?.text.trim();
    if (name == null || name.isEmpty) return null;
    
    // Ingredients - also check content attribute (common for meta tags)
    final ingElements = recipeElement.querySelectorAll('[itemprop="recipeIngredient"], [itemprop="ingredients"]');
    final rawIngs = <String>[];
    for (final e in ingElements) {
      // Check for content attribute first (common for meta tags)
      final contentAttr = e.attributes['content'];
      if (contentAttr != null && contentAttr.isNotEmpty) {
        // Content might be comma-separated list of ingredients
        if (contentAttr.contains(',') && !contentAttr.contains('(')) {
          for (final part in contentAttr.split(',')) {
            final cleaned = _ingParser.decodeHtml(part.trim());
            if (cleaned.isNotEmpty) rawIngs.add(cleaned);
          }
        } else {
          rawIngs.add(_ingParser.decodeHtml(contentAttr));
        }
      } else {
        final text = e.text.trim();
        if (text.isNotEmpty) rawIngs.add(text);
      }
    }
    
    // Directions - handle nested steps and itemListElement
    final dirElements = recipeElement.querySelectorAll('[itemprop="recipeInstructions"]');
    List<String> directions = [];
    for (final el in dirElements) {
      // Check for nested steps (itemListElement, step, li, p)
      final nestedSteps = el.querySelectorAll('[itemprop="itemListElement"], [itemprop="step"], li, p');
      if (nestedSteps.isNotEmpty) {
        for (final step in nestedSteps) {
          final text = _cleanDirectionStep(step.text.trim());
          if (text.isNotEmpty && text.length > 10) directions.add(text);
        }
      } else {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          // Split by newlines or periods followed by capital letters
          final steps = text.split(RegExp(r'\n+|\. (?=[A-Z])'));
          for (final step in steps) {
            if (step.trim().isNotEmpty && step.trim().length > 10) {
              directions.add(_cleanDirectionStep(step.trim()));
            }
          }
        }
      }
    }
    
    if (rawIngs.isEmpty && directions.isEmpty) return null;
    
    // Quality check: If ingredients are just single words or short names without quantities
    // (from meta content), try to find better detailed ingredients from HTML structure.
    // Pattern: digits/fractions followed by a measurement unit
    final quantityPattern = RegExp(
      r'[\d½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:cup|cups|tbsp|tablespoons?|tsp|teaspoons?|oz|ounces?|ml|g|grams?|kg|lb|lbs?|pounds?|liters?|litres?|quarts?|pints?|gallons?|fl\.?\s*oz|dash(?:es)?|splash(?:es)?|pinch(?:es)?|drops?|parts?|cl|dl)',
      caseSensitive: false
    );
    final hasQuantities = rawIngs.any((item) => quantityPattern.hasMatch(item));
    
    if (!hasQuantities && rawIngs.isNotEmpty) {
      // Try to find detailed ingredients from HTML structure
      final htmlIngredients = _parseHtmlIngredientsFallback(document);
      final htmlHasQuantities = htmlIngredients.any((item) => quantityPattern.hasMatch(item));
      
      if (htmlHasQuantities && htmlIngredients.length >= rawIngs.length) {
        // Use detailed HTML ingredients instead of poor microdata
        rawIngs.clear();
        rawIngs.addAll(htmlIngredients);
        
        // If microdata had no directions, the HTML fallback can do a better job
        // since it also extracts directions. Return null to use full HTML parsing.
        if (directions.isEmpty) {
          return null;
        }
      } else if (!hasQuantities && directions.isEmpty) {
        // No quantities in either source, no directions - fall through to HTML fallback
        return null;
      }
    }
    
    // Also return null if we have ingredients but no directions
    // This lets HTML fallback extract both properly
    if (directions.isEmpty && rawIngs.isNotEmpty) {
      // For known sites with complex HTML structures, skip microdata entirely
      // so the dedicated HTML parsers can handle them
      if (url.contains('modernistpantry.com')) {
        return null; // Use dedicated Modernist Pantry parser in HTML fallback
      }
      
      // Check if this site might have directions in HTML that we're missing
      final hasHtmlDirections = _parseDirectionsBySections(document).isNotEmpty;
      if (hasHtmlDirections) {
        return null; // Let HTML fallback handle this
      }
    }
    
    // Time - check datetime and content attributes
    String? time;
    final totalTimeEl = recipeElement.querySelector('[itemprop="totalTime"]');
    final prepTimeEl = recipeElement.querySelector('[itemprop="prepTime"]');
    final cookTimeEl = recipeElement.querySelector('[itemprop="cookTime"]');
    
    if (totalTimeEl != null) {
      final timeContent = totalTimeEl.attributes['content'] ?? 
                          totalTimeEl.attributes['datetime'] ?? 
                          totalTimeEl.text;
      if (timeContent != null) time = _parseIso8601Duration(timeContent);
    } else {
      int totalMins = 0;
      if (prepTimeEl != null) {
        final timeContent = prepTimeEl.attributes['content'] ?? 
                            prepTimeEl.attributes['datetime'] ?? 
                            prepTimeEl.text;
        if (timeContent != null) totalMins += _parseIso8601DurationMinutes(timeContent);
      }
      if (cookTimeEl != null) {
        final timeContent = cookTimeEl.attributes['content'] ?? 
                            cookTimeEl.attributes['datetime'] ?? 
                            cookTimeEl.text;
        if (timeContent != null) totalMins += _parseIso8601DurationMinutes(timeContent);
      }
      if (totalMins > 0) time = _formatMinutes(totalMins);
    }
    
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
      time: time,
      imageUrl: imageUrl,
      nameConfidence: 0.9,
      ingredientsConfidence: rawIngs.isNotEmpty ? 0.85 : 0.0,
      directionsConfidence: directions.isNotEmpty ? 0.85 : 0.0,
    );
  }
  
  /// Parse ISO 8601 duration (PT30M, PT1H30M, etc.) to human-readable string
  String? _parseIso8601Duration(String duration) {
    final mins = _parseIso8601DurationMinutes(duration);
    if (mins <= 0) return null;
    return _formatMinutes(mins);
  }
  
  /// Parse ISO 8601 duration to minutes
  int _parseIso8601DurationMinutes(String duration) {
    // Handle ISO 8601 format: PT1H30M, PT30M, P0DT1H30M, etc.
    final hourMatch = RegExp(r'(\d+)H', caseSensitive: false).firstMatch(duration);
    final minMatch = RegExp(r'(\d+)M(?!O)', caseSensitive: false).firstMatch(duration); // Exclude MONTH
    
    int hours = hourMatch != null ? (int.tryParse(hourMatch.group(1) ?? '0') ?? 0) : 0;
    int mins = minMatch != null ? (int.tryParse(minMatch.group(1) ?? '0') ?? 0) : 0;
    
    return hours * 60 + mins;
  }
  
  /// Format minutes to human-readable string
  String _formatMinutes(int totalMins) {
    if (totalMins >= 60) {
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      if (mins > 0) return '${hours}h ${mins}m';
      return '${hours}h';
    }
    return '$totalMins min';
  }

  // ========== HTML Parsing with Site Configs ==========
  
  /// Lightweight HTML ingredient extraction for enhancing poor microdata.
  /// This is a simpler version of _parseHtmlFallback that only gets ingredients.
  List<String> _parseHtmlIngredientsFallback(Document document) {
    final results = <String>[];
    
    // Try common ingredient selectors
    // Note: .ingredients-list is used by Punch Drink (visible li elements without style attr)
    final selectors = [
      '.ingredients-list li',  // Punch Drink - filter hidden elements below
      '.ingredient-list li',
      '.ingredients li',
      '.recipe-ingredients li',
      'ul.ingredients li',
      '.wprm-recipe-ingredient',
      '.tasty-recipes-ingredients li',
    ];
    
    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final e in elements) {
          // Skip hidden elements (e.g., Punch Drink has hidden microdata duplicates)
          final styleAttr = e.attributes['style'] ?? '';
          if (styleAttr.contains('display:none') || styleAttr.contains('display: none')) {
            continue;
          }
          final text = _ingParser.decodeHtml(e.text.trim());
          if (text.isNotEmpty) results.add(text);
        }
        if (results.isNotEmpty) return results;
      }
    }
    
    // Try section-based parsing (H2/H3 "Ingredients" followed by list)
    for (final heading in document.querySelectorAll('h2, h3')) {
      final headingText = heading.text.trim().toLowerCase();
      // Also check ID attribute for sites like Modernist Pantry that use id="ingredients"
      final headingId = heading.attributes['id']?.toLowerCase() ?? '';
      if (headingText.contains('ingredient') || headingId.contains('ingredient')) {
        var sibling = heading.nextElementSibling;
        while (sibling != null && sibling.localName != 'h2' && sibling.localName != 'h3') {
          if (sibling.localName == 'ul' || sibling.localName == 'ol') {
            for (final li in sibling.querySelectorAll('li')) {
              // Extract text from span if present (Modernist Pantry uses <li><span>...</span></li>)
              final spanText = li.querySelector('span')?.text.trim();
              final text = _ingParser.decodeHtml(spanText ?? li.text.trim());
              // Skip section headers (bold text like "Ingredients Black Garlic Honey:")
              if (text.isNotEmpty && !text.endsWith(':')) results.add(text);
            }
          }
          sibling = sibling.nextElementSibling;
        }
        if (results.isNotEmpty) return results;
      }
    }
    
    return results;
  }
  
  RecipeImportResult? _parseHtmlFallback(Document document, String url, String? rawBody) {
    var rawIngredientStrings = <String>[];
    var rawDirections = <String>[];
    String? glass;
    List<String> garnish = [];
    String? title = document.querySelector('h1')?.text.trim();
    title ??= document.querySelector('meta[property="og:title"]')?.attributes['content'];

    // 0. Try Shopify/Lyres embedded HTML parsing (unicode-escaped HTML in JSON)
    // These sites embed recipe content in JSON strings with \u003c for <, etc.
    if (rawBody != null && (url.contains('lyres.com') || url.contains('seedlip'))) {
      final shopifyResult = _parseShopifyEmbeddedHtml(rawBody, url);
      if (shopifyResult != null) {
        rawIngredientStrings = shopifyResult['ingredients'] ?? [];
        rawDirections = shopifyResult['directions'] ?? [];
        glass = shopifyResult['glass'];
        garnish = shopifyResult['garnish'] ?? [];
      }
    }

    // 0b. Modernist Pantry specific parsing
    // Their structure: <h2 id="ingredients">Ingredients</h2> followed by <ul> with li items
    // Section headers like "Ingredients Black Garlic Honey:" in bold <b> within <li>
    if (rawIngredientStrings.isEmpty && url.contains('modernistpantry.com')) {
      rawIngredientStrings = _extractModernistPantryIngredients(document);
      if (rawDirections.isEmpty) {
        rawDirections = _extractModernistPantryDirections(document);
      }
    }

    // 1. Try Site Configs (targeted plugin patterns)
    if (rawIngredientStrings.isEmpty) {
      final configResult = _tryAllSiteConfigs(document);
      if (configResult != null && configResult.isNotEmpty) {
        rawIngredientStrings = configResult;
      }
    }

    // 2. Try Diffords-style table for ingredients (legacy-ingredients-table)
    if (rawIngredientStrings.isEmpty) {
      final ingredientTable = document.querySelector('.legacy-ingredients-table, table.ingredients');
      if (ingredientTable != null) {
        final rows = ingredientTable.querySelectorAll('tr');
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 2) {
            final amount = _ingParser.decodeHtml(cells[0].text.trim());
            final name = _ingParser.decodeHtml(cells[1].text.trim());
            if (name.isNotEmpty) {
              rawIngredientStrings.add(amount.isNotEmpty ? '$amount $name' : name);
            }
          }
        }
      }
    }

    // 3. Try specific plugin selectors
    if (rawIngredientStrings.isEmpty) {
      // Cooked plugin (WordPress recipe plugin)
      // Uses .cooked-single-ingredient.cooked-ingredient for ingredients (not .cooked-heading which are section headers)
      // Structure: .cooked-ing-amount (quantity) + .cooked-ing-measurement (unit) + .cooked-ing-name (ingredient)
      final cookedItems = document.querySelectorAll('.cooked-single-ingredient');
      if (cookedItems.isNotEmpty) {
        for (final item in cookedItems) {
          final classes = item.classes;
          if (classes.contains('cooked-heading')) {
            // This is a section header
            final headerText = item.text.trim();
            if (headerText.isNotEmpty) {
              rawIngredientStrings.add('[$headerText]');
            }
          } else if (classes.contains('cooked-ingredient')) {
            // This is an actual ingredient
            final amount = item.querySelector('.cooked-ing-amount')?.text.trim() ?? '';
            final measurement = item.querySelector('.cooked-ing-measurement')?.text.trim() ?? '';
            final name = item.querySelector('.cooked-ing-name')?.text.trim() ?? '';
            final ingredientStr = '$amount $measurement $name'.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (ingredientStr.isNotEmpty) {
              rawIngredientStrings.add(_ingParser.decodeHtml(ingredientStr));
            }
          }
        }
      }
      
      // Tasty Recipes
      if (rawIngredientStrings.isEmpty) {
        final tasty = document.querySelectorAll('.tasty-recipes-ingredients li, .tasty-recipes-ingredient');
        if (tasty.isNotEmpty) rawIngredientStrings = tasty.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toList();
      }
      
      // Generic selectors - including .ingredients-list for Punch Drink, etc.
      // Filter out hidden elements (display:none) in code since :not() may not work reliably
      if (rawIngredientStrings.isEmpty) {
        final generic = document.querySelectorAll('.recipe-ingredients li, .recipe-ingred_txt, .ingredient-item, .ingredients-list li, [itemprop="recipeIngredient"]');
        for (final e in generic) {
          final styleAttr = e.attributes['style'] ?? '';
          if (styleAttr.contains('display:none') || styleAttr.contains('display: none')) {
            continue;
          }
          final text = e.text.trim();
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
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
    
    // First try Cooked plugin (detailed structure with .cooked-dir-content)
    if (rawDirections.isEmpty) {
      final cookedDirections = document.querySelectorAll('.cooked-single-direction.cooked-direction, .cooked-single-direction');
      for (final elem in cookedDirections) {
        // Get the content div which contains paragraphs
        final contentDiv = elem.querySelector('.cooked-dir-content');
        if (contentDiv != null) {
          // Get all paragraphs
          final paragraphs = contentDiv.querySelectorAll('p');
          for (final p in paragraphs) {
            final text = _cleanDirectionStep(p.text.trim());
            if (text.isNotEmpty) rawDirections.add(text);
          }
          // If no paragraphs, try the content directly
          if (paragraphs.isEmpty) {
            final text = _cleanDirectionStep(contentDiv.text.trim());
            if (text.isNotEmpty) rawDirections.add(text);
          }
        }
      }
    }
    
    // Try standard direction selectors
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
    
    // Fallback for Modernist Pantry style (h3 with "Create/Make/Prepare" followed by paragraphs)
    if (rawDirections.isEmpty && rawBody != null) {
      rawDirections = _extractModernistPantryDirections(document);
    }

    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) return null;

    // Determine course for cocktail sites
    String? course;
    if (_isCocktailSite(url) || glass != null || garnish.isNotEmpty) {
      course = 'Drinks';
    }

    return RecipeImportResult(
      name: _ingParser.decodeHtml(title ?? 'Untitled Recipe'),
      source: RecipeSource.url,
      sourceUrl: url,
      ingredients: _ingParser.parseList(rawIngredientStrings),
      directions: rawDirections,
      imageUrl: _extractImageFromHtml(document),
      course: course,
      glass: glass,
      garnish: garnish,
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
            // Clean section header (remove trailing colons)
            if (header != null && header.isNotEmpty) {
              ingredients.add('[${_cleanSectionHeader(header)}]');
            }
            
            final items = section.querySelectorAll(config.ingredientSelector);
            ingredients.addAll(items.map((e) => e.text.trim()).where((s) => s.isNotEmpty));
          }
        }
      } else if (config.mode == ExtractionMode.siblingHeaderList && config.headerSelector != null) {
        final headers = container.querySelectorAll(config.headerSelector!);
        for (final header in headers) {
          final headerText = header.text.trim();
          // Clean section header (remove trailing colons)
          if (headerText.isNotEmpty) ingredients.add('[${_cleanSectionHeader(headerText)}]');
          
          var sibling = header.nextElementSibling;
          while (sibling != null && (sibling.localName == 'ul' || sibling.localName == 'ol')) {
            ingredients.addAll(sibling.querySelectorAll('li').map((e) => e.text.trim()).where((s) => s.isNotEmpty));
            sibling = sibling.nextElementSibling;
          }
        }
      } else {
        final items = container.querySelectorAll(config.ingredientSelector);
        for (final e in items) {
          // Skip hidden elements (e.g., Punch Drink has hidden microdata duplicates)
          final styleAttr = e.attributes['style'] ?? '';
          if (styleAttr.contains('display:none') || styleAttr.contains('display: none')) {
            continue;
          }
          final text = e.text.trim();
          if (text.isNotEmpty) ingredients.add(text);
        }
      }

      if (ingredients.isNotEmpty) return ingredients;
    }
    return null;
  }

  List<String> _parseIngredientsBySections(Document document) {
    final ingredients = <String>[];
    // Include h5 for sites like Punch Drink
    final headings = document.querySelectorAll('h2, h3, h4, h5');
    
    for (final heading in headings) {
      final text = heading.text.toLowerCase();
      if (text.contains('ingredient')) {
        var sibling = heading.nextElementSibling;
        int attempts = 0;
        while (sibling != null && attempts < 10) {
          // Stop at next major heading (ingredients section ended)
          if (sibling.localName == 'h1' || sibling.localName == 'h2' || 
              sibling.localName == 'h3' || sibling.localName == 'h4' || sibling.localName == 'h5') {
            final siblingHeading = sibling.text.toLowerCase();
            if (siblingHeading.contains('direction') || siblingHeading.contains('method') || 
                siblingHeading.contains('instruction') || siblingHeading.contains('step') ||
                siblingHeading.contains('note') || siblingHeading.contains('garnish')) {
              break; // Stop - we've hit the next section
            }
          }
          
          if (sibling.localName == 'ul' || sibling.localName == 'ol') {
            ingredients.addAll(sibling.querySelectorAll('li').map((e) => e.text.trim()).where((s) => s.isNotEmpty));
            break;
          }
          
          // Check for bullet-point text (e.g., "• 200g Sugar • 100g Flour")
          final siblingText = sibling.text.trim();
          if (siblingText.contains('•')) {
            final parts = siblingText.split('•');
            for (var part in parts) {
              part = _ingParser.decodeHtml(part.trim());
              if (part.isNotEmpty && part.length >= 5 && part.length <= 150 && _couldBeIngredientLine(part)) {
                ingredients.add(part);
              }
            }
            if (ingredients.isNotEmpty) break;
          }
          
          // Check if this sibling element itself is an ingredient line (cocktail sites like Punch Drink)
          // Punch Drink uses individual <p> or <div> elements for each ingredient line
          if ((sibling.localName == 'p' || sibling.localName == 'div') && 
              siblingText.isNotEmpty && siblingText.length <= 150) {
            // Split by newlines in case multiple ingredients are in one element
            final lines = siblingText.split(RegExp(r'\n+'));
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && (_couldBeIngredientLine(trimmed) || _looksLikeCocktailIngredient(trimmed))) {
                ingredients.add(_ingParser.decodeHtml(trimmed));
              } else if (trimmed.toLowerCase().startsWith('garnish:')) {
                // Garnish line - also add it
                ingredients.add(_ingParser.decodeHtml(trimmed));
              }
            }
          }
          
          // Check if the sibling is a container with p/div/span children
          final divIngredients = sibling.querySelectorAll('p, div, span');
          if (divIngredients.isNotEmpty) {
            for (final el in divIngredients) {
              final elText = el.text.trim();
              // Check for bullet text inside child elements
              if (elText.contains('•')) {
                final parts = elText.split('•');
                for (var part in parts) {
                  part = _ingParser.decodeHtml(part.trim());
                  if (part.isNotEmpty && part.length >= 5 && part.length <= 150 && _couldBeIngredientLine(part)) {
                    ingredients.add(part);
                  }
                }
              } else if (_couldBeIngredientLine(elText) || _looksLikeCocktailIngredient(elText)) {
                ingredients.add(elText);
              }
            }
          }
          sibling = sibling.nextElementSibling;
          attempts++;
        }
        // If we found ingredients under this heading, stop looking at other headings
        if (ingredients.isNotEmpty) break;
      }
    }
    return ingredients;
  }
  
  /// Check if text looks like a cocktail ingredient (e.g., "1 ounce gin")
  bool _looksLikeCocktailIngredient(String text) {
    if (text.isEmpty || text.length > 100) return false;
    // Match patterns like "1 ounce gin" or "1½ oz vodka" or "2 dashes bitters"
    return RegExp(r'^\d+(?:[½¼¾⅓⅔⅛]|\s*[½¼¾⅓⅔⅛])?\s*(?:ounce|oz|dash|barspoon|drop|ml|cl|part|splash)', caseSensitive: false).hasMatch(text);
  }

  List<String> _parseDirectionsBySections(Document document) {
    final directions = <String>[];
    // Include h5 for sites like Punch Drink
    final headings = document.querySelectorAll('h2, h3, h4, h5');
    
    for (final heading in headings) {
      final text = heading.text.toLowerCase();
      if (text.contains('direction') || text.contains('instruction') || text.contains('method') || text.contains('step')) {
        var sibling = heading.nextElementSibling;
        int attempts = 0;
        while (sibling != null && attempts < 10) {
          if (sibling.localName == 'ul' || sibling.localName == 'ol') {
            directions.addAll(sibling.querySelectorAll('li').map((e) => _cleanDirectionStep(e.text.trim())).where((s) => s.isNotEmpty));
            break;
          } else if (sibling.localName == 'p' || sibling.localName == 'div') {
            final elText = sibling.text.trim();
            // Check if this is a numbered step (e.g., "1Add all ingredients...")
            final numberedMatch = RegExp(r'^(\d+)([A-Z])').firstMatch(elText);
            if (numberedMatch != null) {
              // Split apart the number and text
              final stepText = elText.substring(1).trim();
              if (stepText.isNotEmpty) {
                directions.add(_cleanDirectionStep(stepText));
              }
            } else if (elText.isNotEmpty && elText.length > 10) {
              directions.add(_cleanDirectionStep(elText));
            }
          }
          sibling = sibling.nextElementSibling;
          attempts++;
        }
        if (directions.isNotEmpty) break; // Found directions, stop looking
      }
    }
    return directions;
  }

  /// Check if text could be an ingredient line (more flexible than strict measurement matching)
  bool _couldBeIngredientLine(String text) {
    if (text.isEmpty || text.length > 150) return false;
    
    // Has standard measurements (full words and abbreviations)
    if (RegExp(r'\d+\s*(?:g|grams?|kg|oz|ounce|ounces|lb|lbs|pound|pounds|cup|cups|tbsp|tablespoons?|tsp|teaspoons?|ml|l|cl|dl)', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    // Starts with a number (e.g., "4 eggs")
    if (RegExp(r'^\d+\s+').hasMatch(text)) {
      return true;
    }
    // Starts with a fraction (e.g., "½ cup")
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
      return true;
    }
    return false;
  }
  
  /// Extract ingredients from Modernist Pantry style
  /// Structure: <h2 id="ingredients">Ingredients</h2> followed by <ul> with <li> items
  /// Section headers like "Ingredients Black Garlic Honey:" are in bold <b> within <li>
  List<String> _extractModernistPantryIngredients(Document document) {
    final ingredients = <String>[];
    
    // Try direct selector first
    var ingredientHeading = document.querySelector('h2#ingredients, h2[id="ingredients"]');
    
    // Fallback: Find the h2 with text "Ingredients"
    if (ingredientHeading == null) {
      for (final h2 in document.querySelectorAll('h2')) {
        final text = h2.text.trim().toLowerCase();
        if (text == 'ingredients') {
          ingredientHeading = h2;
          break;
        }
      }
    }
    
    if (ingredientHeading == null) return ingredients;
    
    // Strategy 1: Find ul elements that are siblings (may have many p tags in between)
    var sibling = ingredientHeading.nextElementSibling;
    int attempts = 0;
    while (sibling != null && attempts < 30) { // Increased from 10 to 30
      // Stop if we hit another h2 that's a different section
      final siblingId = sibling.attributes['id'] ?? '';
      if (sibling.localName == 'h2' && siblingId != 'ingredients') {
        if (siblingId == 'equipment' || siblingId == 'timing' || siblingId == 'yield' ||
            sibling.text.toLowerCase().contains('equipment') ||
            sibling.text.toLowerCase().contains('direction') ||
            sibling.text.toLowerCase().contains('method')) {
          break;
        }
      }
      
      if (sibling.localName == 'ul' || sibling.localName == 'ol') {
        for (final li in sibling.querySelectorAll('li')) {
          // Check if this is a section header (in bold)
          final boldEl = li.querySelector('b, strong');
          if (boldEl != null && boldEl.text.toLowerCase().contains('ingredients')) {
            // This is a section header like "Ingredients Black Garlic Honey:"
            var headerText = boldEl.text.trim();
            // Extract just the section name (remove "Ingredients" prefix and trailing colon)
            headerText = headerText.replaceFirst(RegExp(r'^Ingredients?\s*', caseSensitive: false), '');
            headerText = headerText.replaceFirst(RegExp(r':\s*$'), '');
            if (headerText.isNotEmpty) {
              ingredients.add('[${headerText.trim()}]');
            }
          } else {
            // This is an actual ingredient - prefer span text if present
            final span = li.querySelector('span');
            final text = _ingParser.decodeHtml(span?.text.trim() ?? li.text.trim());
            if (text.isNotEmpty && !text.toLowerCase().startsWith('ingredients')) {
              ingredients.add(text);
            }
          }
        }
        // Continue to find more ul elements (some recipes have multiple lists)
      }
      
      sibling = sibling.nextElementSibling;
      attempts++;
    }
    
    // Strategy 2: If no ingredients found, try looking for ul inside the parent container
    if (ingredients.isEmpty) {
      final parent = ingredientHeading.parent;
      if (parent != null) {
        // Find all ul elements in the parent after the h2
        bool foundHeading = false;
        for (final child in parent.children) {
          if (child == ingredientHeading) {
            foundHeading = true;
            continue;
          }
          if (!foundHeading) continue;
          
          // Stop at another h2
          if (child.localName == 'h2') break;
          
          if (child.localName == 'ul' || child.localName == 'ol') {
            for (final li in child.querySelectorAll('li')) {
              final boldEl = li.querySelector('b, strong');
              if (boldEl != null && boldEl.text.toLowerCase().contains('ingredients')) {
                var headerText = boldEl.text.trim();
                headerText = headerText.replaceFirst(RegExp(r'^Ingredients?\s*', caseSensitive: false), '');
                headerText = headerText.replaceFirst(RegExp(r':\s*$'), '');
                if (headerText.isNotEmpty) {
                  ingredients.add('[${headerText.trim()}]');
                }
              } else {
                final span = li.querySelector('span');
                final text = _ingParser.decodeHtml(span?.text.trim() ?? li.text.trim());
                if (text.isNotEmpty && !text.toLowerCase().startsWith('ingredients')) {
                  ingredients.add(text);
                }
              }
            }
          }
        }
      }
    }
    
    // Strategy 3: If still no ingredients, find any ul containing li with bold "Ingredients ..." text
    // This handles cases where DOM parsing doesn't maintain expected sibling relationships
    if (ingredients.isEmpty) {
      for (final ul in document.querySelectorAll('ul')) {
        final firstBold = ul.querySelector('li > b, li > strong');
        if (firstBold != null && firstBold.text.toLowerCase().contains('ingredients')) {
          // This looks like a Modernist Pantry ingredient list
          for (final li in ul.querySelectorAll('li')) {
            final boldEl = li.querySelector('b, strong');
            if (boldEl != null && boldEl.text.toLowerCase().contains('ingredients')) {
              // Section header
              var headerText = boldEl.text.trim();
              headerText = headerText.replaceFirst(RegExp(r'^Ingredients?\s*', caseSensitive: false), '');
              headerText = headerText.replaceFirst(RegExp(r':\s*$'), '');
              if (headerText.isNotEmpty) {
                ingredients.add('[${headerText.trim()}]');
              }
            } else {
              // Ingredient line
              final span = li.querySelector('span');
              final text = _ingParser.decodeHtml(span?.text.trim() ?? li.text.trim());
              if (text.isNotEmpty && text.length > 3) {
                ingredients.add(text);
              }
            }
          }
          if (ingredients.isNotEmpty) break;
        }
      }
    }
    
    return ingredients;
  }
  
  /// Extract directions from Modernist Pantry style 
  /// Structure: li.one/.two/.three containing h3 headers and nested .equipment-time divs with instruction text
  List<String> _extractModernistPantryDirections(Document document) {
    final directions = <String>[];
    
    // Find li elements with step classes (one, two, three, etc.) or all li within .product-list
    var stepItems = document.querySelectorAll('.product-list li.one, .product-list li.two, .product-list li.three, .product-list li.four, .product-list li.five');
    
    // If no specific class matches, try all li in product-list that have h3
    if (stepItems.isEmpty) {
      stepItems = document.querySelectorAll('.product-list ul > li');
    }
    
    for (final li in stepItems) {
      // Find the h3 step title
      final h3 = li.querySelector('h3');
      if (h3 != null) {
        final stepTitle = h3.text.trim();
        if (stepTitle.isNotEmpty && 
            RegExp(r'(?:Create|Make|Prepare|Churn|Step|Enjoy)', caseSensitive: false).hasMatch(stepTitle)) {
          directions.add('**$stepTitle**');
          
          // Find all spans with instruction text within this li's nested divs
          final spans = li.querySelectorAll('.equipment-time span, .product-list span');
          for (final span in spans) {
            final text = span.text.trim();
            if (text.length > 15) {
              directions.add(_cleanDirectionStep(text));
            }
          }
          
          // Also get text from divs that don't have spans (direct text content)
          final innerDivs = li.querySelectorAll('.equipment-time > div, .product-list > div');
          for (final div in innerDivs) {
            // Skip if this div contains a span (already processed)
            if (div.querySelector('span') != null) continue;
            final text = div.text.trim();
            if (text.length > 15 && text != ' ') {
              directions.add(_cleanDirectionStep(text));
            }
          }
        }
      }
    }
    
    if (directions.isNotEmpty) return directions;
    
    // Fallback: Find all h3 with action words and gather nearby text
    final actionHeadings = document.querySelectorAll('h3');
    for (final heading in actionHeadings) {
      final headingText = heading.text.trim();
      if (RegExp(r'^(?:Create|Make|Prepare|Churn|Step\s*\d+|Enjoy)', caseSensitive: false).hasMatch(headingText)) {
        directions.add('**$headingText**');
        
        // Strategy A: Look in the parent li for instruction text
        final parentLi = heading.parent;
        if (parentLi != null && parentLi.localName == 'li') {
          // Get all span text after the h3
          bool afterH3 = false;
          for (final child in parentLi.children) {
            if (child == heading) {
              afterH3 = true;
              continue;
            }
            if (!afterH3) continue;
            
            final spans = child.querySelectorAll('span');
            for (final span in spans) {
              final text = span.text.trim();
              if (text.length > 15) {
                directions.add(_cleanDirectionStep(text));
              }
            }
            
            // Also try direct div text
            if (child.localName == 'div') {
              final divText = child.text.trim();
              if (divText.length > 15 && !divText.startsWith('**')) {
                // Avoid adding the heading again
                final cleanText = _cleanDirectionStep(divText);
                if (!directions.contains(cleanText)) {
                  directions.add(cleanText);
                }
              }
            }
          }
        }
        
        // Strategy B: Look at next siblings if parent wasn't an li
        if (parentLi == null || parentLi.localName != 'li') {
          var sibling = heading.nextElementSibling;
          int attempts = 0;
          while (sibling != null && attempts < 10) {
            // Stop at another h3 with action words
            if (sibling.localName == 'h3') {
              final siblingText = sibling.text.trim();
              if (RegExp(r'^(?:Create|Make|Prepare|Churn|Step|Enjoy)', caseSensitive: false).hasMatch(siblingText)) {
                break;
              }
            }
            
            final spans = sibling.querySelectorAll('span');
            for (final span in spans) {
              final text = span.text.trim();
              if (text.length > 15) {
                directions.add(_cleanDirectionStep(text));
              }
            }
            
            sibling = sibling.nextElementSibling;
            attempts++;
          }
        }
      }
    }
    
    return directions;
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
      
      // Check if this is a section header (starts with "Ingredients" and ends with :)
      // e.g., "Ingredients Black Garlic Honey:" -> [Black Garlic Honey]
      final sectionMatch = RegExp(r'^Ingredients\s+(.+?):\s*$', caseSensitive: false).firstMatch(part);
      if (sectionMatch != null) {
        final sectionName = sectionMatch.group(1)?.trim() ?? '';
        if (sectionName.isNotEmpty) {
          ingredients.add('[${_cleanSectionHeader(sectionName)}]');
        }
        continue;
      }
      
      // Check if this looks like an ingredient (has measurement)
      if (_couldBeIngredientLine(part)) {
        ingredients.add(_ingParser.decodeHtml(part));
      }
    }
    
    return ingredients.length >= 2 ? ingredients : [];
  }
  
  /// Parse Shopify/Lyres-style embedded HTML in JSON
  /// These sites embed HTML inside JSON strings with unicode escapes (\u003c for <, etc.)
  /// Structure: <div class="recipe-info"><h4 class="title">Glass</h4><p>Old Fashioned</p></div>
  Map<String, dynamic>? _parseShopifyEmbeddedHtml(String rawBody, String url) {
    // Decode common unicode escapes that Shopify/Lyres uses
    var bodyHtml = rawBody
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
    
    // For Next.js sites (like Seedlip), extract HTML from dangerouslySetInnerHTML payloads
    // Pattern: "dangerouslySetInnerHTML":{"__html":"<h2>Ingredients</h2>..."}
    final dangerouslyMatches = RegExp(
      r'"dangerouslySetInnerHTML":\s*\{\s*"__html"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).allMatches(bodyHtml);
    
    // Collect all the __html payloads and decode them
    final extractedHtmlParts = <String>[];
    for (final match in dangerouslyMatches) {
      var htmlContent = match.group(1) ?? '';
      // Decode unicode escapes within the __html content
      htmlContent = htmlContent
          .replaceAll(r'\u003c', '<')
          .replaceAll(r'\u003e', '>')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\/', '/')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\\n', ' ')
          .replaceAll(r'\"', '"');
      extractedHtmlParts.add(htmlContent);
    }
    
    // Combine extracted HTML with the body for further parsing
    final combinedHtml = extractedHtmlParts.isNotEmpty 
        ? '${extractedHtmlParts.join('\n')}\n$bodyHtml' 
        : bodyHtml;
    
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'directions': <String>[],
      'glass': null,
      'garnish': <String>[],
    };
    
    // Find all recipe-info div sections
    final recipeInfoDivs = RegExp(
      r'<div[^>]*class="[^"]*recipe-info[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(combinedHtml);
    
    for (final divMatch in recipeInfoDivs) {
      final divContent = divMatch.group(1) ?? '';
      
      // Extract h4 title from this div
      final h4Match = RegExp(
        r'<h4[^>]*>(.*?)</h4>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(divContent);
      
      if (h4Match == null) continue;
      
      // Strip any HTML tags from the h4 content to get plain text
      final h4RawContent = h4Match.group(1) ?? '';
      final h4Title = h4RawContent.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
      
      // Extract content after h4
      final afterH4 = divContent.substring(h4Match.end);
      
      if (h4Title == 'glass') {
        // Extract glass from <p> tag
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null) {
          final glassText = pMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          if (glassText != null && glassText.isNotEmpty) {
            result['glass'] = _ingParser.decodeHtml(glassText);
          }
        }
      } else if (h4Title == 'garnish') {
        // Extract garnish from <p> tag
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null) {
          final garnishText = pMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          if (garnishText != null && garnishText.isNotEmpty) {
            result['garnish'] = _splitGarnishText(_ingParser.decodeHtml(garnishText));
          }
        }
      } else if (h4Title == 'ingredients') {
        // Extract ingredients from <ul><li> or <p> tags
        final ulMatch = RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (ulMatch != null) {
          final ulContent = ulMatch.group(1) ?? '';
          final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(ulContent);
          for (final liMatch in liMatches) {
            final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
            if (text.isNotEmpty) {
              (result['ingredients'] as List<String>).add(text);
            }
          }
        } else {
          // Try <p> tags
          final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
          for (final pMatch in pMatches) {
            final text = _ingParser.decodeHtml(pMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
            if (text.isNotEmpty && _couldBeIngredientLine(text)) {
              (result['ingredients'] as List<String>).add(text);
            }
          }
        }
      } else if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
        // Extract directions from <p> tags
        final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final pMatch in pMatches) {
          final text = _ingParser.decodeHtml(pMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
          if (text.isNotEmpty && text.length > 5) {
            // Split by periods for multiple sentences
            if (text.contains('. ')) {
              (result['directions'] as List<String>).addAll(
                text.split(RegExp(r'\.\s+'))
                    .where((s) => s.trim().isNotEmpty)
                    .map((s) {
                      final trimmed = s.trim();
                      return trimmed.endsWith('.') ? trimmed : '$trimmed.';
                    })
              );
            } else {
              (result['directions'] as List<String>).add(text);
            }
          }
        }
      }
    }
    
    // Try Seedlip-style .recipe-prose divs with h2 headings
    if ((result['ingredients'] as List).isEmpty) {
      final recipeProseDivs = RegExp(
        r'<div[^>]*class="[^"]*recipe-prose[^"]*"[^>]*>(.*?)</div>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(combinedHtml);
      
      for (final divMatch in recipeProseDivs) {
        final divContent = divMatch.group(1) ?? '';
        
        // Extract h2 title
        final h2Match = RegExp(
          r'<h2[^>]*>(.*?)</h2>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(divContent);
        
        if (h2Match == null) continue;
        
        final h2Title = h2Match.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase() ?? '';
        final afterH2 = divContent.substring(h2Match.end);
        
        if (h2Title == 'ingredients' || h2Title.contains('ingredient')) {
          // Extract ingredients from <ul><li><p> pattern
          final ulMatch = RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (ulMatch != null) {
            final ulContent = ulMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(ulContent);
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty) {
                (result['ingredients'] as List<String>).add(text);
              }
            }
          }
        } else if (h2Title.contains('glass') && h2Title.contains('garnish')) {
          // "Glass and Garnish" pattern
          final ulMatch = RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (ulMatch != null) {
            final ulContent = ulMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(ulContent);
            final items = <String>[];
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty) items.add(text);
            }
            if (items.isNotEmpty) {
              result['glass'] = items.first;
              if (items.length > 1) {
                result['garnish'] = items.sublist(1);
              }
            }
          }
        } else if (h2Title == 'method' || h2Title.contains('direction') || h2Title.contains('instruction')) {
          // Directions from <ol> or <ul>
          final listMatch = RegExp(r'<(?:ol|ul)[^>]*>(.*?)</(?:ol|ul)>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (listMatch != null) {
            final listContent = listMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(listContent);
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty && text.length > 5) {
                (result['directions'] as List<String>).add(text);
              }
            }
          }
        }
      }
    }
    
    // Try direct h2-section parsing from extracted HTML (Next.js sites like Seedlip)
    // The extracted HTML from dangerouslySetInnerHTML doesn't have wrapper divs
    // Always process extracted HTML parts regardless of what was found above
    if (extractedHtmlParts.isNotEmpty) {
      for (final htmlPart in extractedHtmlParts) {
        // Check for h2 heading
        final h2Match = RegExp(
          r'<h2[^>]*>(.*?)</h2>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(htmlPart);
        
        if (h2Match == null) continue;
        
        final h2Title = h2Match.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase() ?? '';
        final afterH2 = htmlPart.substring(h2Match.end);
        
        if (h2Title == 'ingredients' || h2Title.contains('ingredient')) {
          // Extract ingredients from <ul><li><p> pattern
          final ulMatch = RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (ulMatch != null) {
            final ulContent = ulMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(ulContent);
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty) {
                (result['ingredients'] as List<String>).add(text);
              }
            }
          }
        } else if (h2Title.contains('glass') && h2Title.contains('garnish')) {
          // "Glass and Garnish" pattern
          final ulMatch = RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (ulMatch != null) {
            final ulContent = ulMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(ulContent);
            final items = <String>[];
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty) items.add(text);
            }
            if (items.isNotEmpty) {
              result['glass'] = items.first;
              if (items.length > 1) {
                result['garnish'] = items.sublist(1);
              }
            }
          }
        } else if (h2Title == 'method' || h2Title.contains('direction') || h2Title.contains('instruction')) {
          // Directions from <ol> or <ul>
          final listMatch = RegExp(r'<(?:ol|ul)[^>]*>(.*?)</(?:ol|ul)>', caseSensitive: false, dotAll: true).firstMatch(afterH2);
          if (listMatch != null) {
            final listContent = listMatch.group(1) ?? '';
            final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(listContent);
            for (final liMatch in liMatches) {
              final text = _ingParser.decodeHtml(liMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
              if (text.isNotEmpty && text.length > 5) {
                (result['directions'] as List<String>).add(text);
              }
            }
          }
          // Also check for paragraph text after method heading (for cordial instructions, etc.)
          final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH2);
          for (final pMatch in pMatches) {
            final text = _ingParser.decodeHtml(pMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '');
            // Only add if it looks like a meaningful instruction (contains a verb or starts with asterisk)
            if (text.isNotEmpty && text.length > 10 && (text.contains('*') || text.contains(':'))) {
              if (!(result['directions'] as List<String>).any((d) => d.contains(text) || text.contains(d))) {
                (result['directions'] as List<String>).add(text);
              }
            }
          }
        }
      }
    }
    
    // Return null if we didn't find anything useful
    if ((result['ingredients'] as List).isEmpty && 
        (result['directions'] as List).isEmpty && 
        result['glass'] == null && 
        (result['garnish'] as List).isEmpty) {
      return null;
    }
    
    return result;
  }
  
  /// Clean section header - remove trailing colons and common prefixes
  String _cleanSectionHeader(String header) {
    var cleaned = header.trim();
    // Remove trailing colon
    if (cleaned.endsWith(':')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    // Remove common prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:For\s+(?:the\s+)?)', caseSensitive: false), '');
    return cleaned;
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
    
    // Strategy 3: NYT Cooking (headers with ingredientgroup_name followed by sibling ul)
    final nytHeaders = document.querySelectorAll('[class*="ingredientgroup_name"]');
    if (nytHeaders.isNotEmpty) {
      for (final header in nytHeaders) {
        var headerText = header.text.trim();
        if (headerText.isNotEmpty) {
          // Remove "For the" prefix if present (NYT style)
          final forTheMatch = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false).firstMatch(headerText);
          if (forTheMatch != null) {
            headerText = forTheMatch.group(1)?.trim() ?? headerText;
          }
          results.add('[$headerText]');
        }
        // Find the next sibling ul
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          if (sibling.localName == 'ul') {
            for (final li in sibling.querySelectorAll('li')) {
              final text = li.text.trim();
              if (text.isNotEmpty) results.add(text);
            }
            break;
          } else if (sibling.localName == 'h2' || sibling.localName == 'h3') {
            break; // Next section header
          }
          sibling = sibling.nextElementSibling;
        }
      }
      // Also capture any ingredients before the first header (common in some recipes)
      final allIngLists = document.querySelectorAll('[class*="recipebody_ingredients"] ul');
      if (allIngLists.isNotEmpty && results.isEmpty) {
        for (final ul in allIngLists) {
          for (final li in ul.querySelectorAll('li')) {
            final text = li.text.trim();
            if (text.isNotEmpty) results.add(text);
          }
        }
      }
      if (results.isNotEmpty) return results;
    }
    
    // Strategy 4: Generic section/group containers
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

  /// Strip HTML tags from a string and decode HTML entities
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;|&apos;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _parseImage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is List && data.isNotEmpty) return _parseImage(data.first);
    if (data is Map) return data['url'] as String? ?? data['contentUrl'] as String?;
    return null;
  }
  
  String? _parseTime(Map<String, dynamic> data) {
    // Try various time fields (GBC uses cookTimeCustom)
    final totalTime = data['totalTime'] ?? data['cookTimeCustom'] ?? data['cookTime'] ?? data['prepTime'] ?? data['time'];
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
    
    // Check if it's a known cocktail site
    if (_isCocktailSite(url)) return 'Drinks';
    
    // Guess from URL or name
    final urlLower = url.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    
    if (urlLower.contains('/drink') || urlLower.contains('/cocktail') || name.contains('cocktail') || name.contains('negroni') || name.contains('martini')) return 'Drinks';
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
