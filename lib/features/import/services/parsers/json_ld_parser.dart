import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/ingredient_parser.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/unit_normalizer.dart';
import '../../../recipes/models/recipe.dart';
import 'external_format_parser.dart';

/// Parses JSON-LD Recipe files (schema.org/Recipe format).
///
/// Accepts either a single Recipe object:
/// ```json
/// { "@type": "Recipe", "name": "...", "recipeIngredient": [...], ... }
/// ```
/// or an array of Recipe objects:
/// ```json
/// [{ "@type": "Recipe", ... }, ...]
/// ```
///
/// This parser is not registered in [ExternalRecipeImporter._registry] and
/// is not wired to any file extension.  It is only instantiated directly at
/// the content-sniff site in [RecipeBackupService.importRecipes].
class JsonLdParser implements ExternalFormatParser {
  static const _parserName = 'RecipeSage / JSON-LD';
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    // UTF-8 decode
    String jsonStr;
    try {
      jsonStr = utf8.decode(bytes);
    } catch (e) {
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [ExternalParseFailure(reason: 'Malformed UTF-8 encoding')],
        detectedParserName: _parserName,
      );
    }

    // JSON parse
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException catch (e) {
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(reason: 'Malformed JSON: ${_short(e)}'),
        ],
        detectedParserName: _parserName,
      );
    }

    // Normalise to a list of candidate objects
    final List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = [decoded];
    } else {
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 1,
        failures: [
          ExternalParseFailure(reason: 'Unrecognised JSON-LD structure'),
        ],
        detectedParserName: _parserName,
      );
    }

    final results = <Recipe>[];
    final failures = <ExternalParseFailure>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        failures.add(ExternalParseFailure(reason: 'Expected a JSON object'));
        continue;
      }
      try {
        final recipe = _parseItem(item);
        if (recipe != null) {
          results.add(recipe);
        } else {
          failures.add(ExternalParseFailure(
            reason: 'Missing required field: name',
            rawText: _tryEncode(item),
          ));
        }
      } catch (e) {
        debugPrint('JsonLdParser: parse error — $e');
        final bestName = item['name']?.toString().trim();
        failures.add(ExternalParseFailure(
          name: bestName?.isNotEmpty == true ? bestName : null,
          reason: 'Parse error: ${_short(e)}',
          rawText: _tryEncode(item),
        ));
      }
    }

    return ExternalImportSummary(
      recipes: results,
      skippedCount: failures.length,
      failures: failures,
      detectedParserName: _parserName,
    );
  }

  // ---------------------------------------------------------------------------
  // Field mapping
  // ---------------------------------------------------------------------------

  Recipe? _parseItem(Map<String, dynamic> json) {
    final rawName = json['name']?.toString().trim() ?? '';
    if (rawName.isEmpty) return null;

    // Course — from recipeCategory
    final rawCategory = json['recipeCategory'];
    final categories = <String>[];
    if (rawCategory is String && rawCategory.isNotEmpty) {
      categories.add(rawCategory);
    } else if (rawCategory is List) {
      categories.addAll(rawCategory.whereType<Object>().map((e) => e.toString()));
    }
    final course = detectCourseFromCategories(categories) ?? 'mains';

    // Cuisine
    final rawCuisine = json['recipeCuisine'];
    final cuisine = rawCuisine is String && rawCuisine.isNotEmpty ? rawCuisine : null;

    // Serves — recipeYield may be a string or a list (e.g. ["4", "4 servings"])
    final rawYield = json['recipeYield'];
    final String? serves;
    if (rawYield is String && rawYield.isNotEmpty) {
      serves = rawYield;
    } else if (rawYield is List && rawYield.isNotEmpty) {
      serves = rawYield.first.toString();
    } else {
      serves = null;
    }

    // Time — prefer totalTime, fall back to cookTime, then prepTime
    final time = _parseIsoDuration(
      json['totalTime'] ?? json['cookTime'] ?? json['prepTime'],
    );

    // Comments — from description
    final rawDesc = json['description']?.toString().trim();
    final comments = (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : null;

    // Source URL
    final rawUrl = json['url']?.toString().trim();
    final sourceUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null;

    // Images — image may be a string, ImageObject, or list of either
    final imageUrls = _parseImageUrls(json['image']);

    // Tags — keywords is a comma-separated string or a list
    final tags = _parseKeywords(json['keywords']);

    // Ingredients
    final ingredients = _parseIngredients(json['recipeIngredient']);

    // Directions
    final directions = _parseInstructions(json['recipeInstructions']);

    return Recipe()
      ..uuid = _uuid.v4()
      ..name = TextNormalizer.cleanName(rawName)
      ..course = course
      ..cuisine = cuisine
      ..serves = serves
      ..time = time
      ..comments = comments
      ..sourceUrl = sourceUrl
      ..imageUrls = imageUrls
      ..tags = tags
      ..ingredients = ingredients
      ..directions = directions
      ..source = RecipeSource.imported
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // Ingredient parsing
  // ---------------------------------------------------------------------------

  List<Ingredient> _parseIngredients(dynamic raw) {
    if (raw == null) return [];

    final lines = <String>[];
    if (raw is List) {
      lines.addAll(raw.map((e) => e.toString()));
    } else if (raw is String && raw.isNotEmpty) {
      lines.addAll(raw.split('\n'));
    }

    final results = <Ingredient>[];
    String? currentSection;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parsed = IngredientParser.parse(line);

      if (parsed.isSection) {
        currentSection = parsed.sectionName ?? line.trim();
        continue;
      }
      if (!parsed.looksLikeIngredient && parsed.name.isEmpty) continue;

      final normalizedAmount = parsed.amount != null
          ? TextNormalizer.normalizeFractions(parsed.amount!)
          : null;

      results.add(Ingredient.create(
        name: TextNormalizer.cleanName(parsed.name),
        amount: (normalizedAmount?.isNotEmpty == true) ? normalizedAmount : null,
        unit: UnitNormalizer.normalize(parsed.unit),
        preparation: parsed.preparation,
        section: currentSection,
        alternative: parsed.alternative,
      ));
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Instruction parsing
  // ---------------------------------------------------------------------------

  List<String> _parseInstructions(dynamic raw) {
    if (raw == null) return [];

    // Plain string block — split on line breaks
    if (raw is String) {
      return raw
          .split(RegExp(r'\n+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    if (raw is! List) return [];

    final steps = <String>[];
    _extractStepsFromList(raw, steps);
    return steps;
  }

  void _extractStepsFromList(List<dynamic> list, List<String> out) {
    for (final item in list) {
      if (item is String) {
        final s = item.trim();
        if (s.isNotEmpty) out.add(s);
        continue;
      }
      if (item is! Map<String, dynamic>) continue;

      final type = item['@type']?.toString().toLowerCase();

      if (type == 'howtostep') {
        final text = item['text']?.toString().trim() ?? '';
        if (text.isNotEmpty) out.add(text);
        continue;
      }

      if (type == 'howtosection') {
        // Treat section name as a header step
        final name = item['name']?.toString().trim();
        if (name != null && name.isNotEmpty) out.add(name);
        final subItems = item['itemListElement'];
        if (subItems is List) _extractStepsFromList(subItems, out);
        continue;
      }

      // Fallback: try 'text' field for unknown types
      final text = item['text']?.toString().trim() ?? '';
      if (text.isNotEmpty) out.add(text);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _parseImageUrls(dynamic raw) {
    if (raw == null) return [];

    String? urlFromObject(dynamic obj) {
      if (obj is String && obj.isNotEmpty) return obj;
      if (obj is Map<String, dynamic>) {
        final u = obj['url']?.toString().trim();
        if (u != null && u.isNotEmpty) return u;
        final contentUrl = obj['contentUrl']?.toString().trim();
        if (contentUrl != null && contentUrl.isNotEmpty) return contentUrl;
      }
      return null;
    }

    if (raw is List) {
      return raw
          .map(urlFromObject)
          .whereType<String>()
          .toList();
    }
    final url = urlFromObject(raw);
    return url != null ? [url] : [];
  }

  List<String> _parseKeywords(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      return raw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    if (raw is List) {
      return raw
          .map((t) => t.toString().trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Converts an ISO 8601 duration string (e.g. "PT1H30M", "PT45M") to a
  /// human-readable time string like "1 hr 30 min" or "45 min".
  /// Returns null for empty, zero-length, or unrecognised values.
  String? _parseIsoDuration(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim().toUpperCase();
    if (str.isEmpty) return null;

    // Only attempt ISO 8601 parsing for durations starting with P
    if (!str.startsWith('P')) return str;

    final hours = _durationPart(str, 'H');
    final minutes = _durationPart(str, 'M');
    if (hours == 0 && minutes == 0) return null;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  int _durationPart(String s, String unit) {
    final match = RegExp('(\\d+)$unit').firstMatch(s);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  String _short(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  String? _tryEncode(dynamic obj) {
    try {
      return jsonEncode(obj);
    } catch (_) {
      return null;
    }
  }
}
