import 'dart:typed_data';

import '../../recipes/models/recipe.dart';
import 'parsers/external_format_parser.dart';
import 'parsers/mela_parser.dart';
import 'parsers/paprika_parser.dart';
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

  ImportNeedsReview({
    required this.recipes,
    required this.parseSkipped,
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
  static final Map<String, ExternalFormatParser> _registry = {
    'melarecipes': MelaParser(),
    'melarecipe': MelaParser(),
    'paprikarecipes': PaprikaParser(),
    'paprikarecipe': PaprikaParser(),
    'zip': ZipDispatchParser(),
  };

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
    final parser = _registry[extension.toLowerCase()];
    if (parser == null) throw UnsupportedFormatException(extension);
    return parser.parse(bytes);
  }
}
