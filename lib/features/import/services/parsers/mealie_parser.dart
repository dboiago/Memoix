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

/// Parses Mealie recipe-manager export archives.
///
/// Two archive structures are supported and detected automatically:
///
/// **v1.0+ subfolder format**
/// ```
/// recipes/{slug}/{slug}.json
/// recipes/{slug}/{image}.jpg   ← images alongside JSON
/// ```
///
/// **Legacy flat format**
/// ```
/// recipes/{slug}.json
/// images/{slug}.{ext}          ← images in separate folder
/// ```
///
/// Both formats may coexist in the same archive; each entry is classified
/// by its own path depth.
class MealieParser implements ExternalFormatParser {
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('MealieParser: failed to decode zip — $e');
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

    // Build lookup maps for quick access.
    // entry.name uses forward slashes on all platforms (archive package).
    final Map<String, ArchiveFile> entryByPath = {
      for (final e in archive) if (e.isFile) e.name: e,
    };

    // Collect JSON recipe entries (entries under recipes/ ending in .json)
    // and classify each as subfolder vs flat by path depth.
    //   subfolder: "recipes/{slug}/recipe.json" → 3 segments, last = recipe.json
    //   flat:      "recipes/{slug}.json"         → 2 segments
    final jsonEntries = <ArchiveFile>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final parts = name.split('/');
      if (parts.isEmpty || parts[0] != 'recipes') continue;
      // Subfolder format: recipes/{slug}/recipe.json
      if (parts.length == 3 && parts[2] == 'recipe.json') {
        jsonEntries.add(entry);
        continue;
      }
      // Flat format: recipes/{slug}.json
      if (parts.length == 2 && name.endsWith('.json')) {
        jsonEntries.add(entry);
      }
    }

    final results = <Recipe>[];
    final failures = <ExternalParseFailure>[];

    for (final entry in jsonEntries) {
      final parts = entry.name.split('/');
      final isSubfolder = parts.length == 3;
      final slug = isSubfolder ? parts[1] : parts[1].replaceAll('.json', '');

      // Phase 1: UTF-8 decode
      String? jsonStr;
      try {
        jsonStr = utf8.decode(entry.content as List<int>);
      } on FormatException catch (e) {
        debugPrint('MealieParser: UTF-8 decode failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: slug,
          reason: 'Malformed UTF-8 encoding',
        ));
        continue;
      } catch (e) {
        debugPrint('MealieParser: decode error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: slug,
          reason: 'Corrupt archive entry: ${_shortMessage(e)}',
        ));
        continue;
      }

      // Phase 2: JSON parse
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(jsonStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        debugPrint('MealieParser: JSON parse failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: slug,
          reason: 'Malformed JSON: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      } catch (e) {
        debugPrint('MealieParser: JSON error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: slug,
          reason: 'JSON parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      }

      // Phase 3: field mapping
      try {
        final recipe = await _parseEntry(
          json,
          jsonStr,
          entryByPath: entryByPath,
          slug: slug,
          isSubfolder: isSubfolder,
          subfolderPrefix: isSubfolder ? 'recipes/$slug/' : null,
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
        debugPrint('MealieParser: field mapping failed for "${entry.name}" — $e');
        final bestEffortName = json['name']?.toString().trim();
        failures.add(ExternalParseFailure(
          name: bestEffortName?.isNotEmpty == true ? bestEffortName : slug,
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

  Future<Recipe?> _parseEntry(
    Map<String, dynamic> json,
    String jsonStr, {
    required Map<String, ArchiveFile> entryByPath,
    required String slug,
    required bool isSubfolder,
    String? subfolderPrefix,
  }) async {
    final rawName = json['name']?.toString() ?? '';
    if (rawName.trim().isEmpty) return null;

    // -------------------------------------------------------------------------
    // Description + notes
    // -------------------------------------------------------------------------
    final description = json['description']?.toString().trim() ?? '';

    final notesList = json['notes'];
    final noteParts = <String>[];
    if (notesList is List) {
      for (final note in notesList) {
        if (note is! Map<String, dynamic>) continue;
        final title = note['title']?.toString().trim() ?? '';
        final text = note['text']?.toString().trim() ?? '';
        if (title.isNotEmpty && text.isNotEmpty) {
          noteParts.add('**$title**\n$text');
        } else if (text.isNotEmpty) {
          noteParts.add(text);
        } else if (title.isNotEmpty) {
          noteParts.add(title);
        }
      }
    }
    final notesBlock = noteParts.join('\n\n');

    final String? comments;
    if (description.isNotEmpty && notesBlock.isNotEmpty) {
      comments = '$description\n\n---\n\n$notesBlock';
    } else if (description.isNotEmpty) {
      comments = description;
    } else if (notesBlock.isNotEmpty) {
      comments = notesBlock;
    } else {
      comments = null;
    }

    // -------------------------------------------------------------------------
    // Ingredients
    // -------------------------------------------------------------------------
    final ingredients = <Ingredient>[];
    final ingredientList = json['recipeIngredient'];
    if (ingredientList is List) {
      String? currentSection;
      for (final item in ingredientList) {
        if (item is! Map<String, dynamic>) continue;

        // Section header
        final sectionTitle = item['title']?.toString().trim() ?? '';
        if (sectionTitle.isNotEmpty) {
          currentSection = sectionTitle;
          continue;
        }

        // Build raw string — prefer originalText, fall back to components
        String? rawLine = item['originalText']?.toString().trim();
        if (rawLine == null || rawLine.isEmpty) {
          final quantity = item['quantity']?.toString().trim();
          final unit = (item['unit'] as Map<String, dynamic>?)?['name']
              ?.toString()
              .trim();
          final food = (item['food'] as Map<String, dynamic>?)?['name']
              ?.toString()
              .trim();
          final note = item['note']?.toString().trim();

          final parts = <String>[
            if (quantity != null && quantity.isNotEmpty) quantity,
            if (unit != null && unit.isNotEmpty) unit,
            if (food != null && food.isNotEmpty) food,
          ];
          if (note != null && note.isNotEmpty) {
            parts.add(', $note');
          }
          if (parts.isEmpty) continue; // all fields null — skip
          rawLine = parts.join(' ');
        }

        final parsed = IngredientParser.parse(rawLine);
        if (!parsed.looksLikeIngredient && parsed.name.isEmpty) continue;

        final normalizedAmount = parsed.amount != null
            ? TextNormalizer.normalizeFractions(parsed.amount!)
            : null;

        ingredients.add(Ingredient.create(
          name: TextNormalizer.cleanName(parsed.name),
          amount:
              (normalizedAmount?.isNotEmpty == true) ? normalizedAmount : null,
          unit: UnitNormalizer.normalize(parsed.unit),
          preparation: parsed.preparation,
          section: currentSection,
          bakerPercent: parsed.bakerPercent,
          alternative: parsed.alternative,
        ));
      }
    }

    // -------------------------------------------------------------------------
    // Directions
    // -------------------------------------------------------------------------
    final directions = <String>[];
    final instructionList = json['recipeInstructions'];
    if (instructionList is List) {
      for (final step in instructionList) {
        if (step is! Map<String, dynamic>) continue;
        final stepTitle = step['title']?.toString().trim() ?? '';
        final stepText = step['text']?.toString().trim() ?? '';
        if (stepTitle.isNotEmpty && stepText.isNotEmpty) {
          directions.add('**$stepTitle**\n$stepText');
        } else if (stepText.isNotEmpty) {
          directions.add(stepText);
        } else if (stepTitle.isNotEmpty) {
          directions.add(stepTitle);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Servings — prefer recipeServings (int), fall back to leading int in recipeYield
    // -------------------------------------------------------------------------
    String? serves;
    final recipeServings = json['recipeServings'];
    if (recipeServings != null) {
      serves = UnitNormalizer.normalizeServes(recipeServings.toString());
    } else {
      final yieldStr = json['recipeYield']?.toString() ?? '';
      final leadingInt = RegExp(r'^\d+').firstMatch(yieldStr)?.group(0);
      if (leadingInt != null) {
        serves = UnitNormalizer.normalizeServes(leadingInt);
      }
    }
    if (serves?.isEmpty == true) serves = null;

    // -------------------------------------------------------------------------
    // Time — parse ISO 8601 or human-readable duration strings
    // -------------------------------------------------------------------------
    final totalTimeRaw = json['totalTime']?.toString();
    final cookTimeRaw = json['cookTime']?.toString();
    final timeInput =
        (totalTimeRaw?.isNotEmpty == true) ? totalTimeRaw : cookTimeRaw;
    final time = _parseDuration(timeInput);

    // -------------------------------------------------------------------------
    // Categories + tags → course detection
    // -------------------------------------------------------------------------
    final categories = <String>[];
    final categoryList = json['recipeCategory'];
    if (categoryList is List) {
      for (final c in categoryList) {
        final name = c is Map<String, dynamic>
            ? c['name']?.toString().trim()
            : c?.toString().trim();
        if (name != null && name.isNotEmpty) categories.add(name);
      }
    }
    final tagList = json['tags'];
    if (tagList is List) {
      for (final t in tagList) {
        final name = t is Map<String, dynamic>
            ? t['name']?.toString().trim()
            : t?.toString().trim();
        if (name != null && name.isNotEmpty) categories.add(name);
      }
    }
    final suggestedCourse = detectCourseFromCategories(categories) ?? 'mains';

    // -------------------------------------------------------------------------
    // Rating
    // -------------------------------------------------------------------------
    int rating = 0;
    final rawRating = json['rating'];
    if (rawRating is int) {
      rating = rawRating.clamp(0, 5);
    } else if (rawRating is num) {
      rating = rawRating.round().clamp(0, 5);
    }

    // -------------------------------------------------------------------------
    // Source URL
    // -------------------------------------------------------------------------
    var sourceUrl = json['orgURL']?.toString().trim();
    if (sourceUrl?.isEmpty == true) sourceUrl = null;
    final source = (sourceUrl != null &&
            (sourceUrl.startsWith('http://') ||
                sourceUrl.startsWith('https://')))
        ? RecipeSource.url
        : RecipeSource.personal;
    if (source == RecipeSource.personal) sourceUrl = null;

    // -------------------------------------------------------------------------
    // Image — raw bytes from archive entry → temp file
    // -------------------------------------------------------------------------
    String? headerImage;
    try {
      ArchiveFile? imageEntry;

      if (isSubfolder && subfolderPrefix != null) {
        // Look in the same subfolder as the JSON
        for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
          final candidate = entryByPath['${subfolderPrefix}original.$ext'] ??
              entryByPath['${subfolderPrefix}min-original.$ext'] ??
              entryByPath['${subfolderPrefix}$slug.$ext'];
          if (candidate != null) {
            imageEntry = candidate;
            break;
          }
        }
        // Generic search in subfolder if specific names not found
        if (imageEntry == null) {
          imageEntry = entryByPath.entries
              .where((e) =>
                  e.key.startsWith(subfolderPrefix) &&
                  _isImageExtension(e.key))
              .map((e) => e.value)
              .firstOrNull;
        }
      } else {
        // Flat format — look in images/{slug}.*
        for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
          final candidate = entryByPath['images/$slug.$ext'];
          if (candidate != null) {
            imageEntry = candidate;
            break;
          }
        }
        // Generic search in images/ folder
        if (imageEntry == null) {
          imageEntry = entryByPath.entries
              .where((e) =>
                  e.key.startsWith('images/') && _isImageExtension(e.key))
              .map((e) => e.value)
              .firstOrNull;
        }
      }

      if (imageEntry != null) {
        headerImage = await _writeImageBytes(
          imageEntry.content as List<int>,
          _extensionOf(imageEntry.name),
        );
      }
    } catch (e) {
      debugPrint('MealieParser: failed to write image for "$slug" — $e');
      // Non-fatal — recipe saved without image
    }

    // -------------------------------------------------------------------------
    // Assemble recipe
    // -------------------------------------------------------------------------
    final recipe = Recipe.create(
      uuid: _uuid.v4(),
      name: TextNormalizer.cleanName(rawName),
      course: suggestedCourse,
      serves: serves,
      time: (time != null && time.isNotEmpty) ? time : null,
      comments: comments,
      ingredients: ingredients,
      directions: directions,
      tags: categories,
      sourceUrl: sourceUrl,
      source: source,
      rating: rating,
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
      // Course
      final categories = <String>[];
      final categoryList = json['recipeCategory'];
      if (categoryList is List) {
        for (final c in categoryList) {
          final name = c is Map<String, dynamic>
              ? c['name']?.toString().trim()
              : c?.toString().trim();
          if (name != null && name.isNotEmpty) categories.add(name);
        }
      }
      final tagList = json['tags'];
      if (tagList is List) {
        for (final t in tagList) {
          final name = t is Map<String, dynamic>
              ? t['name']?.toString().trim()
              : t?.toString().trim();
          if (name != null && name.isNotEmpty) categories.add(name);
        }
      }
      final course = detectCourseFromCategories(categories) ?? 'mains';

      // Description + notes
      final description = json['description']?.toString().trim() ?? '';
      final notesList = json['notes'];
      final noteParts = <String>[];
      if (notesList is List) {
        for (final note in notesList) {
          if (note is! Map<String, dynamic>) continue;
          final title = note['title']?.toString().trim() ?? '';
          final text = note['text']?.toString().trim() ?? '';
          if (title.isNotEmpty && text.isNotEmpty) {
            noteParts.add('**$title**\n$text');
          } else if (text.isNotEmpty) {
            noteParts.add(text);
          } else if (title.isNotEmpty) {
            noteParts.add(title);
          }
        }
      }
      final notesBlock = noteParts.join('\n\n');
      final String? comments;
      if (description.isNotEmpty && notesBlock.isNotEmpty) {
        comments = '$description\n\n---\n\n$notesBlock';
      } else if (description.isNotEmpty) {
        comments = description;
      } else if (notesBlock.isNotEmpty) {
        comments = notesBlock;
      } else {
        comments = null;
      }

      // Ingredients as RawIngredientData
      final rawIngredients = <RawIngredientData>[];
      final ingredientList = json['recipeIngredient'];
      if (ingredientList is List) {
        String? currentSection;
        for (final item in ingredientList) {
          if (item is! Map<String, dynamic>) continue;
          final sectionTitle = item['title']?.toString().trim() ?? '';
          if (sectionTitle.isNotEmpty) {
            currentSection = sectionTitle;
            continue;
          }
          String? rawLine = item['originalText']?.toString().trim();
          if (rawLine == null || rawLine.isEmpty) {
            final quantity = item['quantity']?.toString().trim();
            final unit = (item['unit'] as Map<String, dynamic>?)?['name']
                ?.toString()
                .trim();
            final food = (item['food'] as Map<String, dynamic>?)?['name']
                ?.toString()
                .trim();
            final note = item['note']?.toString().trim();
            final parts = <String>[
              if (quantity != null && quantity.isNotEmpty) quantity,
              if (unit != null && unit.isNotEmpty) unit,
              if (food != null && food.isNotEmpty) food,
            ];
            if (note != null && note.isNotEmpty) parts.add(', $note');
            if (parts.isEmpty) continue;
            rawLine = parts.join(' ');
          }
          final parsed = IngredientParser.parse(rawLine);
          if (!parsed.looksLikeIngredient && parsed.name.isEmpty) continue;
          final normalizedAmount = parsed.amount != null
              ? TextNormalizer.normalizeFractions(parsed.amount!)
              : null;
          rawIngredients.add(RawIngredientData(
            original: rawLine,
            amount:
                (normalizedAmount?.isNotEmpty == true) ? normalizedAmount : null,
            unit: UnitNormalizer.normalize(parsed.unit),
            preparation: parsed.preparation,
            bakerPercent: parsed.bakerPercent,
            alternative: parsed.alternative,
            name: TextNormalizer.cleanName(parsed.name),
            looksLikeIngredient: parsed.looksLikeIngredient,
            sectionName: currentSection,
          ));
        }
      }

      // Directions
      final rawDirections = <String>[];
      final instructionList = json['recipeInstructions'];
      if (instructionList is List) {
        for (final step in instructionList) {
          if (step is! Map<String, dynamic>) continue;
          final stepTitle = step['title']?.toString().trim() ?? '';
          final stepText = step['text']?.toString().trim() ?? '';
          if (stepTitle.isNotEmpty && stepText.isNotEmpty) {
            rawDirections.add('**$stepTitle**\n$stepText');
          } else if (stepText.isNotEmpty) {
            rawDirections.add(stepText);
          } else if (stepTitle.isNotEmpty) {
            rawDirections.add(stepTitle);
          }
        }
      }

      // Serves
      String? serves;
      final recipeServings = json['recipeServings'];
      if (recipeServings != null) {
        serves = UnitNormalizer.normalizeServes(recipeServings.toString());
      } else {
        final yieldStr = json['recipeYield']?.toString() ?? '';
        final leadingInt = RegExp(r'^\d+').firstMatch(yieldStr)?.group(0);
        if (leadingInt != null) {
          serves = UnitNormalizer.normalizeServes(leadingInt);
        }
      }
      if (serves?.isEmpty == true) serves = null;

      // Time
      final totalTimeRaw = json['totalTime']?.toString();
      final cookTimeRaw = json['cookTime']?.toString();
      final timeInput =
          (totalTimeRaw?.isNotEmpty == true) ? totalTimeRaw : cookTimeRaw;
      final time = _parseDuration(timeInput);

      // Source
      var sourceUrl = json['orgURL']?.toString().trim();
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
        time: (time != null && time.isNotEmpty) ? time : null,
        sourceUrl: sourceUrl,
        source: source,
        rawText: jsonStr,
        detectedCourses: [course],
      );
    } catch (_) {
      return null;
    }
  }

  /// Writes raw image bytes to a temporary file and returns the absolute path.
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
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  /// Parses an ISO 8601 duration string (e.g. `PT1H30M`) or a plain
  /// human-readable string (e.g. `"30 minutes"`, `"1 hour"`) into a
  /// normalised time string via [UnitNormalizer.normalizeTime].
  ///
  /// Returns null if the input is null, empty, or unparseable.
  String? _parseDuration(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final trimmed = raw.trim();

    // ISO 8601: PT[nH][nM][nS]
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

  String _shortMessage(Object e) {
    final msg = e.toString();
    return msg.length > 120 ? '${msg.substring(0, 117)}…' : msg;
  }
}
