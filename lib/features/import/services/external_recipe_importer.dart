import 'dart:io';
import 'dart:typed_data';

import '../../recipes/models/recipe.dart';
import 'parsers/external_format_parser.dart';
import 'parsers/json_ld_parser.dart';
import 'parsers/mealie_parser.dart';
import 'parsers/mela_parser.dart';
import 'parsers/paprika_parser.dart';
import 'parsers/tandoor_parser.dart';
import 'parsers/zip_dispatch_parser.dart';

export 'parsers/external_format_parser.dart'
    show ExternalImportSummary, ExternalFormatParser, ExternalParseFailure;

// ---------------------------------------------------------------------------
// Result types returned to the caller of RecipeBackupService.importRecipes()
// ---------------------------------------------------------------------------

/// Sealed result type for [RecipeBackupService.importRecipes].
sealed class RecipeImportFileResult {}

/// The user cancelled the file picker — no action required.
class ImportCancelled extends RecipeImportFileResult {
  ImportCancelled();
}

/// A file was picked and processed directly (JSON backup).
/// [imported] is the number of recipes saved; [skipped] is always 0 for JSON.
class ImportCompleted extends RecipeImportFileResult {
  final int imported;
  final int skipped;
  ImportCompleted({required this.imported, required this.skipped});
}

/// An external-format archive was parsed and the caller must push a review
/// screen so the user can choose which recipes to import.
class ImportNeedsReview extends RecipeImportFileResult {
  /// Recipes parsed from the archive, each with suggested course and source
  /// already assigned.  The caller must not mutate this list directly.
  final List<Recipe> recipes;

  /// Number of archive entries that were skipped due to parse errors.
  final int parseSkipped;

  /// Detailed failure records for entries that could not be parsed.
  final List<ExternalParseFailure> failures;

  /// Original archive bytes, retained for format-override re-parsing on
  /// [ExternalImportReviewScreen].
  final Uint8List fileBytes;

  /// User-visible name of the parser that produced this result
  /// (e.g. 'Mealie', 'Mela').
  final String detectedParserName;

  ImportNeedsReview({
    required this.recipes,
    required this.parseSkipped,
    required this.fileBytes,
    required this.detectedParserName,
    this.failures = const [],
  });
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown when no parser is registered for the given file extension.
class UnsupportedFormatException implements Exception {
  final String extension;
  const UnsupportedFormatException(this.extension);

  @override
  String toString() => 'Unsupported file format: .$extension';
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Routes external recipe archive files to the correct [ExternalFormatParser]
/// based on file extension.
///
/// **Adding a new format** requires only:
/// 1. Creating a class that implements [ExternalFormatParser].
/// 2. Registering it in [_registry] below.
/// No other change is needed.
class ExternalRecipeImporter {
  /// Maximum raw file size accepted before any parsing begins (50 MB).
  static const int _maxFileSizeBytes = 50 * 1024 * 1024;

  static final Map<String, ExternalFormatParser> _registry = {
    'melarecipes': MelaParser(),
    'melarecipe': MelaParser(),
    'paprikarecipes': PaprikaParser(),
    'paprikarecipe': PaprikaParser(),
    'zip': ZipDispatchParser(),
  };

  /// Named parsers for format override — keyed by user-visible app name.
  /// Excludes [ZipDispatchParser] (a meta-parser, not a user-selectable format).
  static final Map<String, ExternalFormatParser> _namedParsers = {
    'Mela': MelaParser(),
    'Mealie': MealieParser(),
    'Paprika': PaprikaParser(),
    'RecipeSage / JSON-LD': JsonLdParser(),
    'Tandoor': TandoorParser(),
  };

  /// All available parser names, sorted alphabetically.
  static List<String> get parserNames =>
      (_namedParsers.keys.toList()..sort());

  /// Parses [bytes] using the parser identified by [name].
  ///
  /// Throws [UnsupportedFormatException] if [name] is not registered.
  static Future<ExternalImportSummary> parseByName(
    String name,
    Uint8List bytes,
  ) {
    if (bytes.length > _maxFileSizeBytes) {
      return Future.value(ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(
            reason: 'File too large to import (max 50 MB)',
          ),
        ],
        detectedParserName: name,
      ));
    }
    final parser = _namedParsers[name];
    if (parser == null) throw UnsupportedFormatException(name);
    return parser.parse(bytes);
  }

  /// Returns true when [extension] (without leading dot, any case) has a
  /// registered parser.
  static bool supportsExtension(String extension) =>
      _registry.containsKey(extension.toLowerCase());

  /// Parses [bytes] using the parser registered for [extension].
  ///
  /// Throws [UnsupportedFormatException] if no parser is registered.
  Future<ExternalImportSummary> parse(
    String extension,
    Uint8List bytes,
  ) {
    if (bytes.length > _maxFileSizeBytes) {
      return Future.value(ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(
            reason: 'File too large to import (max 50 MB)',
          ),
        ],
      ));
    }
    final parser = _registry[extension.toLowerCase()];
    if (parser == null) throw UnsupportedFormatException(extension);
    return parser.parse(bytes);
  }

  /// Deletes temporary image files that were written during parsing for
  /// [recipes] that were not ultimately imported.
  ///
  /// Silently ignores any IO errors.
  static void cleanupTempImages(List<Recipe> recipes) {
    for (final recipe in recipes) {
      _deleteTempFile(recipe.headerImage);
      for (final path in recipe.stepImages) {
        _deleteTempFile(path);
      }
    }
  }

  static void _deleteTempFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Silently ignore IO errors during temp file cleanup
    }
  }
}
