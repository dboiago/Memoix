import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/smoking_recipe.dart';

/// Service to import smoking recipes from URLs like amazingribs.com
class SmokingUrlImporter {
  static const _uuid = Uuid();

  /// Known smoking/BBQ recipe sites
  static const knownSites = [
    'amazingribs.com',
    'smokingmeatforums.com',
    'virtualweberbullet.com',
    'bbqu.net',
    'thermoworks.com',
    'seriouseats.com',
    'traeger.com',
    'weber.com',
    'charbroil.com',
    'bbqguys.com',
    'heygrillhey.com',
    'smokedbbqsource.com',
    'meatchurch.com',
    'malcomsbbq.com',
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
    '&deg;': '°',
    '&#176;': '°',
  };

  /// Fraction conversion map
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
  };

  /// Import a smoking recipe from a URL
  Future<SmokingRecipe?> importFromUrl(String url) async {
    try {
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
      final jsonLdScripts =
          document.querySelectorAll('script[type="application/ld+json"]');

      for (final script in jsonLdScripts) {
        try {
          final data = jsonDecode(script.text);
          final recipe = _parseJsonLd(data, url);
          if (recipe != null) return recipe;
        } catch (_) {
          continue;
        }
      }

      // Fallback: try to parse from HTML structure
      return _parseFromHtml(document, url);
    } catch (e) {
      throw Exception('Failed to import smoking recipe from URL: $e');
    }
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

    // Clean up extra whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Clean recipe name - remove common suffixes
  String _cleanRecipeName(String name) {
    var cleaned = _decodeHtml(name);

    // Remove common suffixes
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*[-–—]\s*Recipe\s*$', caseSensitive: false), '');
    cleaned =
        cleaned.replaceAll(RegExp(r'\s+Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'^Recipe\s*[-–—:]\s*', caseSensitive: false), '');

    // Remove "smoked" prefix if it's redundant (we know it's a smoking recipe)
    // But keep it if it's part of the meat name like "Smoked Salmon"
    if (cleaned.toLowerCase().startsWith('smoked ') &&
        !RegExp(r'^smoked\s+(salmon|trout|fish)',
                caseSensitive: false)
            .hasMatch(cleaned)) {
      // Don't remove smoked - it's part of the identity
    }

    return cleaned.trim();
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return _decodeHtml(value.trim());
    if (value is List && value.isNotEmpty) {
      return _decodeHtml(value.first.toString().trim());
    }
    return _decodeHtml(value.toString().trim());
  }

  /// Parse JSON-LD structured data
  SmokingRecipe? _parseJsonLd(dynamic data, String sourceUrl) {
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
    final isRecipe =
        type == 'Recipe' || (type is List && type.contains('Recipe'));

    if (!isRecipe) return null;

    // Parse the recipe data
    final name = _cleanRecipeName(_parseString(data['name']) ?? 'Untitled');
    final cookTime = _parseTime(data);
    final temperature = _detectTemperature(data);
    final wood = _detectWood(data);
    final seasonings = _parseSeasonings(data['recipeIngredient']);
    final directions = _parseInstructions(data['recipeInstructions']);
    final notes = _parseString(data['description']);
    final imageUrl = _parseImage(data['image']);

    return SmokingRecipe.create(
      uuid: _uuid.v4(),
      name: name,
      temperature: temperature ?? '225°F',
      time: cookTime ?? '',
      wood: wood ?? '',
      seasonings: seasonings,
      directions: directions,
      notes: notes,
      imageUrl: imageUrl,
      source: SmokingSource.imported,
    );
  }

  /// Parse cooking time from recipe data
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
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (hours > 0 && mins > 0) {
        return '$hours hr $mins min';
      } else if (hours > 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      } else {
        return '$mins min';
      }
    }

    return null;
  }

  int _parseDurationMinutes(dynamic value) {
    if (value == null) return 0;
    final str = value.toString();

    // Parse ISO 8601 duration (e.g., PT30M, PT1H30M, PT720M)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);

    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      return hours * 60 + minutes;
    }

    return 0;
  }

  String? _parseDuration(dynamic value) {
    if (value == null) return null;
    final str = value.toString();

    // Parse ISO 8601 duration
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(str);

    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;

      if (hours > 0 && minutes > 0) {
        return '$hours hr $minutes min';
      } else if (hours > 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      } else if (minutes > 0) {
        return '$minutes min';
      }
    }

    return str;
  }

  /// Detect smoking temperature from recipe text
  String? _detectTemperature(Map data) {
    // Search in instructions, description, and name
    final textToSearch = [
      _parseString(data['description']) ?? '',
      ...(_parseInstructions(data['recipeInstructions'])),
    ].join(' ');

    // Look for temperature patterns
    // Common smoking temps: 225°F, 250°F, 275°F, 300°F
    final tempPatterns = [
      // Fahrenheit patterns
      RegExp(r'(\d{3})\s*°?\s*F(?:ahrenheit)?', caseSensitive: false),
      RegExp(r'at\s+(\d{3})\s*degrees?', caseSensitive: false),
      RegExp(r'(\d{3})\s*degrees?\s*F', caseSensitive: false),
      // Celsius patterns
      RegExp(r'(\d{2,3})\s*°?\s*C(?:elsius)?', caseSensitive: false),
    ];

    for (final pattern in tempPatterns) {
      final match = pattern.firstMatch(textToSearch);
      if (match != null) {
        final temp = match.group(1);
        if (temp != null) {
          final tempNum = int.tryParse(temp);
          if (tempNum != null) {
            // Determine if F or C based on pattern
            if (pattern.pattern.contains('C(?:elsius)?')) {
              return '$temp°C';
            } else if (tempNum >= 200 && tempNum <= 400) {
              // Likely Fahrenheit
              return '$temp°F';
            } else if (tempNum >= 90 && tempNum <= 200) {
              // Likely Celsius
              return '$temp°C';
            }
          }
        }
      }
    }

    // Default smoking temperature
    return '225°F';
  }

  /// Detect wood type from recipe text
  String? _detectWood(Map data) {
    final textToSearch = [
      _parseString(data['name']) ?? '',
      _parseString(data['description']) ?? '',
      ...(_parseInstructions(data['recipeInstructions'])),
    ].join(' ').toLowerCase();

    // Check for wood types mentioned in text
    for (final wood in WoodSuggestions.common) {
      if (textToSearch.contains(wood.toLowerCase())) {
        // Also check it's in a wood context
        final woodContext = RegExp(
          '(${wood.toLowerCase()})\\s*(wood|chips?|chunks?|pellets?|smoke)',
          caseSensitive: false,
        );
        if (woodContext.hasMatch(textToSearch)) {
          return wood;
        }
      }
    }

    // Secondary check - just look for wood name near "wood" or "smoke"
    for (final wood in WoodSuggestions.common) {
      final pattern = RegExp(
        '(smoke|wood|chips?|chunks?|pellets?).{0,30}${wood.toLowerCase()}|'
        '${wood.toLowerCase()}.{0,30}(smoke|wood|chips?|chunks?|pellets?)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(textToSearch)) {
        return wood;
      }
    }

    // If no wood detected, check for general mentions
    for (final wood in WoodSuggestions.common) {
      if (textToSearch.contains(wood.toLowerCase())) {
        return wood;
      }
    }

    return null;
  }

  /// Parse seasonings/rub ingredients from recipe ingredients
  List<SmokingSeasoning> _parseSeasonings(dynamic value) {
    if (value == null) return [];

    List<String> items;
    if (value is String) {
      items = [value];
    } else if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else {
      return [];
    }

    // Keywords that indicate rub/seasoning ingredients
    final seasoningKeywords = [
      'salt', 'pepper', 'paprika', 'cayenne', 'chili', 'cumin', 'garlic',
      'onion', 'sugar', 'brown sugar', 'mustard', 'rub', 'spice', 'herb',
      'oregano', 'thyme', 'rosemary', 'sage', 'coriander', 'fennel',
      'powder', 'ground', 'dried', 'smoked paprika', 'ancho', 'chipotle',
    ];

    // Keywords to exclude (main meat, liquids)
    final excludeKeywords = [
      'brisket', 'pork', 'beef', 'ribs', 'chicken', 'turkey', 'salmon',
      'broth', 'stock', 'water', 'beer', 'wine', 'vinegar', 'oil',
      'butter', 'sauce', 'marinade',
    ];

    final seasonings = <SmokingSeasoning>[];

    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;

      final lower = decoded.toLowerCase();

      // Check if this is a seasoning ingredient
      final isSeasoning =
          seasoningKeywords.any((kw) => lower.contains(kw));
      final isExcluded = excludeKeywords.any((kw) => lower.contains(kw));

      if (isSeasoning && !isExcluded) {
        final seasoning = _parseSeasoningString(decoded);
        if (seasoning.name.isNotEmpty) {
          seasonings.add(seasoning);
        }
      }
    }

    return seasonings;
  }

  /// Parse a single seasoning string into structured data
  SmokingSeasoning _parseSeasoningString(String text) {
    var remaining = text;

    // Try to extract amount (number at start)
    String? amount;
    final amountMatch = RegExp(
      r'^([\d½¼¾⅓⅔⅛⅜⅝⅞.]+)\s*'
      r'(tsp|teaspoon|Tbsp|tablespoon|cup|oz|ounce|pound|lb|g|kg)s?\s+',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (amountMatch != null) {
      final number = amountMatch.group(1)?.trim() ?? '';
      final unit = amountMatch.group(2)?.trim() ?? '';
      amount = '$number $unit'.trim();
      remaining = remaining.substring(amountMatch.end).trim();
    }

    // Clean up the name
    remaining = remaining.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    remaining = remaining.replaceAll(RegExp(r',.*$'), '').trim();

    return SmokingSeasoning.create(
      name: remaining,
      amount: amount,
    );
  }

  /// Parse instructions from recipe data
  List<String> _parseInstructions(dynamic value) {
    if (value == null) return [];

    if (value is String) {
      return _decodeHtml(value)
          .split(RegExp(r'\n+|\. (?=[A-Z])'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }

    if (value is List) {
      final result = <String>[];
      for (final item in value) {
        String? text;
        if (item is String) {
          text = item.trim();
        } else if (item is Map) {
          text = _parseString(item['text']) ?? _parseString(item['name']);
        } else {
          text = item.toString().trim();
        }

        if (text != null && text.isNotEmpty) {
          // Clean up the instruction text
          var cleaned = _decodeHtml(text);
          
          // Remove step name if it duplicates the text
          if (cleaned.contains('. ')) {
            final parts = cleaned.split('. ');
            if (parts.length == 2 && 
                parts[0].toLowerCase() == parts[1].toLowerCase().substring(0, parts[0].length.clamp(0, parts[1].length))) {
              cleaned = parts[1];
            }
          }
          
          // Simplify very long instructions
          if (cleaned.length > 500) {
            // Try to extract the key action
            final sentences = cleaned.split(RegExp(r'\.\s+'));
            if (sentences.isNotEmpty) {
              // Take first 2-3 sentences
              cleaned = sentences.take(3).join('. ');
              if (!cleaned.endsWith('.')) cleaned += '.';
            }
          }

          result.add(cleaned);
        }
      }
      return result;
    }

    return [];
  }

  /// Parse image URL from recipe data
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

  /// Fallback HTML parsing for sites without JSON-LD
  SmokingRecipe? _parseFromHtml(dynamic document, String sourceUrl) {
    final title = document.querySelector('h1')?.text?.trim() ??
        document.querySelector('.recipe-title')?.text?.trim() ??
        document.querySelector('[itemprop="name"]')?.text?.trim() ??
        'Untitled';

    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"]',
    );

    final seasonings = <SmokingSeasoning>[];
    for (final el in ingredientElements) {
      final text = _decodeHtml(el.text.trim());
      if (text.isNotEmpty) {
        final seasoning = _parseSeasoningString(text);
        if (seasoning.name.isNotEmpty) {
          seasonings.add(seasoning);
        }
      }
    }

    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li',
    );

    final directions = instructionElements
        .map((e) => _decodeHtml(e.text.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    if (seasonings.isEmpty && directions.isEmpty) {
      return null;
    }

    return SmokingRecipe.create(
      uuid: _uuid.v4(),
      name: _cleanRecipeName(title),
      temperature: '225°F',
      time: '',
      wood: '',
      seasonings: seasonings,
      directions: directions,
      source: SmokingSource.imported,
    );
  }
}

/// Provider for SmokingUrlImporter
final smokingUrlImporterProvider = Provider<SmokingUrlImporter>((ref) {
  return SmokingUrlImporter();
});
