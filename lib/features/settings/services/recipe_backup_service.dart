import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';

import '../../cellar/models/cellar_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../notes/repository/scratch_pad_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../import/services/external_recipe_importer.dart';
import '../../import/services/parsers/json_ld_parser.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../../core/database/app_database.dart' hide Recipe, Ingredient, Course;
import '../../../core/widgets/memoix_snackbar.dart';

/// Service for exporting and importing recipes as JSON backup files
class RecipeBackupService {
  final RecipeRepository _recipeRepository;
  final PizzaRepository _pizzaRepository;
  final SandwichRepository _sandwichRepository;
  final SmokingRepository _smokingRepository;
  final ModernistRepository _modernistRepository;
  final CellarRepository _cellarRepository;
  final CheeseRepository _cheeseRepository;
  final ScratchPadRepository _scratchPadRepository;

  RecipeBackupService(
    this._recipeRepository,
    this._pizzaRepository,
    this._sandwichRepository,
    this._smokingRepository,
    this._modernistRepository,
    this._cellarRepository,
    this._cheeseRepository,
    this._scratchPadRepository,
  );

  /// Export all personal recipes to a JSON file
  /// Returns the path to the exported file or null if cancelled/failed
  Future<String?> exportRecipes({bool includeAll = false}) async {
    // Get recipes to export
    List<Recipe> recipes;
    if (includeAll) {
      recipes = await _recipeRepository.getAllRecipes();
    } else {
      // All user recipes (not memoix collection)
      // Includes: personal, imported, ocr, url, ai, walkin
      final allRecipes = await _recipeRepository.getAllRecipes();
      recipes = allRecipes.where((r) => r.source != RecipeSource.memoix).toList();
    }

    // Fetch specialist domains
    var pizzas = await _pizzaRepository.getAllPizzas();
    var sandwiches = await _sandwichRepository.getAllSandwiches();
    var smokingRecipes = await _smokingRepository.getAllRecipes();
    var modernistRecipes = await _modernistRepository.getAll();
    var cellarEntries = await _cellarRepository.getAllEntries();
    var cheeseEntries = await _cheeseRepository.getAllEntries();
    if (!includeAll) {
      pizzas = pizzas.where((p) => p.source != PizzaSource.memoix.name).toList();
      sandwiches = sandwiches.where((s) => s.source != SandwichSource.memoix.name).toList();
      smokingRecipes = smokingRecipes.where((s) => s.source != SmokingSource.memoix.name).toList();
      modernistRecipes = modernistRecipes.where((m) => m.source.name != ModernistSource.memoix.name).toList();
      cellarEntries = cellarEntries.where((c) => c.source != CellarSource.memoix.name).toList();
      cheeseEntries = cheeseEntries.where((c) => c.source != CheeseSource.memoix.name).toList();
    }

    if (recipes.isEmpty && pizzas.isEmpty && sandwiches.isEmpty &&
        smokingRecipes.isEmpty && modernistRecipes.isEmpty &&
        cellarEntries.isEmpty && cheeseEntries.isEmpty) {
      throw Exception('No personal recipes or entries to export');
    }
    final quickNotes = await _scratchPadRepository.getQuickNotes();
    final drafts = await _scratchPadRepository.getAllDrafts();

    // Convert to JSON
    final jsonData = {
      'format': 'memoix/v1',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'recipeCount': recipes.length,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'pizzas': pizzas.map((p) => p.toJson()).toList(),
      'sandwiches': sandwiches.map((s) => s.toJson()).toList(),
      'smoking': smokingRecipes.map((s) => s.toJson()).toList(),
      'modernist': modernistRecipes.map((m) => m.toJson()).toList(),
      'cellar': cellarEntries.map((c) => c.toJson()).toList(),
      'cheese': cheeseEntries.map((c) => c.toJson()).toList(),
      'scratch': {
        'quickNotes': quickNotes,
        'drafts': drafts.map((d) => <String, dynamic>{
          'uuid': d.uuid,
          'name': d.name,
          'imagePath': d.imagePath,
          'serves': d.serves,
          'time': d.time,
          'structuredIngredients': d.structuredIngredients,
          'structuredDirections': d.structuredDirections,
          'notes': d.notes,
          'createdAt': d.createdAt.toIso8601String(),
          'updatedAt': d.updatedAt.toIso8601String(),
        }).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    // Generate filename with date
    final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final filename = 'memoix_recipes_$dateStr.json';

    // On desktop (Windows/macOS/Linux), use save file dialog
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Recipe Backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (outputPath == null) {
        return null; // User cancelled
      }
      
      final file = File(outputPath);
      await file.writeAsString(jsonString);
      return outputPath;
    }

    // On mobile, save to documents and share
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(jsonString);

    // Share the file
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'Memoix Recipe Backup',
        text: 'Exported ${recipes.length} recipe${recipes.length == 1 ? '' : 's'}',
      ),
      );
    } catch (e) {
      debugPrint('RecipeBackupService.exportRecipes error: $e');
      MemoixSnackBar.showError('Could not open share sheet. Please try again.');
    }

    return file.path;
  }

  /// Import recipes from a JSON backup or external app archive file.
  ///
  /// Returns a [RecipeImportFileResult]:
  ///   - [ImportCancelled] — user dismissed the file picker.
  ///   - [ImportCompleted] — JSON backup imported directly (no review needed).
  ///   - [ImportNeedsReview] — external archive parsed; caller must push
  ///     [ExternalImportReviewScreen] so the user can confirm which recipes
  ///     to import.
  Future<RecipeImportFileResult> importRecipes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'json',
        'melarecipes', 'melarecipe',
        'paprikarecipes', 'paprikarecipe',
        'zip',
      ],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return ImportCancelled();
    }

    final file = result.files.first;
    final ext = file.name.split('.').last.toLowerCase();

    // External app formats (Mela, Paprika, …)
    if (ExternalRecipeImporter.supportsExtension(ext)) {
      final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Could not read file');
      }

      final summary = await ExternalRecipeImporter().parse(ext, bytes);

      if (summary.recipes.isEmpty && summary.skippedCount == 0) {
        return ImportCompleted(imported: 0, skipped: 0);
      }
      return ImportNeedsReview(
        recipes: summary.recipes,
        parseSkipped: summary.skippedCount,
        failures: summary.failures,
        fileBytes: bytes,
        detectedParserName: summary.detectedParserName ??
            ExternalRecipeImporter.parserNames.first,
      );
    }

    // JSON file — read bytes once, then sniff content to determine format.
    final Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('Could not read file');
    }

    // Attempt UTF-8 + JSON decode for content sniffing.
    // If either step fails, fall through to the Memoix backup path and let it
    // error naturally.
    Object? sniffed;
    try {
      sniffed = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      // Decoding or parsing failed — fall through to Memoix path.
    }

    if (sniffed != null) {
      debugPrint('[sniff] sniffed runtimeType=${sniffed.runtimeType}');
      // Priority 1: explicit Memoix v1 format tag → Memoix path.
      final isMemoixV1 = sniffed is Map<String, dynamic> &&
          sniffed['format'] == 'memoix/v1';
      debugPrint('[sniff] isMemoixV1=$isMemoixV1'
          '${sniffed is Map ? ", format=${(sniffed as Map)['format']}" : ""}');

      if (!isMemoixV1) {
        // Priority 2: JSON-LD single recipe object with @type == "Recipe".
        // Priority 3: JSON-LD array where the first element has @type == "Recipe".
        bool isJsonLd = false;
        if (sniffed is Map<String, dynamic>) {
          final atType = sniffed['@type'];
          debugPrint('[sniff] Map branch: @type raw=$atType (${atType?.runtimeType})'
              ', lowered=${atType?.toString().toLowerCase()}');
          isJsonLd =
              sniffed['@type']?.toString().toLowerCase() == 'recipe';
          debugPrint('[sniff] Map branch: isJsonLd=$isJsonLd');
        } else if (sniffed is List &&
            sniffed.isNotEmpty &&
            sniffed.first is Map<String, dynamic>) {
          final firstAtType =
              (sniffed.first as Map<String, dynamic>)['@type'];
          debugPrint('[sniff] List branch: first[@type] raw=$firstAtType'
              ' (${firstAtType?.runtimeType})'
              ', lowered=${firstAtType?.toString().toLowerCase()}');
          isJsonLd =
              (sniffed.first as Map<String, dynamic>)['@type']
                      ?.toString()
                      .toLowerCase() ==
                  'recipe';
          debugPrint('[sniff] List branch: isJsonLd=$isJsonLd');
        } else {
          debugPrint('[sniff] no @type branch matched: sniffed is '
              '${sniffed.runtimeType}, isEmpty=${sniffed is List ? (sniffed as List).isEmpty : "n/a"}');
        }

        if (isJsonLd) {
          debugPrint('[sniff] → routing to JsonLdParser');
          final summary = await JsonLdParser().parse(bytes);
          if (summary.recipes.isEmpty && summary.skippedCount == 0) {
            return ImportCompleted(imported: 0, skipped: 0);
          }
          return ImportNeedsReview(
            recipes: summary.recipes,
            parseSkipped: summary.skippedCount,
            failures: summary.failures,
            fileBytes: bytes,
            detectedParserName: 'RecipeSage / JSON-LD',
          );
        }
        // Priority 4: anything else → fall through to Memoix path as fallback.
        debugPrint('[sniff] → falling through to Memoix backup path');
      } else {
        debugPrint('[sniff] → routing to Memoix backup path (v1 format tag)');
      }
    } else {
      debugPrint('[sniff] sniffed is null — sniff failed, falling to Memoix path');
    }

    // Memoix backup path.
    // Handles: format "memoix/v1" wrapper, pre-v1 wrapper objects, bare arrays,
    // and files that failed JSON sniffing (let errors surface naturally).
    final String jsonString = utf8.decode(bytes);
    final jsonData = jsonDecode(jsonString);
    var count = 0;
    if (jsonData is Map<String, dynamic> && jsonData.containsKey('recipes')) {
      count = await _importRecipeList(jsonData['recipes'] as List);
      // Specialist domains — silently skipped when key absent (backward compatibility).
      if (jsonData['pizzas'] is List) count += await _importPizzas(jsonData['pizzas'] as List);
      if (jsonData['sandwiches'] is List) count += await _importSandwiches(jsonData['sandwiches'] as List);
      if (jsonData['smoking'] is List) count += await _importSmoking(jsonData['smoking'] as List);
      if (jsonData['modernist'] is List) count += await _importModernist(jsonData['modernist'] as List);
      if (jsonData['cellar'] is List) count += await _importCellar(jsonData['cellar'] as List);
      if (jsonData['cheese'] is List) count += await _importCheese(jsonData['cheese'] as List);
      if (jsonData['scratch'] is Map<String, dynamic>) await _importScratch(jsonData['scratch'] as Map<String, dynamic>);
    } else if (jsonData is List) {
      count = await _importRecipeList(jsonData);
    } else {
      throw Exception('Invalid backup file format');
    }
    return ImportCompleted(imported: count, skipped: 0);
  }

  Future<int> _importRecipeList(List recipesList) async {
    int imported = 0;

    for (final recipeJson in recipesList) {
      try {
        final recipe = Recipe.fromJson(recipeJson as Map<String, dynamic>);

        // Check if recipe already exists by UUID
        final existing = await _recipeRepository.getRecipeByUuid(recipe.uuid);
        if (existing != null) {
          // Update version to trigger merge
          recipe.version = existing.version + 1;
          recipe.id = existing.id; // Supply the local Drift PK so saveRecipe() performs an UPDATE, not an INSERT.
        }

        await _recipeRepository.saveRecipe(recipe, preserveSource: true);
        imported++;
      } catch (e) {
        // Skip invalid recipes, continue with others
        continue;
      }
    }

    return imported;
  }

  /// Export all recipes grouped by course to separate JSON files
  /// Returns the number of files exported, or null if cancelled
  /// 
  /// Exports ALL domains including:
  /// - Recipe courses (mains, desserts, drinks, etc.) - even if empty
  /// - Specialized domains: pizzas, sandwiches, smoking, modernist, cellar, cheese
  /// - Scratch pad (quick notes and recipe drafts)
  ///
  // Dev feature - Used for exporting recipes to be used a Memoix default recipes in the correct format
  Future<int?> exportByCourse() async {
    // On desktop, use folder picker
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder for course JSON files',
      );

      if (outputDir == null) {
        return null; // User cancelled
      }

      return _exportAllDomainsToDirectory(outputDir);
    }

    // On mobile, create files in documents and share
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/memoix_export');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create();

    final filesWritten = await _exportAllDomainsToDirectory(exportDir.path);
    
    // Collect all files for sharing
    final files = <XFile>[];
    await for (final entity in exportDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(XFile(entity.path));
      }
    }

    // Share all files
    if (files.isNotEmpty) {
      try {
        await SharePlus.instance.share(ShareParams(
          files: files,
          subject: 'Memoix Full Backup',
          text: 'Exported $filesWritten domain files',
        ),
        );
      } catch (e) {
        debugPrint('RecipeBackupService.exportByCourse error: $e');
        MemoixSnackBar.showError('Could not open share sheet. Please try again.');
      }
    }

    return filesWritten;
  }

  /// Export all domains to a directory
  /// Returns the number of files written
  Future<int> _exportAllDomainsToDirectory(String outputDir) async {
    int filesWritten = 0;

    // 1. Export all Recipe courses (including empty ones)
    final recipes = await _recipeRepository.getAllRecipes();
    final groupedRecipes = groupBy(recipes, (Recipe r) => r.course.toLowerCase());
    
    // Get all course slugs from defaults
    final allCourseSlugs = Course.defaults
        .map((c) => c.slug)
        .where((slug) => !_isSpecializedDomain(slug))
        .toList();
    
    for (final slug in allCourseSlugs) {
      final courseRecipes = groupedRecipes[slug] ?? [];
      courseRecipes.sort((a, b) => a.name.compareTo(b.name));
      
      final jsonList = courseRecipes.map((r) => r.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      
      final file = File('$outputDir/$slug.json');
      await file.writeAsString(jsonString);
      filesWritten++;
    }
    
    // Handle uncategorized recipes (if any)
    final uncategorized = groupedRecipes['uncategorized'] ?? [];
    if (uncategorized.isNotEmpty) {
      uncategorized.sort((a, b) => a.name.compareTo(b.name));
      final jsonList = uncategorized.map((r) => r.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      final file = File('$outputDir/uncategorized.json');
      await file.writeAsString(jsonString);
      filesWritten++;
    }

    // 2. Export Pizzas
    final pizzas = await _pizzaRepository.getAllPizzas();
    pizzas.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/pizzas.json', pizzas.map((p) => p.toJson()).toList());
    filesWritten++;

    // 3. Export Sandwiches
    final sandwiches = await _sandwichRepository.getAllSandwiches();
    sandwiches.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/sandwiches.json', sandwiches.map((s) => s.toJson()).toList());
    filesWritten++;

    // 4. Export Smoking
    final smokingRecipes = await _smokingRepository.getAllRecipes();
    smokingRecipes.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/smoking.json', smokingRecipes.map((s) => s.toJson()).toList());
    filesWritten++;

    // 5. Export Modernist
    final modernistRecipes = await _modernistRepository.getAll();
    modernistRecipes.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/modernist.json', modernistRecipes.map((m) => m.toJson()).toList());
    filesWritten++;

    // 6. Export Cellar
    final cellarEntries = await _cellarRepository.getAllEntries();
    cellarEntries.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/cellar.json', cellarEntries.map((c) => c.toJson()).toList());
    filesWritten++;

    // 7. Export Cheese
    final cheeseEntries = await _cheeseRepository.getAllEntries();
    cheeseEntries.sort((a, b) => a.name.compareTo(b.name));
    await _writeJsonFile('$outputDir/cheese.json', cheeseEntries.map((c) => c.toJson()).toList());
    filesWritten++;

    // 8. Export Scratch Pad
    final quickNotes = await _scratchPadRepository.getQuickNotes();
    final drafts = await _scratchPadRepository.getAllDrafts();
    final scratchData = {
      'quickNotes': quickNotes,
      'drafts': drafts.map((d) => <String, dynamic>{
        'uuid': d.uuid,
        'name': d.name,
        'imagePath': d.imagePath,
        'serves': d.serves,
        'time': d.time,
        'structuredIngredients': d.structuredIngredients,
        'structuredDirections': d.structuredDirections,
        'notes': d.notes,
        'createdAt': d.createdAt.toIso8601String(),
        'updatedAt': d.updatedAt.toIso8601String(),
      },).toList(),
    };
    await _writeJsonFile('$outputDir/scratch.json', scratchData);
    filesWritten++;

    return filesWritten;
  }

  /// Check if a course slug is a specialized domain (has its own model)
  bool _isSpecializedDomain(String slug) {
    return const ['pizzas', 'sandwiches', 'smoking', 'modernist', 'cellar', 'cheese', 'scratch'].contains(slug);
  }

  /// Write JSON data to a file
  Future<void> _writeJsonFile(String path, dynamic data) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final file = File(path);
    await file.writeAsString(jsonString);
  }

  // ── Per-domain import helpers ─────────────────────────────────────────────
  // Called from importRecipes() when a specialist domain key is present in the
  // backup file.

  Future<int> _importPizzas(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        var pizza = pizzaFromJson(json);
        if (pizza.source == PizzaSource.memoix.name) {
          pizza = pizza.copyWith(source: PizzaSource.imported.name);
        }
        final existing = await _pizzaRepository.getPizzaByUuid(pizza.uuid);
        if (existing != null) {
          pizza = pizza.copyWith(version: existing.version + 1, id: existing.id);
        }
        await _pizzaRepository.savePizza(pizza);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importSandwiches(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        var sandwich = sandwichFromJson(json);
        if (sandwich.source == SandwichSource.memoix.name) {
          sandwich = sandwich.copyWith(source: SandwichSource.imported.name);
        }
        final existing = await _sandwichRepository.getSandwichByUuid(sandwich.uuid);
        if (existing != null) {
          sandwich = sandwich.copyWith(version: existing.version + 1, id: existing.id);
        }
        await _sandwichRepository.saveSandwich(sandwich);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importSmoking(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        var recipe = smokingRecipeFromJson(json);
        if (recipe.source == SmokingSource.memoix.name) {
          recipe = recipe.copyWith(source: SmokingSource.imported.name);
        }
        final existing = await _smokingRepository.getRecipeByUuid(recipe.uuid);
        if (existing != null) recipe = recipe.copyWith(id: existing.id);
        await _smokingRepository.saveRecipe(recipe);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importModernist(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        final recipe = ModernistRecipe.fromJson(json);
        if (recipe.source == ModernistSource.memoix) recipe.source = ModernistSource.imported;
        final existing = await _modernistRepository.getByUuid(recipe.uuid);
        if (existing != null) recipe.id = existing.id;
        await _modernistRepository.save(recipe);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importCellar(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        var entry = cellarEntryFromJson(json);
        if (entry.source == CellarSource.personal.name) {
          entry = entry.copyWith(source: CellarSource.imported.name);
        }
        final existing = await _cellarRepository.getEntryByUuid(entry.uuid);
        if (existing != null) {
          entry = entry.copyWith(version: existing.version + 1, id: existing.id);
        }
        await _cellarRepository.saveEntry(entry);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importCheese(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      if (json is! Map<String, dynamic>) continue;
      try {
        var entry = cheeseEntryFromJson(json);
        if (entry.source == CheeseSource.personal.name) {
          entry = entry.copyWith(source: CheeseSource.imported.name);
        }
        final existing = await _cheeseRepository.getEntryByUuid(entry.uuid);
        if (existing != null) {
          entry = entry.copyWith(version: existing.version + 1, id: existing.id);
        }
        await _cheeseRepository.saveEntry(entry);
        imported++;
      } catch (e) { debugPrint('domain import error: $e'); continue; }
    }
    return imported;
  }

  Future<int> _importScratch(Map<String, dynamic> json) async {
    int imported = 0;
    final quickNotes = json['quickNotes'] as String?;
    if (quickNotes != null && quickNotes.isNotEmpty) {
      await _scratchPadRepository.saveQuickNotes(quickNotes);
      imported++;
    }
    final drafts = json['drafts'] as List?;
    if (drafts != null) {
      for (final draftJson in drafts) {
        try {
          final draft = RecipeDraft(
            id: 0,
            uuid: draftJson['uuid'] as String? ?? '',
            name: draftJson['name'] as String? ?? '',
            imagePath: draftJson['imagePath'] as String?,
            serves: draftJson['serves'] as String?,
            time: draftJson['time'] as String?,
            course: draftJson['course'] as String? ?? 'mains',
            structuredIngredients: draftJson['structuredIngredients'] as String? ?? '[]',
            structuredDirections: draftJson['structuredDirections'] as String? ?? '[]',
            legacyIngredients: null,
            legacyDirections: null,
            notes: draftJson['notes'] as String? ?? '',
            stepImages: '[]',
            stepImageMap: '[]',
            pairedRecipeIds: '[]',
            createdAt: draftJson['createdAt'] != null
                ? DateTime.parse(draftJson['createdAt'] as String)
                : DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _scratchPadRepository.updateDraft(draft);
          imported++;
        } catch (_) { continue; }
      }
    }
    return imported;
  }
}

// Provider
final recipeBackupServiceProvider = Provider<RecipeBackupService>((ref) {
  return RecipeBackupService(
    ref.watch(recipeRepositoryProvider),
    ref.watch(pizzaRepositoryProvider),
    ref.watch(sandwichRepositoryProvider),
    ref.watch(smokingRepositoryProvider),
    ref.watch(modernistRepositoryProvider),
    ref.watch(cellarRepositoryProvider),
    ref.watch(cheeseRepositoryProvider),
    ref.watch(scratchPadRepositoryProvider),
  );
});
