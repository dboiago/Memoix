import 'dart:convert';
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
  static const _uuid = Uuid();

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
    // Handle truncated or colloquial variants like "tables"/"table"
    RegExp(r'\btables?\b', caseSensitive: false): 'Tbsp',
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
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Memoix Recipe App/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch URL: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      
      for (final script in jsonLdScripts) {
        try {
          final data = jsonDecode(script.text);
          final result = _parseJsonLdWithConfidence(data, url);
          if (result != null) return result;
        } catch (_) {
          continue;
        }
      }

      // Fallback: try to parse from HTML structure
      final result = _parseFromHtmlWithConfidence(document, url);
      if (result != null) return result;
      
      throw Exception('Could not find recipe data on this page');
    } catch (e) {
      throw Exception('Failed to import recipe from URL: $e');
    }
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
      
      final body = response.body;
      
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
      String transcriptDebug = '';
      try {
        final (segments, debug) = await _fetchYouTubeTranscriptWithTimestamps(videoId, body);
        transcriptSegments = segments;
        transcriptDebug = debug;
      } catch (e) {
        transcriptDebug = 'err: $e';
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
      String recipeName = _cleanYouTubeTitle(title ?? 'YouTube Recipe');
      
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
            recipeTime = '${totalMinutes} min';
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
      
      // Create raw ingredient data for review
      final rawIngredients = rawIngredientStrings.map((raw) {
        final parsed = _parseIngredientString(raw);
        final bakerPct = _extractBakerPercent(raw);
        return RawIngredientData(
          original: raw,
          amount: parsed.amount,
          unit: parsed.unit,
          preparation: parsed.preparation,
          bakerPercent: bakerPct != null ? '$bakerPct%' : null,
          name: parsed.name.isNotEmpty ? parsed.name : raw,
          looksLikeIngredient: parsed.name.isNotEmpty,
          isSection: parsed.section != null,
          sectionName: parsed.section,
        );
      }).toList();
      
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
        nameConfidence: title != null ? 0.7 : 0.3,
        courseConfidence: detectedCourse != null ? 0.7 : 0.3,
        ingredientsConfidence: hasIngredients ? 0.6 : 0.0,
        directionsConfidence: hasDirections 
            ? (transcriptSegments.isNotEmpty ? 0.7 : 0.5) 
            : 0.0,
        timeConfidence: recipeTime != null ? 0.8 : 0.0,
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
    
    // Breads course keywords
    if (RegExp(r'\b(?:bread|focaccia|ciabatta|baguette|brioche|sourdough|rolls?|buns?|loaf|loaves|naan|pita|flatbread|bagels?|croissants?|pretzels?|challah)\b').hasMatch(lowerTitle)) {
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
    
    // Drinks course keywords
    if (RegExp(r'\b(?:cocktail|smoothie|juice|lemonade|drink|beverage|mocktail|sangria|punch|milkshake|frappe|coffee|espresso|latte|tea)\b').hasMatch(lowerTitle)) {
      return 'Drinks';
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
          } else if (line.length > 10 && line.length < 80 && !looksLikeIng) {
            // Medium-length line in directions section - could be a step description
            // Only add if it doesn't look like intro text
            if (!line.contains('...') && !line.endsWith('!')) {
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
    // Starts with cooking action verb
    if (RegExp(r'^(?:preheat|heat|mix|combine|add|stir|whisk|fold|pour|place|put|cook|bake|roast|fry|sauté|boil|simmer|reduce|let|allow|serve|garnish|season|taste|check|remove|transfer|set|cover|wrap|chill|refrigerate|freeze|blend|process|pulse|slice|dice|chop|mince|grate|shred|fold|knead|proof|rise|ferment|dimpl|topp|cutt|plac)\b', caseSensitive: false).hasMatch(line)) {
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
          ));
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
          ));
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
            lastError = 'youtubei($foundPattern): 0 segs from ${transcriptResponse.body.length}b';
          } else {
            lastError = 'youtubei($foundPattern): ${transcriptResponse.statusCode}';
          }
        } catch (e) {
          lastError = 'youtubei err: $e';
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
              var freshCaptionUrl = _decodeUnicodeEscapes(captionMatch.group(1)!);
              // Add format parameter
              if (!freshCaptionUrl.contains('fmt=')) {
                freshCaptionUrl = '$freshCaptionUrl&fmt=json3';
              }
              
              final captionResponse = await http.get(
                Uri.parse(freshCaptionUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                },
              );
              
              if (captionResponse.statusCode == 200 && captionResponse.body.isNotEmpty) {
                final segments = _parseTranscriptJson(captionResponse.body);
                if (segments.isNotEmpty) {
                  return (segments, 'player: ${segments.length} segments');
                }
                // Try XML parsing
                final xmlSegments = _parseTranscriptXmlWithTimestamps(captionResponse.body);
                if (xmlSegments.isNotEmpty) {
                  return (xmlSegments, 'player-xml: ${xmlSegments.length} segments');
                }
                lastError = '$lastError | player:0segs';
              } else {
                lastError = '$lastError | player-cap:${captionResponse.statusCode}';
              }
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
          ));
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
            ));
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
          s.startSeconds < nextChapterStart
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

  /// Decode HTML entities and normalise text
  String _decodeHtml(String text) {
    var result = text;
    
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
    var ingredients = _parseIngredients(data['recipeIngredient']);
    ingredients = _sortIngredientsByQuantity(ingredients);

    // Parse nutrition information if available
    final nutrition = _parseNutrition(data['nutrition']);

    // Determine course with drink detection
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    
    // For drinks, detect the base spirit and set as subcategory
    String? subcategory;
    if (course == 'drinks') {
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
    final rawIngredientStrings = _extractRawIngredients(data['recipeIngredient']);
    var ingredients = _parseIngredients(data['recipeIngredient']);
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
    final directions = _parseInstructions(data['recipeInstructions']);
    final rawDirections = _extractRawDirections(data['recipeInstructions']);
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

    // For drinks, detect the base spirit
    String? subcategory;
    if (course == 'drinks') {
      subcategory = _detectSpirit(ingredients);
      if (subcategory != null) {
        subcategory = Spirit.toDisplayName(subcategory);
      }
    }

    // Create raw ingredient data
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      final bakerPct = _extractBakerPercent(raw);
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        preparation: parsed.preparation,
        bakerPercent: bakerPct != null ? '$bakerPct%' : null,
        name: parsed.name.isNotEmpty ? parsed.name : raw,
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    }).toList();

    return RecipeImportResult(
      name: name.isNotEmpty ? name : null,
      course: course,
      cuisine: cuisine,
      subcategory: subcategory,
      serves: serves,
      time: time,
      ingredients: ingredients,
      directions: directions,
      notes: _decodeHtml(_parseString(data['description']) ?? ''),
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
      return value
          .map((e) => _decodeHtml(e.toString().trim()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
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
    if (allText.contains('drink') || allText.contains('cocktail') || allText.contains('beverage')) courses.add('drinks');
    if (allText.contains('vegetarian') || allText.contains('vegan')) courses.add("Veg'n");
    
    // Always include Mains as default option
    if (courses.isEmpty) courses.add('Mains');
    
    return courses.toList()..sort();
  }

  /// Detect all possible cuisines from recipe data
  List<String> _detectAllCuisines(Map data) {
    final cuisines = <String>{};
    final cuisine = _parseString(data['recipeCuisine'])?.toLowerCase() ?? '';
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final allText = '$cuisine $keywords $name';
    
    // Check for cuisine indicators
    final cuisineIndicators = {
      'american': 'USA', 'southern': 'USA', 'cajun': 'USA',
      'french': 'France', 'italian': 'Italy', 'spanish': 'Spain',
      'mexican': 'Mexico', 'chinese': 'China', 'japanese': 'Japan',
      'korean': 'Korea', 'thai': 'Thailand', 'vietnamese': 'Vietnam',
      'indian': 'India', 'greek': 'Greece', 'mediterranean': 'Mediterranean',
      'middle eastern': 'Middle East', 'moroccan': 'Morocco',
      'caribbean': 'Caribbean', 'brazilian': 'Brazil',
    };
    
    cuisineIndicators.forEach((indicator, cuisineName) {
      if (allText.contains(indicator)) {
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
    if (value is String) return _decodeHtml(value);
    if (value is num) return value.toString();
    if (value is List && value.isNotEmpty) return _decodeHtml(value.first.toString());
    return null;
  }

  /// Parse cuisine - convert region names to country names
  String? _parseCuisine(dynamic value) {
    if (value == null) return null;
    
    var cuisine = _parseString(value);
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Map regions to countries
    final regionToCountry = {
      'american': 'USA',
      'southern': 'USA',
      'cajun': 'USA',
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
      'north american': 'USA',
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
    
    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M)
    final iso = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final isoMatch = iso.firstMatch(str);
    
    if (isoMatch != null) {
      final hours = int.tryParse(isoMatch.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(isoMatch.group(2) ?? '') ?? 0;
      return hours * 60 + minutes;
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
    
    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);
    
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      
      // Always use _formatMinutes to properly handle large durations
      final totalMinutes = hours * 60 + minutes;
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
    // Common patterns: "For the sauce:", "Sauce:", "Main Ingredients:", etc.
    String? currentSection;
    final result = <Ingredient>[];
    
    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;
      
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
            ));
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
      r'^[^,]+,\s*([\d.]+)%\s*[–-]',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  /// Parse a single ingredient string into structured data
  Ingredient _parseIngredientString(String text) {
    var remaining = text;
    bool isOptional = false;
    List<String> notesParts = [];
    String? amount;
    String? inlineSection;
    
    // Handle baker's percentage format: "All-Purpose Flour, 100% – 600g (4 1/2 Cups)"
    // or "Warm Water, 75% – 450g (2 Cups)" or "Extra Virgin Olive Oil, 3.3% – 20g (2 tbsp.)"
    final bakerPercentMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–-]\s*(\d+\s*(?:g|kg|ml|l))\s*(?:\(([^)]+)\))?',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (bakerPercentMatch != null) {
      final name = bakerPercentMatch.group(1)?.trim() ?? '';
      final bakerPercent = bakerPercentMatch.group(2)?.trim(); // Capture for future use
      final metric = bakerPercentMatch.group(3)?.trim() ?? '';
      final imperial = bakerPercentMatch.group(4)?.trim();
      
      // Use metric as the amount, imperial as preparation/notes
      // In future, bakerPercent could be stored in a separate field
      return Ingredient.create(
        name: name,
        amount: metric,
        preparation: imperial,
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
    }
    
    // Remove footnote markers like [1], *, †, etc.
    remaining = remaining.replaceAll(RegExp(r'\[\d+\]|\*+|†+'), '').trim();
    
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
        // Check if it's a weight conversion (e.g., "0.6 pounds", "1 lb", "500g")
        final isWeightConversion = RegExp(
          r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$',
          caseSensitive: false
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
      r'(\s*(?:cup|cups|Tbsp|tsp|oz|lb|kg|g|ml|L|pound|pounds|ounce|ounces|inch|inches|in|cm)s?)?\s+',
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
        r'(\s*(?:cup|cups|Tbsp|tsp|oz|lb|kg|g|ml|L|pound|pounds|ounce|ounces|inch|inches|in|cm)s?)?\s+',
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
      // Original pattern for simple amounts and ranges
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+|[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:cup|cups|Tbsp|tsp|oz|lb|kg|g|ml|L|pound|pounds|ounce|ounces|inch|inches|in|cm)s?)?\s+',
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
    final commaIndex = remaining.indexOf(',');
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
              .trim())
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
    final category = _parseString(data['recipeCategory'])?.toLowerCase();
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final description = _parseString(data['description'])?.toLowerCase() ?? '';
    
    // Check if this is from a cocktail site
    if (sourceUrl != null && _isCocktailSite(sourceUrl)) {
      return 'drinks';
    }
    
    // Check for drink/cocktail indicators in the data
    if (_isDrinkRecipe(category, keywords, name, description)) {
      return 'drinks';
    }
    
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
    
    if (keywords.contains('vegetarian') || keywords.contains('vegan')) return "Veg'n";
    
    return 'Mains'; // Default
  }

  /// Check if this is a drink/cocktail recipe based on content
  bool _isDrinkRecipe(String? category, String keywords, String name, String description) {
    final allText = '${category ?? ''} $keywords $name $description'.toLowerCase();
    
    // Cocktail/drink category indicators
    const drinkIndicators = [
      'cocktail', 'cocktails', 'drink', 'drinks', 'beverage', 'beverages',
      'martini', 'margarita', 'mojito', 'negroni', 'manhattan', 'daiquiri',
      'old fashioned', 'old-fashioned', 'highball', 'lowball', 'sour',
      'fizz', 'collins', 'spritz', 'punch', 'shooter', 'shot',
      'mocktail', 'smoothie', 'shake', 'milkshake',
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
    
    // If category specifically mentions spirits, it's likely a drink
    if (category != null) {
      for (final spirit in spiritIndicators) {
        if (category.contains(spirit)) return true;
      }
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
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient'
    );
    
    var rawIngredientStrings = <String>[];
    for (final e in ingredientElements) {
      final text = _decodeHtml((e.text ?? '').trim());
      if (text.isNotEmpty) {
        rawIngredientStrings.add(text);
      }
    }
    
    // If standard selectors failed, try section-based parsing
    List<String> equipmentItems = [];
    String? yield;
    String? timing;
    
    if (rawIngredientStrings.isEmpty) {
      final sectionResult = _parseHtmlBySections(document);
      rawIngredientStrings = sectionResult['ingredients'] ?? [];
      equipmentItems = sectionResult['equipment'] ?? [];
      yield = sectionResult['yield'];
      timing = sectionResult['timing'];
    }
    
    var ingredients = rawIngredientStrings
        .map((e) => _parseIngredientString(e))
        .where((i) => i.name.isNotEmpty)
        .toList();
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    // First try standard direction selectors
    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction'
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
      course = 'drinks';
    } else if (_isModernistRecipe(document, sourceUrl, rawIngredientStrings)) {
      course = 'molecular';
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
  RecipeImportResult? _parseFromHtmlWithConfidence(dynamic document, String sourceUrl) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim();

    // First try standard recipe selectors
    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient'
    );
    
    var rawIngredientStrings = <String>[];
    for (final e in ingredientElements) {
      final text = _decodeHtml((e.text ?? '').trim());
      if (text.isNotEmpty) {
        rawIngredientStrings.add(text);
      }
    }
    
    // If standard selectors failed, try section-based parsing
    // This handles sites like Modernist Pantry that use headings + lists
    List<String> equipmentItems = [];
    String? yield;
    String? timing;
    
    if (rawIngredientStrings.isEmpty) {
      final sectionResult = _parseHtmlBySections(document);
      rawIngredientStrings = sectionResult['ingredients'] ?? [];
      equipmentItems = sectionResult['equipment'] ?? [];
      yield = sectionResult['yield'];
      timing = sectionResult['timing'];
    }
    
    var ingredients = rawIngredientStrings
        .map((s) => _parseIngredientString(s))
        .where((i) => i.name.isNotEmpty)
        .toList();
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    // First try standard direction selectors
    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction'
    );
    
    var rawDirections = <String>[];
    for (final e in instructionElements) {
      final text = _decodeHtml((e.text ?? '').trim());
      if (text.isNotEmpty) {
        rawDirections.add(text);
      }
    }
    
    // If standard selectors failed, try step-based parsing
    // This handles sites that use h3 headings for step names
    if (rawDirections.isEmpty) {
      rawDirections = _parseDirectionsBySections(document);
    }

    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktail = _isCocktailSite(sourceUrl);
    
    // Try to detect course from content - check for modernist/molecular indicators
    String course;
    if (isCocktail) {
      course = 'drinks';
    } else if (_isModernistRecipe(document, sourceUrl, rawIngredientStrings)) {
      course = 'molecular';
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

    // Calculate confidence - HTML parsing is generally less reliable
    final nameConfidence = title != null && title.isNotEmpty ? 0.7 : 0.0;
    final ingredientsConfidence = rawIngredientStrings.isNotEmpty 
        ? (ingredients.length / rawIngredientStrings.length) * 0.6 
        : 0.0;
    final directionsConfidence = rawDirections.isNotEmpty ? 0.6 : 0.0;
    double courseConfidence;
    if (isCocktail) {
      courseConfidence = 0.8;
    } else if (course == 'molecular') {
      courseConfidence = 0.75;
    } else {
      courseConfidence = 0.3; // Low confidence for defaulting to Mains
    }

    // Create raw ingredient data
    final rawIngredients = rawIngredientStrings.map((raw) {
      final parsed = _parseIngredientString(raw);
      final bakerPct = _extractBakerPercent(raw);
      return RawIngredientData(
        original: raw,
        amount: parsed.amount,
        unit: parsed.unit,
        preparation: parsed.preparation,
        bakerPercent: bakerPct != null ? '$bakerPct%' : null,
        name: parsed.name.isNotEmpty ? parsed.name : raw,
        looksLikeIngredient: parsed.name.isNotEmpty,
        isSection: parsed.section != null,
        sectionName: parsed.section,
      );
    }).toList();

    // Build detected courses list
    final detectedCourses = <String>[];
    if (isCocktail) {
      detectedCourses.add('drinks');
    }
    if (course == 'molecular') {
      detectedCourses.add('molecular');
    }
    if (detectedCourses.isEmpty) {
      detectedCourses.add('Mains');
    }

    // Build notes from equipment if found
    String? notes;
    if (equipmentItems.isNotEmpty) {
      notes = 'Equipment: ${equipmentItems.join(', ')}';
    }

    return RecipeImportResult(
      name: title != null ? _cleanRecipeName(title) : null,
      course: course,
      subcategory: subcategory,
      serves: yield,
      time: timing,
      ingredients: ingredients,
      directions: rawDirections,
      notes: notes,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: detectedCourses,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }
  
  /// Parse HTML by looking for section headings (h2, h3) followed by content
  /// This handles sites like Modernist Pantry that structure recipes with headings
  Map<String, dynamic> _parseHtmlBySections(dynamic document) {
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'equipment': <String>[],
      'yield': null,
      'timing': null,
    };
    
    // Find all h2 headings and check their text
    final headings = document.querySelectorAll('h2');
    
    for (final heading in headings) {
      final headingText = heading.text?.trim().toLowerCase() ?? '';
      
      // Find the next sibling elements after this heading
      var nextElement = heading.nextElementSibling;
      
      if (headingText.contains('ingredient')) {
        // Parse ingredients from the list following this heading
        final ingredients = _extractListItemsAfterHeading(heading, document);
        result['ingredients'] = ingredients;
      } else if (headingText.contains('equipment')) {
        // Parse equipment from the list following this heading
        final equipment = _extractListItemsAfterHeading(heading, document);
        result['equipment'] = equipment;
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
    
    // If we didn't find ingredients with h2, try looking for lists with specific patterns
    if ((result['ingredients'] as List).isEmpty) {
      // Look for lists that contain ingredient-like items (amounts + names)
      final allLists = document.querySelectorAll('ul');
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
        final hasQuantities = itemTexts.any((item) => 
          RegExp(r'\d+\s*[gG](?:\s|$)|\d+\s*(?:cup|tbsp|tsp|oz|ml|lb|kg)', caseSensitive: false).hasMatch(item)
        );
        
        if (hasQuantities && itemTexts.length >= 3) {
          result['ingredients'] = _processIngredientListItems(itemTexts);
          break;
        }
      }
    }
    
    return result;
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
        break;
      } else if (tagName == 'h2' || tagName == 'h3') {
        // Hit another heading - stop searching
        break;
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
                break;
              } else if (tagName == 'h2' || tagName == 'h3') {
                break;
              }
            }
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
    
    for (final item in items) {
      // Check if this is a section header (ends with colon, starts with "Ingredients")
      final isSectionHeader = RegExp(
        r'^Ingredients?\s+(?:for\s+)?(.+?)[:.]?\s*$',
        caseSensitive: false,
      ).hasMatch(item);
      
      if (isSectionHeader) {
        // Extract section name and format as [Section] marker
        final match = RegExp(
          r'^Ingredients?\s+(?:for\s+)?(.+?)[:.]?\s*$',
          caseSensitive: false,
        ).firstMatch(item);
        if (match != null) {
          final sectionName = match.group(1)?.trim() ?? item;
          processed.add('[${_capitalise(sectionName)}]');
        }
      } else if (item.isNotEmpty) {
        processed.add(item);
      }
    }
    
    return processed;
  }
  
  /// Parse directions by looking for step-based structure (h3 headings or numbered sections)
  List<String> _parseDirectionsBySections(dynamic document) {
    final directions = <String>[];
    
    // Look for h3 headings that might be step titles
    final stepHeadings = document.querySelectorAll('h3');
    
    for (final heading in stepHeadings) {
      final stepTitle = _decodeHtml(heading.text?.trim() ?? '');
      if (stepTitle.isEmpty) continue;
      
      // Skip if this looks like a non-recipe heading (navigation, etc.)
      if (_isNavigationHeading(stepTitle)) continue;
      
      // Collect text content after this heading until the next h3
      final stepParts = <String>[stepTitle];
      var nextElement = heading.nextElementSibling;
      
      while (nextElement != null) {
        final tagName = nextElement.localName?.toLowerCase();
        
        // Stop at the next step heading
        if (tagName == 'h3' || tagName == 'h2') break;
        
        // Extract text from divs, paragraphs, etc.
        if (tagName == 'div' || tagName == 'p' || tagName == 'span') {
          final text = _decodeHtml(nextElement.text?.trim() ?? '');
          // Filter out empty or whitespace-only text
          if (text.isNotEmpty && text != ' ') {
            stepParts.add(text);
          }
        }
        
        nextElement = nextElement.nextElementSibling;
      }
      
      // Combine step title with its content
      if (stepParts.length > 1) {
        // Format: "Step Title: instructions..."
        final stepContent = stepParts.skip(1).join(' ').trim();
        if (stepContent.isNotEmpty) {
          directions.add('$stepTitle: $stepContent');
        }
      } else if (stepParts.length == 1 && stepTitle.length > 10) {
        // If only title but it's descriptive, add it as a direction
        directions.add(stepTitle);
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
  
  /// Check if this looks like a modernist/molecular gastronomy recipe
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
}

// Provider for URL recipe importer
final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
