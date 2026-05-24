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
import '../../models/recipe_import_result.dart';
import 'external_format_parser.dart';

/// Parses Tandoor Recipes export archives.
///
/// Archive structure:
/// ```
/// recipes/{name}/recipe.json
/// recipes/{name}/full.jpg       ← preferred image
/// recipes/{name}/{other}.jpg    ← fallback if full.jpg absent
/// ```
///
/// Only files named exactly `recipe.json` are processed.
class TandoorParser implements ExternalFormatParser {
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('TandoorParser: failed to decode zip — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(
            reason: 'Corrupt archive: ${_shortMessage(e)}',
          ),
        ],
        detectedParserName: 'Tandoor',
      );
    }

    // Zip bomb / resource exhaustion guard
    if (archive.files.length > ExternalFormatParser.maxEntries) {
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [ExternalParseFailure(reason: 'Archive contains too many entries')],
        detectedParserName: 'Tandoor',
      );
    }
    var totalInflatedBytes = 0;
    for (final f in archive.files) {
      if (f.size > ExternalFormatParser.maxInflatedBytes) {
        return ExternalImportSummary(
          recipes: [],
          skippedCount: 0,
          failures: [ExternalParseFailure(reason: 'Archive entry too large to process safely')],
          detectedParserName: 'Tandoor',
        );
      }
      totalInflatedBytes += f.size;
      if (totalInflatedBytes > ExternalFormatParser.maxInflatedBytes) {
        return ExternalImportSummary(
          recipes: [],
          skippedCount: 0,
          failures: [ExternalParseFailure(reason: 'Archive entry too large to process safely')],
          detectedParserName: 'Tandoor',
        );
      }
    }

    final Map<String, ArchiveFile> entryByPath = {
      for (final e in archive) if (e.isFile) e.name: e,
    };

    // Collect only entries named exactly "recipe.json" under "recipes/{name}/"
    final recipeEntries = <ArchiveFile>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final parts = entry.name.split('/');
      // "recipes/{name}/recipe.json" → 3 segments, last is "recipe.json"
      if (parts.length == 3 &&
          parts[0].toLowerCase() == 'recipes' &&
          parts[2] == 'recipe.json') {
        recipeEntries.add(entry);
      }
    }

    final results = <Recipe>[];
    final failures = <ExternalParseFailure>[];

    for (final entry in recipeEntries) {
      // Recipe count cap
      if (results.length + failures.length >= ExternalFormatParser.maxRecipesPerFile) {
        failures.add(ExternalParseFailure(
          reason: 'Import limit reached — maximum ${ExternalFormatParser.maxRecipesPerFile} recipes per file',
        ));
        break;
      }

      final parts = entry.name.split('/');
      final folderName = parts[1]; // "recipes/{name}/recipe.json"
      final subfolderPrefix = 'recipes/$folderName/';

      // Phase 1: UTF-8 decode
      String? jsonStr;
      try {
        jsonStr = utf8.decode(entry.content as List<int>);
      } on FormatException catch (e) {
        debugPrint('TandoorParser: UTF-8 decode failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: folderName,
          reason: 'Malformed UTF-8 encoding',
        ));
        continue;
      } catch (e) {
        debugPrint('TandoorParser: decode error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: folderName,
          reason: 'Corrupt archive entry: ${_shortMessage(e)}',
        ));
        continue;
      }

      // Phase 2: JSON parse
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(jsonStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        debugPrint('TandoorParser: JSON parse failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: folderName,
          reason: 'Malformed JSON: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      } catch (e) {
        debugPrint('TandoorParser: JSON error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: folderName,
          reason: 'JSON parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      }

      // Phase 3: field mapping
      try {
        final recipe = await _parseEntry(
          json,
          entryByPath: entryByPath,
          subfolderPrefix: subfolderPrefix,
          folderName: folderName,
        );
        if (recipe != null) {
          results.add(recipe);
        } else {
          // Fully parsed but name is empty — attach partial result for the Fix path.
          failures.add(ExternalParseFailure(
            name: null,
            reason: 'Missing required fields (name)',
            rawText: jsonStr,
            partialResult: _buildPartialResult(json, jsonStr),
          ));
        }
      } catch (e) {
        debugPrint('TandoorParser: field mapping failed for "${entry.name}" — $e');
        final bestEffortName = json['name']?.toString().trim();
        failures.add(ExternalParseFailure(
          name: bestEffortName?.isNotEmpty == true ? bestEffortName : folderName,
          reason: 'Parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
      }
    }

    return ExternalImportSummary(
      recipes: results,
      skippedCount: failures.length,
      failures: failures,
      detectedParserName: 'Tandoor',
    );
  }

  Future<Recipe?> _parseEntry(
    Map<String, dynamic> json, {
    required Map<String, ArchiveFile> entryByPath,
    required String subfolderPrefix,
    required String folderName,
  }) async {
    final rawName = json['name']?.toString() ?? '';
    if (rawName.trim().isEmpty) return null;

    // -------------------------------------------------------------------------
    // Description
    // -------------------------------------------------------------------------
    final description = json['description']?.toString().trim();
    final comments =
        (description != null && description.isNotEmpty) ? description : null;

    // -------------------------------------------------------------------------
    // Ingredients — from steps[].ingredients[]
    // -------------------------------------------------------------------------
    final ingredients = <Ingredient>[];
    final stepList = json['steps'];
    if (stepList is List) {
      for (final step in stepList.take(ExternalFormatParser.maxInnerListItems)) {
        if (step is! Map<String, dynamic>) continue;
        final stepIngredients = step['ingredients'];
        if (stepIngredients is! List) continue;

        for (final item in stepIngredients.take(ExternalFormatParser.maxInnerListItems)) {
          if (item is! Map<String, dynamic>) continue;

          final amount = item['amount']?.toString().trim();
          final unit = (item['unit'] as Map<String, dynamic>?)?['name']
              ?.toString()
              .trim();
          final food = (item['food'] as Map<String, dynamic>?)?['name']
              ?.toString()
              .trim();
          final note = item['note']?.toString().trim();

          // Build raw ingredient string
          final parts = <String>[
            if (amount != null && amount.isNotEmpty && amount != '0') amount,
            if (unit != null && unit.isNotEmpty) unit,
            if (food != null && food.isNotEmpty) food,
          ];
          if (parts.isEmpty) continue;

          var rawLine = parts.join(' ');
          if (note != null && note.isNotEmpty) {
            rawLine = '$rawLine, $note';
          }

          final parsed = IngredientParser.parse(rawLine);
          if (!parsed.looksLikeIngredient && parsed.name.isEmpty) continue;

          final normalizedAmount = parsed.amount != null
              ? TextNormalizer.normalizeFractions(parsed.amount!)
              : null;

          ingredients.add(Ingredient.create(
            name: TextNormalizer.cleanName(parsed.name),
            amount: (normalizedAmount?.isNotEmpty == true)
                ? normalizedAmount
                : null,
            unit: UnitNormalizer.normalize(parsed.unit),
            preparation: parsed.preparation,
            bakerPercent: parsed.bakerPercent,
            alternative: parsed.alternative,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // Directions — from steps[].instruction (+ steps[].name as title)
    // -------------------------------------------------------------------------
    final directions = <String>[];
    if (stepList is List) {
      for (final step in stepList.take(ExternalFormatParser.maxInnerListItems)) {
        if (step is! Map<String, dynamic>) continue;
        final stepName = step['name']?.toString().trim() ?? '';
        final instruction = step['instruction']?.toString().trim() ?? '';
        if (stepName.isNotEmpty && instruction.isNotEmpty) {
          directions.add('**$stepName**\n$instruction');
        } else if (instruction.isNotEmpty) {
          directions.add(instruction);
        } else if (stepName.isNotEmpty) {
          directions.add(stepName);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Time — working_time and waiting_time are integer minutes
    // -------------------------------------------------------------------------
    final workingTime = json['working_time'] as int? ?? 0;
    final waitingTime = json['waiting_time'] as int? ?? 0;
    final totalMinutes = workingTime + waitingTime;
    String? time;
    if (totalMinutes > 0) {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      if (h > 0 && m > 0) {
        time = '${h}h ${m}min';
      } else if (h > 0) {
        time = '${h}h';
      } else {
        time = '${m}min';
      }
    }

    // -------------------------------------------------------------------------
    // Servings
    // -------------------------------------------------------------------------
    final rawServings = json['servings'];
    String? serves;
    if (rawServings != null) {
      serves = UnitNormalizer.normalizeServes(rawServings.toString());
      if (serves?.isEmpty == true) serves = null;
    }

    // -------------------------------------------------------------------------
    // Keywords → course detection
    // -------------------------------------------------------------------------
    final categories = <String>[];
    final keywordList = json['keywords'];
    if (keywordList is List) {
      for (final kw in keywordList) {
        final name = kw is Map<String, dynamic>
            ? kw['name']?.toString().trim()
            : kw?.toString().trim();
        if (name != null && name.isNotEmpty) categories.add(name);
      }
    }
    final suggestedCourse = detectCourseFromCategories(categories) ?? 'mains';

    // -------------------------------------------------------------------------
    // Source URL
    // -------------------------------------------------------------------------
    var sourceUrl = json['source_url']?.toString().trim();
    if (sourceUrl?.isEmpty == true) sourceUrl = null;
    final source = (sourceUrl != null &&
            (sourceUrl.startsWith('http://') ||
                sourceUrl.startsWith('https://')))
        ? RecipeSource.url
        : RecipeSource.personal;
    if (source == RecipeSource.personal) sourceUrl = null;

    // -------------------------------------------------------------------------
    // Image — prefer full.jpg, fallback to any image in subfolder
    // -------------------------------------------------------------------------
    String? headerImage;
    try {
      ArchiveFile? imageEntry =
          entryByPath['${subfolderPrefix}full.jpg'];

      if (imageEntry == null) {
        // Fallback: any image in the subfolder
        imageEntry = entryByPath.entries
            .where((e) =>
                e.key.startsWith(subfolderPrefix) &&
                _isImageExtension(e.key))
            .map((e) => e.value)
            .firstOrNull;
      }

      if (imageEntry != null) {
        headerImage = await _writeImageBytes(
          imageEntry.content as List<int>,
          _extensionOf(imageEntry.name),
        );
      }
    } catch (e) {
      debugPrint('TandoorParser: failed to write image for "$folderName" — $e');
      // Non-fatal
    }

    // -------------------------------------------------------------------------
    // Assemble recipe
    // -------------------------------------------------------------------------
    final recipe = Recipe.create(
      uuid: _uuid.v4(),
      name: TextNormalizer.cleanName(rawName),
      course: suggestedCourse,
      serves: serves,
      time: time,
      comments: comments,
      ingredients: ingredients,
      directions: directions,
      tags: categories,
      sourceUrl: sourceUrl,
      source: source,
    );

    if (headerImage != null) {
      recipe.headerImage = headerImage;
    }

    return recipe;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Builds a [RecipeImportResult] from a fully-decoded JSON map for use as
  /// [ExternalParseFailure.partialResult].  Called only when the name field
  /// is empty; image handling is skipped since the recipe is not being saved.
  RecipeImportResult? _buildPartialResult(
    Map<String, dynamic> json,
    String jsonStr,
  ) {
    try {
      // Description
      final description = json['description']?.toString().trim();
      final comments =
          (description != null && description.isNotEmpty) ? description : null;

      // Ingredients and directions from steps
      final rawIngredients = <RawIngredientData>[];
      final rawDirections = <String>[];
      final stepList = json['steps'];
      if (stepList is List) {
        for (final step in stepList) {
          if (step is! Map<String, dynamic>) continue;

          // Directions
          final stepName = step['name']?.toString().trim() ?? '';
          final instruction = step['instruction']?.toString().trim() ?? '';
          if (stepName.isNotEmpty && instruction.isNotEmpty) {
            rawDirections.add('**$stepName**\n$instruction');
          } else if (instruction.isNotEmpty) {
            rawDirections.add(instruction);
          } else if (stepName.isNotEmpty) {
            rawDirections.add(stepName);
          }

          // Ingredients
          final stepIngredients = step['ingredients'];
          if (stepIngredients is! List) continue;
          for (final item in stepIngredients) {
            if (item is! Map<String, dynamic>) continue;
            final amount = item['amount']?.toString().trim();
            final unit = (item['unit'] as Map<String, dynamic>?)?['name']
                ?.toString()
                .trim();
            final food = (item['food'] as Map<String, dynamic>?)?['name']
                ?.toString()
                .trim();
            final note = item['note']?.toString().trim();
            final parts = <String>[
              if (amount != null && amount.isNotEmpty && amount != '0') amount,
              if (unit != null && unit.isNotEmpty) unit,
              if (food != null && food.isNotEmpty) food,
            ];
            if (parts.isEmpty) continue;
            var rawLine = parts.join(' ');
            if (note != null && note.isNotEmpty) rawLine = '$rawLine, $note';
            final parsed = IngredientParser.parse(rawLine);
            if (!parsed.looksLikeIngredient && parsed.name.isEmpty) continue;
            final normalizedAmount = parsed.amount != null
                ? TextNormalizer.normalizeFractions(parsed.amount!)
                : null;
            rawIngredients.add(RawIngredientData(
              original: rawLine,
              amount: (normalizedAmount?.isNotEmpty == true)
                  ? normalizedAmount
                  : null,
              unit: UnitNormalizer.normalize(parsed.unit),
              preparation: parsed.preparation,
              bakerPercent: parsed.bakerPercent,
              alternative: parsed.alternative,
              name: TextNormalizer.cleanName(parsed.name),
              looksLikeIngredient: parsed.looksLikeIngredient,
            ));
          }
        }
      }

      // Time
      final workingTime = json['working_time'] as int? ?? 0;
      final waitingTime = json['waiting_time'] as int? ?? 0;
      final totalMinutes = workingTime + waitingTime;
      String? time;
      if (totalMinutes > 0) {
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        if (h > 0 && m > 0) {
          time = '${h}h ${m}min';
        } else if (h > 0) {
          time = '${h}h';
        } else {
          time = '${m}min';
        }
      }

      // Serves
      final rawServings = json['servings'];
      String? serves;
      if (rawServings != null) {
        serves = UnitNormalizer.normalizeServes(rawServings.toString());
        if (serves?.isEmpty == true) serves = null;
      }

      // Course
      final categories = <String>[];
      final keywordList = json['keywords'];
      if (keywordList is List) {
        for (final kw in keywordList) {
          final name = kw is Map<String, dynamic>
              ? kw['name']?.toString().trim()
              : kw?.toString().trim();
          if (name != null && name.isNotEmpty) categories.add(name);
        }
      }
      final detectedCourse = detectCourseFromCategories(categories);
      final course = detectedCourse ?? 'mains';

      // Source
      var sourceUrl = json['source_url']?.toString().trim();
      if (sourceUrl?.isEmpty == true) sourceUrl = null;
      final source = (sourceUrl != null &&
              (sourceUrl.startsWith('http://') ||
                  sourceUrl.startsWith('https://')))
          ? RecipeSource.url
          : RecipeSource.personal;
      if (source == RecipeSource.personal) sourceUrl = null;

      return RecipeImportResult(
        course: course,
        comments: comments,
        rawIngredients: rawIngredients,
        rawDirections: rawDirections,
        serves: serves,
        time: time,
        sourceUrl: sourceUrl,
        source: source,
        rawText: jsonStr,
        detectedCourses: [course],
        nameConfidence: 0.0,
        courseConfidence: detectedCourse != null ? 0.7 : 0.3,
        ingredientsConfidence: rawIngredients.isNotEmpty ? 0.9 : 0.0,
        directionsConfidence: rawDirections.isNotEmpty ? 0.8 : 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _writeImageBytes(List<int> bytes, String ext) async {
    if (bytes.isEmpty) return null;
    final tmpDir = await getTemporaryDirectory();
    final fileName = '${_uuid.v4()}.$ext';
    final file = File('${tmpDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  bool _isImageExtension(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  String _extensionOf(String path) {
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String _shortMessage(Object e) {
    final msg = e.toString();
    return msg.length > 120 ? '${msg.substring(0, 117)}…' : msg;
  }
}
