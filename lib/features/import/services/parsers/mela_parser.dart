import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart' hide Recipe, Ingredient, Course;
import '../../../../core/utils/ingredient_parser.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/unit_normalizer.dart';
import '../../../recipes/models/recipe.dart';
import 'external_format_parser.dart';

/// Parses `.melarecipes` and `.melarecipe` files produced by the Mela app.
///
/// Outer container is a zip archive.  Each entry that ends with `.melarecipe`
/// is a UTF-8–encoded JSON object.  There is no intermediate gzip step.
class MelaParser implements ExternalFormatParser {
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('MelaParser: failed to decode zip — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(
            reason: 'Corrupt archive: ${_shortMessage(e)}',
          ),
        ],
      );
    }

    final results = <Recipe>[];
    final failures = <ExternalParseFailure>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (!entry.name.toLowerCase().endsWith('.melarecipe')) continue;

      // Phase 1: decode bytes to UTF-8 string
      String? jsonStr;
      try {
        jsonStr = utf8.decode(entry.content as List<int>);
      } on FormatException catch (e) {
        debugPrint('MelaParser: UTF-8 decode failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Malformed UTF-8 encoding',
        ));
        continue;
      } catch (e) {
        debugPrint('MelaParser: decode error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Corrupt archive entry: ${_shortMessage(e)}',
        ));
        continue;
      }

      // Phase 2: JSON parse
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(jsonStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        debugPrint('MelaParser: JSON parse failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Malformed JSON: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      } catch (e) {
        debugPrint('MelaParser: JSON error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'JSON parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      }

      // Phase 3: field mapping — graceful degradation; only fails if no title
      try {
        final recipe = await _parseEntry(json);
        if (recipe != null) {
          results.add(recipe);
        } else {
          // No usable title — add to failures
          final bestEffortName = json['title']?.toString().trim();
          failures.add(ExternalParseFailure(
            name: bestEffortName?.isNotEmpty == true ? bestEffortName : _entryBaseName(entry.name),
            reason: 'Missing required fields (title)',
            rawText: jsonStr,
          ));
        }
      } catch (e) {
        debugPrint('MelaParser: field mapping failed for "${entry.name}" — $e');
        final bestEffortName = json['title']?.toString().trim();
        failures.add(ExternalParseFailure(
          name: bestEffortName?.isNotEmpty == true ? bestEffortName : _entryBaseName(entry.name),
          reason: 'Parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
      }
    }

    return ExternalImportSummary(
      recipes: results,
      skippedCount: failures.length,
      failures: failures,
    );
  }

  Future<Recipe?> _parseEntry(Map<String, dynamic> json) async {
    final rawTitle = json['title']?.toString() ?? '';
    if (rawTitle.trim().isEmpty) return null;

    // Categories → course detection + tags
    final categories = _toStringList(json['categories']);
    final suggestedCourse =
        detectCourseFromCategories(categories) ?? 'mains';

    // Description ("text") + notes — concatenate when both present
    final text = json['text']?.toString().trim() ?? '';
    final notes = json['notes']?.toString().trim() ?? '';
    final comments =
        [text, notes].where((s) => s.isNotEmpty).join('\n\n');

    // Ingredients — split on newline, then parse each line
    final ingredients =
        _parseIngredientLines(_splitLines(json['ingredients']?.toString()));

    // Directions — split on newline, keep non-empty
    final directions = _splitLines(json['instructions']?.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    // Time — prefer totalTime over cookTime; prepTime is dropped
    final totalTimeRaw = json['totalTime']?.toString();
    final cookTimeRaw = json['cookTime']?.toString();
    final timeInput =
        (totalTimeRaw?.isNotEmpty == true) ? totalTimeRaw : cookTimeRaw;
    final time = UnitNormalizer.normalizeTime(timeInput);

    // Servings
    final servesRaw = UnitNormalizer.normalizeServes(json['yield']?.toString());
    final serves =
        (servesRaw != null && servesRaw.isNotEmpty) ? servesRaw : null;

    // Source URL
    final sourceUrl = json['link']?.toString().trim();
    final resolvedSourceUrl =
        (sourceUrl != null && sourceUrl.isNotEmpty) ? sourceUrl : null;

    // Source: url if a valid http(s) link is present, otherwise personal
    final source = (resolvedSourceUrl != null &&
            (resolvedSourceUrl.startsWith('http://') ||
                resolvedSourceUrl.startsWith('https://')))
        ? RecipeSource.url
        : RecipeSource.personal;

    // Images — base64 strings → temp files
    final imageList = _toStringList(json['images']);
    final imagePaths = await _writeBase64Images(imageList);

    // Nutrition — only parsed when the value is already a structured Map
    NutritionInfo? nutrition;
    final rawNutrition = json['nutrition'];
    if (rawNutrition is Map<String, dynamic>) {
      try {
        nutrition = NutritionInfo.fromJson(rawNutrition);
      } catch (_) {
        // Silently drop malformed nutrition data
      }
    }

    final recipe = Recipe.create(
      uuid: _uuid.v4(),
      name: TextNormalizer.cleanName(rawTitle),
      course: suggestedCourse,
      serves: serves,
      time: (time != null && time.isNotEmpty) ? time : null,
      comments: comments.isNotEmpty ? comments : null,
      ingredients: ingredients,
      directions: directions,
      tags: categories,
      sourceUrl: resolvedSourceUrl,
      source: source,
      isFavourite: json['favorite'] as bool? ?? false,
      nutrition: nutrition,
    );

    if (imagePaths.isNotEmpty) {
      recipe.headerImage = imagePaths.first;
      if (imagePaths.length > 1) {
        recipe.stepImages = imagePaths.sublist(1);
      }
    }

    return recipe;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<String> _splitLines(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return [];
  }

  List<Ingredient> _parseIngredientLines(List<String> lines) {
    final results = <Ingredient>[];
    String? currentSection;

    for (final line in lines) {
      if (line.isEmpty) continue;
      final parsed = IngredientParser.parse(line);

      if (parsed.isSection) {
        currentSection = parsed.sectionName ?? line;
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
        bakerPercent: parsed.bakerPercent,
        alternative: parsed.alternative,
      ));
    }

    return results;
  }

  /// Strips the directory path and extension from an archive entry filename.
  String _entryBaseName(String entryName) {
    final base = entryName.split('/').last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  /// Returns a short (≤120 char) version of an exception message.
  String _shortMessage(Object e) {
    final msg = e.toString();
    return msg.length > 120 ? '${msg.substring(0, 117)}…' : msg;
  }

  /// Decodes base64 image strings to temporary files.
  ///
  /// [_saveImageBlobs] in [RecipeRepository] reads these absolute paths and
  /// persists the bytes to the blob store during [saveRecipe].  Using
  /// [getTemporaryDirectory] is safe — the files are read synchronously
  /// during the same [saveRecipe] call.
  Future<List<String>> _writeBase64Images(List<String> base64Strings) async {
    if (base64Strings.isEmpty) return [];
    final tmpDir = await getTemporaryDirectory();
    final paths = <String>[];

    for (final b64 in base64Strings) {
      if (b64.isEmpty) continue;
      try {
        final bytes = base64Decode(b64);
        final fileName = '${_uuid.v4()}.jpg';
        final file = File('${tmpDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        paths.add(file.path);
      } catch (e) {
        debugPrint('MelaParser: failed to write image — $e');
        // Silently skip images that cannot be decoded or written
      }
    }

    return paths;
  }
}
