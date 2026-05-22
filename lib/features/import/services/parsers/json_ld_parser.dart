import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/ingredient_parser.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/unit_normalizer.dart';
import '../../../recipes/models/recipe.dart';
import '../../models/recipe_import_result.dart';
import 'external_format_parser.dart';

/// Parses schema.org/Recipe JSON-LD files (e.g. RecipeSage exports).
///
/// Accepts either a single Recipe object or an array of Recipe objects.
/// Not registered in [ExternalRecipeImporter._registry]; instantiated
/// directly at the content-sniff site in [RecipeBackupService.importRecipes].
class JsonLdParser implements ExternalFormatParser {
  static const _parserName = 'RecipeSage / JSON-LD';
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    // Phase 1: UTF-8 decode
    String jsonStr;
    try {
      jsonStr = utf8.decode(bytes);
    } on FormatException catch (e) {
      debugPrint('JsonLdParser: UTF-8 decode failed — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 1,
        failures: [ExternalParseFailure(reason: 'Malformed UTF-8 encoding')],
        detectedParserName: _parserName,
      );
    } catch (e) {
      debugPrint('JsonLdParser: decode error — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 1,
        failures: [ExternalParseFailure(reason: 'Decode error: ${_short(e)}')],
        detectedParserName: _parserName,
      );
    }

    // Phase 2: JSON parse
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException catch (e) {
      debugPrint('JsonLdParser: JSON parse failed — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 1,
        failures: [
          ExternalParseFailure(reason: 'Malformed JSON: ${_short(e)}'),
        ],
        detectedParserName: _parserName,
      );
    } catch (e) {
      debugPrint('JsonLdParser: JSON error — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 1,
        failures: [
          ExternalParseFailure(reason: 'JSON parse error: ${_short(e)}'),
        ],
        detectedParserName: _parserName,
      );
    }

