import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/smoking_recipe.dart';
import '../models/smoking_import_result.dart';

/// Service to import smoking recipes from URLs like amazingribs.com
/// Returns SmokingImportResult with confidence scores for user review
class SmokingUrlImporter {
  static const _uuid = Uuid();

  /// Known smoking/BBQ recipe sites (higher confidence)
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

  /// HTML entity decode map
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
  /// Returns SmokingImportResult with confidence scores
  Future<SmokingImportResult> importFromUrl(String url) async {
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
      final isKnownSite = knownSites.any((site) => url.contains(site));

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts =
          document.querySelectorAll('script[type="application/ld+json"]');

      for (final script in jsonLdScripts) {
        try {
          final data = jsonDecode(script.text);
          final result = _parseJsonLd(data, url, isKnownSite);
          if (result != null) return result;
        } catch (_) {
          continue;
        }
      }

      // Fallback: try to parse from HTML structure
      final result = _parseFromHtml(document, url, isKnownSite);
      if (result != null) return result;

      // Return empty result if nothing found
      return SmokingImportResult(
        sourceUrl: url,
        nameConfidence: 0,
        temperatureConfidence: 0,
        timeConfidence: 0,
        woodConfidence: 0,
        seasoningsConfidence: 0,
        directionsConfidence: 0,
      );
    } catch (e) {
      throw Exception('Failed to import smoking recipe from URL: $e');
    }
  }

  /// Decode HTML entities and normalise text
  String _decodeHtml(String text) {
    var result = text;

    _htmlEntities.forEach((entity, char) {
      result = result.replaceAll(entity, char);
    });

    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );

    _fractionMap.forEach((fraction, unicode) {
      result = result.replaceAll(fraction, unicode);
    });

    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  String _cleanRecipeName(String name) {
    var cleaned = _decodeHtml(name);
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*[-–—]\s*Recipe\s*$', caseSensitive: false), '');
    cleaned =
        cleaned.replaceAll(RegExp(r'\s+Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'^Recipe\s*[-–—:]\s*', caseSensitive: false), '');
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

  /// Parse JSON-LD structured data with confidence scoring
  SmokingImportResult? _parseJsonLd(
      dynamic data, String sourceUrl, bool isKnownSite) {
    // Handle @graph structure
    if (data is Map && data['@graph'] != null) {
      final graph = data['@graph'] as List;
      for (final item in graph) {
        final result = _parseJsonLd(item, sourceUrl, isKnownSite);
        if (result != null) return result;
      }
      return null;
    }

    // Handle array of items
    if (data is List) {
      for (final item in data) {
        final result = _parseJsonLd(item, sourceUrl, isKnownSite);
        if (result != null) return result;
      }
      return null;
    }

    if (data is! Map) return null;

    final type = data['@type'];
    final isRecipe =
        type == 'Recipe' || (type is List && type.contains('Recipe'));

    if (!isRecipe) return null;

    // Extract name
    final name = _cleanRecipeName(_parseString(data['name']) ?? 'Untitled');
    final nameConfidence = name.isNotEmpty && name != 'Untitled' ? 1.0 : 0.3;

    // Extract time
    final cookTime = _parseTime(data);
    final timeConfidence = cookTime != null && cookTime.isNotEmpty ? 0.9 : 0.0;

    // Detect temperatures (all found, plus best guess)
    final tempResult = _detectTemperatures(data);
    final temperature = tempResult['selected'] as String?;
    final detectedTemps = tempResult['all'] as List<String>;
    final tempConfidence = tempResult['confidence'] as double;

    // Detect woods (all found, plus best guess)
    final woodResult = _detectWoods(data);
    final wood = woodResult['selected'] as String?;
    final detectedWoods = woodResult['all'] as List<String>;
    final woodConfidence = woodResult['confidence'] as double;

    // Parse all ingredients with classification
    final ingredientResult = _parseAllIngredients(data['recipeIngredient']);
    final rawIngredients = ingredientResult['raw'] as List<RawIngredient>;
    final seasonings = ingredientResult['seasonings'] as List<SmokingSeasoning>;
    final seasoningsConfidence = ingredientResult['confidence'] as double;

    // Parse directions
    final directions = _parseInstructions(data['recipeInstructions']);
    final directionsConfidence = directions.isNotEmpty
        ? (directions.length >= 3 ? 1.0 : 0.7)
        : 0.0;

    // Parse other fields
    final notes = _parseString(data['description']);
    final imageUrl = _parseImage(data['image']);

    // Boost confidence for known BBQ sites
    final siteBoost = isKnownSite ? 0.1 : 0.0;

    return SmokingImportResult(
      name: name,
      temperature: temperature,
      time: cookTime,
      wood: wood,
      seasonings: seasonings,
      directions: directions,
      notes: notes,
      imageUrl: imageUrl,
      rawIngredients: rawIngredients,
      detectedTemperatures: detectedTemps,
      detectedWoods: detectedWoods,
      rawDirections: directions,
      nameConfidence: (nameConfidence + siteBoost).clamp(0.0, 1.0),
      temperatureConfidence: (tempConfidence + siteBoost).clamp(0.0, 1.0),
      timeConfidence: (timeConfidence + siteBoost).clamp(0.0, 1.0),
      woodConfidence: (woodConfidence + siteBoost).clamp(0.0, 1.0),
      seasoningsConfidence: (seasoningsConfidence + siteBoost).clamp(0.0, 1.0),
      directionsConfidence: (directionsConfidence + siteBoost).clamp(0.0, 1.0),
      sourceUrl: sourceUrl,
    );
  }

  String? _parseTime(Map data) {
    if (data['totalTime'] != null) {
      final total = _parseDuration(data['totalTime']);
      if (total != null) return total;
    }

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
    // Fallback: parse non-ISO strings like "380 minutes", "6 hours 20 minutes"
    final lowered = str.toLowerCase().trim();
    final pureNumber = int.tryParse(lowered);
    if (pureNumber != null) {
      return _formatMinutes(pureNumber);
    }
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
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(lowered);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1) ?? '') ?? 0;
      final hrs = hoursMatch != null ? (int.tryParse(hoursMatch.group(1)!) ?? 0) : 0;
      final mins = minsMatch != null ? (int.tryParse(minsMatch.group(1)!) ?? 0) : 0;
      return _formatMinutes(days * 1440 + hrs * 60 + mins);
    }
    return lowered;
  }

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

  /// Detect all temperatures and return best guess with confidence
  Map<String, dynamic> _detectTemperatures(Map data) {
    final textToSearch = [
      _parseString(data['description']) ?? '',
      ...(_parseInstructions(data['recipeInstructions'])),
    ].join(' ');

    final temps = <String>[];
    final tempPatterns = [
      RegExp(r'(\d{3})\s*°\s*F', caseSensitive: false),
      RegExp(r'(\d{3})\s*degrees?\s*F', caseSensitive: false),
      RegExp(r'at\s+(\d{3})\s*°?', caseSensitive: false),
      RegExp(r'(\d{2,3})\s*°\s*C', caseSensitive: false),
    ];

    for (final pattern in tempPatterns) {
      for (final match in pattern.allMatches(textToSearch)) {
        final temp = match.group(1);
        if (temp != null) {
          final tempNum = int.tryParse(temp);
          if (tempNum != null) {
            String formatted;
            if (pattern.pattern.contains('C')) {
              formatted = '$temp°C';
            } else if (tempNum >= 200 && tempNum <= 400) {
              formatted = '$temp°F';
            } else if (tempNum >= 90 && tempNum <= 200) {
              formatted = '$temp°C';
            } else {
              continue;
            }
            if (!temps.contains(formatted)) {
              temps.add(formatted);
            }
          }
        }
      }
    }

    // Find most likely smoking temperature (200-300°F range)
    String? selected;
    double confidence = 0.0;

    for (final temp in temps) {
      final numMatch = RegExp(r'(\d+)').firstMatch(temp);
      if (numMatch != null) {
        final num = int.tryParse(numMatch.group(1)!);
        if (num != null) {
          // Prefer typical smoking temps
          if (temp.contains('F') && num >= 200 && num <= 300) {
            selected = temp;
            confidence = 0.9;
            break;
          } else if (temp.contains('C') && num >= 100 && num <= 150) {
            selected = temp;
            confidence = 0.9;
            break;
          }
        }
      }
    }

    // Use first found if no ideal match
    if (selected == null && temps.isNotEmpty) {
      selected = temps.first;
      confidence = 0.5;
    }

    return {
      'selected': selected,
      'all': temps,
      'confidence': confidence,
    };
  }

  /// Detect all wood mentions and return best guess with confidence
  Map<String, dynamic> _detectWoods(Map data) {
    final textToSearch = [
      _parseString(data['name']) ?? '',
      _parseString(data['description']) ?? '',
      ...(_parseInstructions(data['recipeInstructions'])),
    ].join(' ').toLowerCase();

    final woods = <String>[];
    String? selected;
    double confidence = 0.0;

    // Check each known wood type
    for (final wood in WoodSuggestions.common) {
      if (textToSearch.contains(wood.toLowerCase())) {
        if (!woods.contains(wood)) {
          woods.add(wood);
        }

        // Check if it's in a wood context (higher confidence)
        final woodContext = RegExp(
          '(${wood.toLowerCase()})\\s*(wood|chips?|chunks?|pellets?|smoke)|'
          '(smoke|wood|chips?|chunks?|pellets?)\\s*(${wood.toLowerCase()})',
          caseSensitive: false,
        );
        if (woodContext.hasMatch(textToSearch)) {
          selected = wood;
          confidence = 0.9;
          break;
        }
      }
    }

    // Use first found if no contextual match
    if (selected == null && woods.isNotEmpty) {
      selected = woods.first;
      confidence = 0.5; // Lower confidence without context
    }

    return {
      'selected': selected,
      'all': woods,
      'confidence': confidence,
    };
  }

  /// Parse all ingredients and classify them
  Map<String, dynamic> _parseAllIngredients(dynamic value) {
    if (value == null) {
      return {
        'raw': <RawIngredient>[],
        'seasonings': <SmokingSeasoning>[],
        'confidence': 0.0,
      };
    }

    List<String> items;
    if (value is String) {
      items = [value];
    } else if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else {
      return {
        'raw': <RawIngredient>[],
        'seasonings': <SmokingSeasoning>[],
        'confidence': 0.0,
      };
    }

    // Classification keywords
    const seasoningKeywords = [
      'salt', 'pepper', 'paprika', 'cayenne', 'chili', 'cumin', 'garlic',
      'onion powder', 'sugar', 'brown sugar', 'mustard', 'rub', 'spice',
      'oregano', 'thyme', 'rosemary', 'sage', 'coriander', 'fennel',
      'powder', 'ground', 'dried', 'smoked paprika', 'ancho', 'chipotle',
    ];

    const proteinKeywords = [
      'brisket', 'pork', 'beef', 'ribs', 'chicken', 'turkey', 'salmon',
      'pork butt', 'pork shoulder', 'chuck', 'tri-tip', 'lamb', 'duck',
    ];

    const liquidKeywords = [
      'broth', 'stock', 'water', 'beer', 'wine', 'vinegar', 'oil',
      'butter', 'sauce', 'marinade', 'juice', 'cider',
    ];

    final rawIngredients = <RawIngredient>[];
    final seasonings = <SmokingSeasoning>[];
    int seasoningMatches = 0;

    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;

      final lower = decoded.toLowerCase();

      // Parse amount and name
      String? amount;
      String name = decoded;

      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞.]+\s*'
        r'(?:tsp|teaspoon|Tbsp|tablespoon|cup|oz|ounce|pound|lb|g|kg)s?)\s+',
        caseSensitive: false,
      ).firstMatch(decoded);

      if (amountMatch != null) {
        amount = amountMatch.group(1)?.trim();
        name = decoded.substring(amountMatch.end).trim();
      }

      // Clean up name
      name = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

      // Classify
      final isSeasoning = seasoningKeywords.any((kw) => lower.contains(kw));
      final isProtein = proteinKeywords.any((kw) => lower.contains(kw));
      final isLiquid = liquidKeywords.any((kw) => lower.contains(kw));

      final rawIngredient = RawIngredient(
        original: decoded,
        amount: amount,
        name: name,
        isSeasoning: isSeasoning && !isProtein && !isLiquid,
        isMainProtein: isProtein,
        isLiquid: isLiquid,
      );
      rawIngredients.add(rawIngredient);

      // Add to seasonings list if classified as seasoning
      if (isSeasoning && !isProtein && !isLiquid) {
        seasonings.add(rawIngredient.toSeasoning());
        seasoningMatches++;
      }
    }

    // Calculate confidence based on how many ingredients we classified
    double confidence = 0.0;
    if (rawIngredients.isNotEmpty) {
      final classifiedCount = rawIngredients
          .where((i) => i.isSeasoning || i.isMainProtein || i.isLiquid)
          .length;
      confidence = classifiedCount / rawIngredients.length;

      // Boost if we found some seasonings
      if (seasoningMatches > 0) {
        confidence = (confidence + 0.3).clamp(0.0, 1.0);
      }
    }

    return {
      'raw': rawIngredients,
      'seasonings': seasonings,
      'confidence': confidence,
    };
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
          var cleaned = _decodeHtml(text);

          // Simplify very long instructions
          if (cleaned.length > 500) {
            final sentences = cleaned.split(RegExp(r'\.\s+'));
            if (sentences.isNotEmpty) {
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

  SmokingImportResult? _parseFromHtml(
      dynamic document, String sourceUrl, bool isKnownSite) {
    final title = document.querySelector('h1')?.text?.trim() ??
        document.querySelector('.recipe-title')?.text?.trim() ??
        document.querySelector('[itemprop="name"]')?.text?.trim() ??
        'Untitled';

    final ingredientElements = document.querySelectorAll(
      '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"]',
    );

    final rawIngredients = <RawIngredient>[];
    final seasonings = <SmokingSeasoning>[];

    for (final el in ingredientElements) {
      final text = _decodeHtml(el.text.trim());
      if (text.isNotEmpty) {
        rawIngredients.add(RawIngredient(
          original: text,
          name: text,
          isSeasoning: true, // Mark all as seasonings in HTML fallback
        ));
        seasonings.add(SmokingSeasoning.create(name: _titleCase(text)));
      }
    }

    final instructionElements = document.querySelectorAll(
      '.instructions li, .directions li, [itemprop="recipeInstructions"] li',
    );

    final directions = instructionElements
        .map((e) => _decodeHtml(e.text.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawIngredients.isEmpty && directions.isEmpty) {
      return null;
    }

    return SmokingImportResult(
      name: _cleanRecipeName(title),
      temperature: null,
      time: null,
      wood: null,
      seasonings: seasonings,
      directions: directions,
      rawIngredients: rawIngredients,
      detectedTemperatures: [],
      detectedWoods: [],
      rawDirections: directions,
      nameConfidence: 0.5,
      temperatureConfidence: 0.0,
      timeConfidence: 0.0,
      woodConfidence: 0.0,
      seasoningsConfidence: 0.3,
      directionsConfidence: directions.isNotEmpty ? 0.5 : 0.0,
      sourceUrl: sourceUrl,
    );
  }

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

/// Provider for SmokingUrlImporter
final smokingUrlImporterProvider = Provider<SmokingUrlImporter>((ref) {
  return SmokingUrlImporter();
});
