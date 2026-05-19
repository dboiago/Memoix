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

/// Parses `.paprikarecipes` and `.paprikarecipe` files produced by the
/// Paprika Recipe Manager app.
///
/// Outer container is a zip archive.  Each entry is individually
/// gzip-compressed.  The decode sequence is:
///   1. [ZipDecoder] → raw entry bytes
///   2. [GZipCodec().decode] → JSON bytes
///   3. [utf8.decode] → JSON string
///   4. [jsonDecode] → Map
class PaprikaParser implements ExternalFormatParser {
  static const _uuid = Uuid();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('PaprikaParser: failed to decode zip — $e');
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

      // Phase 0: gzip decompression — every Paprika entry is gzipped
      List<int>? jsonBytes;
      try {
        final gzipBytes = entry.content as List<int>;
        jsonBytes = GZipCodec().decode(gzipBytes);
      } on ArchiveException catch (e) {
        debugPrint('PaprikaParser: gzip decode failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Corrupt archive entry (gzip): ${_shortMessage(e)}',
        ));
        continue;
      } on FormatException catch (e) {
        debugPrint('PaprikaParser: gzip format error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Corrupt gzip data: ${_shortMessage(e)}',
        ));
        continue;
      } catch (e) {
        debugPrint('PaprikaParser: gzip error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Gzip error: ${_shortMessage(e)}',
        ));
        continue;
      }

      // Phase 1: decode bytes to UTF-8 string
      String? jsonStr;
      try {
        jsonStr = utf8.decode(jsonBytes);
      } on FormatException catch (e) {
        debugPrint('PaprikaParser: UTF-8 decode failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Malformed UTF-8 encoding',
        ));
        continue;
      } catch (e) {
        debugPrint('PaprikaParser: decode error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Decode error: ${_shortMessage(e)}',
        ));
        continue;
      }

      // Phase 2: JSON parse
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(jsonStr) as Map<String, dynamic>;
      } on FormatException catch (e) {
        debugPrint('PaprikaParser: JSON parse failed for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'Malformed JSON: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      } catch (e) {
        debugPrint('PaprikaParser: JSON error for "${entry.name}" — $e');
        failures.add(ExternalParseFailure(
          name: _entryBaseName(entry.name),
          reason: 'JSON parse error: ${_shortMessage(e)}',
          rawText: jsonStr,
        ));
        continue;
      }

      // Phase 3: field mapping — graceful degradation; only fails if no name
      try {
        final recipe = await _parseEntry(json);
        if (recipe != null) {
          results.add(recipe);
        } else {
          final bestEffortName = json['name']?.toString().trim();
          failures.add(ExternalParseFailure(
            name: bestEffortName?.isNotEmpty == true ? bestEffortName : _entryBaseName(entry.name),
            reason: 'Missing required fields (name)',
            rawText: jsonStr,
          ));
        }
      } catch (e) {
        debugPrint('PaprikaParser: field mapping failed for "${entry.name}" — $e');
        final bestEffortName = json['name']?.toString().trim();
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
    final rawName = json['name']?.toString() ?? '';
    if (rawName.trim().isEmpty) return null;

    // Categories → course detection + tags
    final categories = _toStringList(json['categories']);
    final suggestedCourse =
        detectCourseFromCategories(categories) ?? 'mains';

    // Description + notes — concatenate when both present
    final description = json['description']?.toString().trim() ?? '';
    final notes = json['notes']?.toString().trim() ?? '';
    final comments =
        [description, notes].where((s) => s.isNotEmpty).join('\n\n');

    // Ingredients — split on newline, then parse each line
    final ingredients =
        _parseIngredientLines(_splitLines(json['ingredients']?.toString()));

    // Directions — split on newline, keep non-empty
    final directions = _splitLines(json['directions']?.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    // Time — prefer total_time over cook_time; prep_time is dropped
    final totalTimeRaw = json['total_time']?.toString();
    final cookTimeRaw = json['cook_time']?.toString();
    final timeInput =
        (totalTimeRaw?.isNotEmpty == true) ? totalTimeRaw : cookTimeRaw;
    final time = UnitNormalizer.normalizeTime(timeInput);

    // Servings
    final servesRaw =
        UnitNormalizer.normalizeServes(json['servings']?.toString());
    final serves =
        (servesRaw != null && servesRaw.isNotEmpty) ? servesRaw : null;

    // Source URL (from source_url field)
    var sourceUrl = json['source_url']?.toString().trim();
    if (sourceUrl?.isEmpty == true) sourceUrl = null;

    // Image handling:
    //   - photo_data present → decode base64 to temp file → headerImage
    //   - photo_data absent → check photo_url as a sourceUrl fallback (no download)
    String? headerImage;
    final photoData = json['photo_data']?.toString() ?? '';
    if (photoData.isNotEmpty) {
      headerImage = await _writeBase64Image(photoData);
    } else {
      final photoUrl = json['photo_url']?.toString().trim() ?? '';
      if (photoUrl.isNotEmpty &&
          sourceUrl == null &&
          (photoUrl.startsWith('http://') ||
              photoUrl.startsWith('https://'))) {
        // Store as source URL only — no download
        sourceUrl = photoUrl;
      }
    }

    // Source: url if a valid http(s) link is present, otherwise personal
    final source = (sourceUrl != null &&
            (sourceUrl.startsWith('http://') ||
                sourceUrl.startsWith('https://')))
        ? RecipeSource.url
        : RecipeSource.personal;

    // Rating clamped to 0-5
    int rating = 0;
    final rawRating = json['rating'];
    if (rawRating is int) {
      rating = rawRating.clamp(0, 5);
    } else if (rawRating is num) {
      rating = rawRating.round().clamp(0, 5);
    }

    // nutritional_info is a free-form string — no structured parser exists;
    // silently dropped per specification.

    // Paprika's "source" field is the originating app/site name (a plain
    // string, not a URL).  Recipe has no sourceName field — silently dropped.

    final recipe = Recipe.create(
      uuid: _uuid.v4(),
      name: TextNormalizer.cleanName(rawName),
      course: suggestedCourse,
      serves: serves,
      time: (time != null && time.isNotEmpty) ? time : null,
      comments: comments.isNotEmpty ? comments : null,
      ingredients: ingredients,
      directions: directions,
      tags: categories,
      sourceUrl: sourceUrl,
      source: source,
      isFavourite: json['on_favorites'] as bool? ?? false,
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

  /// Decodes a single base64 image string to a temporary file and returns
  /// its absolute path, or null on failure.
  ///
  /// [_saveImageBlobs] in [RecipeRepository] reads this absolute path and
  /// persists the bytes to the blob store during [saveRecipe].
  Future<String?> _writeBase64Image(String b64) async {
    if (b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      final tmpDir = await getTemporaryDirectory();
      final fileName = '${_uuid.v4()}.jpg';
      final file = File('${tmpDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('PaprikaParser: failed to write image — $e');
      return null;
    }
  }
}