    // Normalize top-level value to a list
    final List<dynamic> items;
    if (decoded is Map<String, dynamic>) {
      items = [decoded];
    } else if (decoded is List) {
      items = decoded;
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

    // Phase 3: per-entry field mapping
    for (final item in items) {
      // Recipe count cap
      if (results.length + failures.length >= ExternalFormatParser.maxRecipesPerFile) {
        failures.add(ExternalParseFailure(
          reason: 'Import limit reached — maximum ${ExternalFormatParser.maxRecipesPerFile} recipes per file',
        ));
        break;
      }
      if (item is! Map<String, dynamic>) {
        failures.add(ExternalParseFailure(
          reason: 'Expected a JSON object, got ${item.runtimeType}',
        ));
        continue;
      }

      String? rawJson;
      try {
        rawJson = jsonEncode(item);
      } catch (_) {}

      try {
        final recipe = _parseEntry(item);
        if (recipe != null) {
          results.add(recipe);
        } else {
          failures.add(ExternalParseFailure(
            reason: 'Missing required field: name',
            rawText: rawJson,
            partialResult: rawJson != null
                ? _buildPartialResult(item, rawJson!)
                : null,
          ));
        }
      } catch (e) {
        debugPrint('JsonLdParser: field mapping failed — $e');
        final bestName = item['name']?.toString().trim();
        failures.add(ExternalParseFailure(
          name: (bestName != null && bestName.isNotEmpty) ? bestName : null,
          reason: 'Parse error: ${_short(e)}',
          rawText: rawJson,
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
  // Entry mapping
  // ---------------------------------------------------------------------------

  Recipe? _parseEntry(Map<String, dynamic> json) {
    // name — required
    final rawName = json['name']?.toString().trim() ?? '';
    if (rawName.isEmpty) return null;

    // description
    final rawDesc = json['description']?.toString().trim();
    final comments = (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : null;

    // recipeIngredient
    final ingredients = _parseIngredients(json['recipeIngredient']);

    // recipeInstructions
    final directions = _parseInstructions(json['recipeInstructions']);

    // time — totalTime → cookTime → prepTime
    final time = _parseDuration(
      json['totalTime']?.toString() ??
          json['cookTime']?.toString() ??
          json['prepTime']?.toString(),
    );

    // recipeYield → extract leading integer
    final serves = _parseYield(json['recipeYield']);

    // recipeCategory + keywords → combined for course detection
    final combined = [
      ..._normalizeStringList(json['recipeCategory']),
      ..._normalizeStringList(json['keywords']),
    ];
    final course = detectCourseFromCategories(combined) ?? 'mains';

    // aggregateRating.ratingValue → clamp 0–5, round to int
    int rating = 0;
    final aggRating = json['aggregateRating'];
    if (aggRating is Map<String, dynamic>) {
      final rv = aggRating['ratingValue'];
      if (rv != null) {
        final d = double.tryParse(rv.toString());
        if (d != null) rating = d.clamp(0.0, 5.0).round();
      }
    }

    // url / mainEntityOfPage → sourceUrl + source
    String? sourceUrl;
    final rawUrl = json['url']?.toString().trim();
    if (rawUrl != null &&
        rawUrl.isNotEmpty &&
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
      sourceUrl = rawUrl;
    } else {
      // Fall back to mainEntityOfPage (may be a string or {"@id": "..."})
      final mep = json['mainEntityOfPage'];
      String? mepUrl;
      if (mep is String) {
        mepUrl = mep.trim();
      } else if (mep is Map<String, dynamic>) {
        mepUrl = mep['@id']?.toString().trim();
      }
      if (mepUrl != null &&
          mepUrl.isNotEmpty &&
          (mepUrl.startsWith('http://') || mepUrl.startsWith('https://'))) {
        sourceUrl = mepUrl;
      }
    }
    final source =
        (sourceUrl != null) ? RecipeSource.url : RecipeSource.personal;

    // image — extract first URL; used as sourceUrl fallback only (not downloaded)
    if (sourceUrl == null) {
      sourceUrl = _firstImageUrl(json['image']);
    }

    return Recipe()
      ..uuid = _uuid.v4()
      ..name = TextNormalizer.cleanName(rawName)
      ..course = course
      ..comments = comments
      ..ingredients = ingredients
      ..directions = directions
      ..time = time
      ..serves = serves
      ..rating = rating
      ..sourceUrl = sourceUrl
      ..source = source
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // recipeIngredient
  // ---------------------------------------------------------------------------

  List<Ingredient> _parseIngredients(dynamic raw) {
    if (raw == null) return [];

    final lines = <String>[];
    if (raw is List) {
      lines.addAll(raw.take(ExternalFormatParser.maxInnerListItems).map((e) => e.toString()));
    } else if (raw is String && raw.isNotEmpty) {
      lines.addAll(
        raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
      );
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
  // recipeInstructions
  // ---------------------------------------------------------------------------

  List<String> _parseInstructions(dynamic raw) {
    if (raw == null) return [];

    // Plain string at top level → single direction
    if (raw is String) {
      final s = raw.trim();
      return s.isNotEmpty ? [s] : [];
    }

    if (raw is! List) return [];

    final out = <String>[];
    final castRaw = raw as List<dynamic>;
    _collectSteps(
      castRaw.length > ExternalFormatParser.maxInnerListItems
          ? castRaw.sublist(0, ExternalFormatParser.maxInnerListItems)
          : castRaw,
      out,
    );
    return out;
  }

  void _collectSteps(List<dynamic> list, List<String> out) {
    for (final item in list) {
      // Plain string element
      if (item is String) {
        final s = item.trim();
        if (s.isNotEmpty) out.add(s);
        continue;
      }

      if (item is! Map<String, dynamic>) continue;

      final type = item['@type']?.toString().toLowerCase();

      if (type == 'howtostep') {
        final name = item['name']?.toString().trim() ?? '';
        final text = item['text']?.toString().trim() ?? '';
        if (name.isNotEmpty && text.isNotEmpty) {
          out.add('**$name**\n$text');
        } else if (text.isNotEmpty) {
          out.add(text);
        } else if (name.isNotEmpty) {
          out.add(name);
        }
        continue;
      }

      if (type == 'howtosection') {
        final sectionName = item['name']?.toString().trim() ?? '';
        if (sectionName.isNotEmpty) out.add('**$sectionName**');
        final subItems = item['itemListElement'];
        if (subItems is List) _collectSteps(subItems, out);
        continue;
      }

      // Unknown type — try 'text' field
      final text = item['text']?.toString().trim() ?? '';
      if (text.isNotEmpty) out.add(text);
    }
  }

  // ---------------------------------------------------------------------------
  // recipeYield
  // ---------------------------------------------------------------------------

  String? _parseYield(dynamic raw) {
    if (raw == null) return null;
    final s = (raw is List && raw.isNotEmpty)
        ? raw.first.toString().trim()
        : raw.toString().trim();
    if (s.isEmpty) return null;
    final match = RegExp(r'^\d+').firstMatch(s);
    if (match == null) return null;
    final result = UnitNormalizer.normalizeServes(match.group(0));
    return result.isEmpty ? null : result;
  }

  // ---------------------------------------------------------------------------
  // recipeCategory / keywords normalization
  // ---------------------------------------------------------------------------

  /// Normalizes a field that may be a plain string (optionally comma-separated),
  /// an array of strings, or null into a flat [List<String>].
  List<String> _normalizeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      final result = <String>[];
      for (final item in raw) {
        final s = item.toString().trim();
        if (s.isEmpty) continue;
        result.addAll(
          s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty),
        );
      }
      return result;
    }
    if (raw is String && raw.isNotEmpty) {
      return raw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // image
  // ---------------------------------------------------------------------------

  String? _firstImageUrl(dynamic raw) {
    if (raw == null) return null;
    String? extract(dynamic obj) {
      if (obj is String && obj.isNotEmpty) return obj;
      if (obj is Map<String, dynamic>) {
        final u = obj['url']?.toString().trim();
        if (u != null && u.isNotEmpty) return u;
        final cu = obj['contentUrl']?.toString().trim();
        if (cu != null && cu.isNotEmpty) return cu;
      }
      return null;
    }
    if (raw is List) {
      for (final item in raw) {
        final u = extract(item);
        if (u != null) return u;
      }
      return null;
    }
    return extract(raw);
  }

  // ---------------------------------------------------------------------------
  // Partial result (for empty-name failures)
  // ---------------------------------------------------------------------------

  RecipeImportResult? _buildPartialResult(
    Map<String, dynamic> item,
    String rawJson,
  ) {
    try {
      // Course
      final combined = [
        ..._normalizeStringList(item['recipeCategory']),
        ..._normalizeStringList(item['keywords']),
      ];
      final detectedCourse = detectCourseFromCategories(combined);
      final course = detectedCourse ?? 'mains';

      // Description
      final rawDesc = item['description']?.toString().trim();
      final comments =
          (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : null;

      // rawIngredients
      final rawIngredients = <RawIngredientData>[];
      final ingredientRaw = item['recipeIngredient'];
      final ingredientLines = <String>[];
      if (ingredientRaw is List) {
        ingredientLines.addAll(ingredientRaw.map((e) => e.toString()));
      } else if (ingredientRaw is String && ingredientRaw.isNotEmpty) {
        ingredientLines.addAll(
          ingredientRaw
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty),
        );
      }
      String? currentSection;
      for (final line in ingredientLines) {
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
        rawIngredients.add(RawIngredientData(
          original: line,
          name: TextNormalizer.cleanName(parsed.name),
          amount:
              (normalizedAmount?.isNotEmpty == true) ? normalizedAmount : null,
          unit: UnitNormalizer.normalize(parsed.unit),
          preparation: parsed.preparation,
          alternative: parsed.alternative,
          sectionName: currentSection,
        ));
      }

      // rawDirections
      final rawDirections = <String>[];
      _collectSteps(
        item['recipeInstructions'] is List
            ? item['recipeInstructions'] as List
            : [],
        rawDirections,
      );
      // top-level plain string fallback
      if (rawDirections.isEmpty &&
          item['recipeInstructions'] is String &&
          (item['recipeInstructions'] as String).trim().isNotEmpty) {
        rawDirections.add((item['recipeInstructions'] as String).trim());
      }

      // Time
      final time = _parseDuration(
        item['totalTime']?.toString() ??
            item['cookTime']?.toString() ??
            item['prepTime']?.toString(),
      );

      // Serves
      final serves = _parseYield(item['recipeYield']);

      // Source
      String? sourceUrl;
      final rawUrl = item['url']?.toString().trim();
      if (rawUrl != null &&
          rawUrl.isNotEmpty &&
          (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
        sourceUrl = rawUrl;
      } else {
        final mep = item['mainEntityOfPage'];
        String? mepUrl;
        if (mep is String) {
          mepUrl = mep.trim();
        } else if (mep is Map<String, dynamic>) {
          mepUrl = mep['@id']?.toString().trim();
        }
        if (mepUrl != null &&
            mepUrl.isNotEmpty &&
            (mepUrl.startsWith('http://') ||
                mepUrl.startsWith('https://'))) {
          sourceUrl = mepUrl;
        }
      }
      final source =
          (sourceUrl != null) ? RecipeSource.url : RecipeSource.personal;

      return RecipeImportResult(
        course: course,
        comments: comments,
        rawIngredients: rawIngredients,
        rawDirections: rawDirections,
        serves: serves,
        time: time,
        sourceUrl: sourceUrl,
        source: source,
        rawText: rawJson,
        detectedCourses: [course],
        nameConfidence: 0.0,
        courseConfidence: detectedCourse != null ? 0.7 : 0.3,
        ingredientsConfidence: rawIngredients.isNotEmpty ? 0.9 : 0.0,
        directionsConfidence: rawDirections.isNotEmpty ? 0.8 : 0.0,
      );
    } catch (e, st) {
      debugPrint('JsonLdParser._buildPartialResult error — $e\n$st');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ISO 8601 duration — identical to MealieParser._parseDuration
  // ---------------------------------------------------------------------------

  String? _parseDuration(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final trimmed = raw.trim();

    // ISO 8601: P[nD]T[nH][nM][nS]
    final iso = RegExp(
      r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (iso != null) {
      final days = int.tryParse(iso.group(1) ?? '') ?? 0;
      final hours = int.tryParse(iso.group(2) ?? '') ?? 0;
      final minutes = int.tryParse(iso.group(3) ?? '') ?? 0;
      // Seconds ignored for cooking purposes
      final totalMinutes = days * 1440 + hours * 60 + minutes;
      if (totalMinutes == 0) return null;
      if (totalMinutes < 60) return '$totalMinutes min';
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}min';
    }

    // Fall back to UnitNormalizer for human-readable strings
    return UnitNormalizer.normalizeTime(trimmed);
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  String _short(Object e) {
    final msg = e.toString();
    return msg.length > 120 ? '${msg.substring(0, 117)}…' : msg;
  }
}
