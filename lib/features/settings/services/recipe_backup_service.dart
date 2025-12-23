import 'dart:convert';
import 'dart:io';
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
import '../../notes/models/scratch_pad.dart';
import '../../notes/repository/scratch_pad_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/repository/smoking_repository.dart';

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
      // Only personal recipes (not memoix collection)
      recipes = await _recipeRepository.getPersonalRecipes();
      final imported = await _recipeRepository.getImportedRecipes();
      recipes = [...recipes, ...imported];
    }

    if (recipes.isEmpty) {
      throw Exception('No recipes to export');
    }

    // Convert to JSON
    final jsonData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'recipeCount': recipes.length,
      'recipes': recipes.map((r) => r.toJson()).toList(),
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
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Memoix Recipe Backup',
      text: 'Exported ${recipes.length} recipe${recipes.length == 1 ? '' : 's'}',
    );

    return file.path;
  }

  /// Import recipes from a JSON file
  /// Returns the number of recipes imported
  Future<int> importRecipes() async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return 0;
    }

    final file = result.files.first;
    String jsonString;

    // Read file content
    if (file.path != null) {
      jsonString = await File(file.path!).readAsString();
    } else if (file.bytes != null) {
      jsonString = utf8.decode(file.bytes!);
    } else {
      throw Exception('Could not read file');
    }

    // Parse JSON
    final jsonData = jsonDecode(jsonString);

    if (jsonData is! Map || !jsonData.containsKey('recipes')) {
      // Try parsing as a simple array of recipes
      if (jsonData is List) {
        return _importRecipeList(jsonData);
      }
      throw Exception('Invalid backup file format');
    }

    final recipesList = jsonData['recipes'] as List;
    return _importRecipeList(recipesList);
  }

  Future<int> _importRecipeList(List recipesList) async {
    int imported = 0;

    for (final recipeJson in recipesList) {
      try {
        final recipe = Recipe.fromJson(recipeJson as Map<String, dynamic>);
        
        // Mark as imported unless it was personal
        if (recipe.source == RecipeSource.memoix) {
          recipe.source = RecipeSource.imported;
        }
        
        // Check if recipe already exists by UUID
        final existing = await _recipeRepository.getRecipeByUuid(recipe.uuid);
        if (existing != null) {
          // Update version to trigger merge
          recipe.version = existing.version + 1;
          recipe.id = existing.id; // Keep the same Isar ID
        }
        
        await _recipeRepository.saveRecipe(recipe);
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
  // TODO(release): Remove this method before public release - dev/maintenance only
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
      await Share.shareXFiles(
        files,
        subject: 'Memoix Full Backup',
        text: 'Exported $filesWritten domain files',
      );
    }

    return filesWritten;
  }

  /// Export all domains to a directory
  /// Returns the number of files written
  Future<int> _exportAllDomainsToDirectory(String outputDir) async {
    int filesWritten = 0;

    // 1. Export all Recipe courses (including empty ones)
    final recipes = await _recipeRepository.getAllRecipes();
    final groupedRecipes = groupBy(recipes, (Recipe r) => r.course?.toLowerCase() ?? 'uncategorized');
    
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
      'drafts': drafts.map((d) => {
        return {
          'uuid': d.uuid,
          'name': d.name,
          'imagePath': d.imagePath,
          'serves': d.serves,
          'time': d.time,
          'ingredients': d.ingredients,
          'directions': d.directions,
          'comments': d.comments,
          'createdAt': d.createdAt.toIso8601String(),
          'updatedAt': d.updatedAt.toIso8601String(),
        };
      }).toList(),
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

  /// Import all domains from a folder of JSON files
  /// Returns a map of domain -> count imported
  Future<Map<String, int>> importFromFolder() async {
    final result = <String, int>{};

    // On desktop, use folder picker
    String? inputDir;
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      inputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder containing JSON backup files',
      );
    } else {
      // On mobile, pick multiple files
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
      );
      
      if (pickResult == null || pickResult.files.isEmpty) {
        return result;
      }
      
      // Process each picked file
      for (final file in pickResult.files) {
        if (file.path == null) continue;
        final filename = file.name.toLowerCase().replaceAll('.json', '');
        final count = await _importDomainFile(File(file.path!), filename);
        if (count > 0) {
          result[filename] = count;
        }
      }
      return result;
    }

    if (inputDir == null) {
      return result;
    }

    // Read all JSON files in the directory
    final dir = Directory(inputDir);
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.path.split(Platform.pathSeparator).last.toLowerCase().replaceAll('.json', '');
        final count = await _importDomainFile(entity, filename);
        if (count > 0) {
          result[filename] = count;
        }
      }
    }

    return result;
  }

  /// Import a single domain file
  /// Returns count of items imported
  Future<int> _importDomainFile(File file, String domain) async {
    try {
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      switch (domain) {
        case 'pizzas':
          return _importPizzas(jsonData as List);
        case 'sandwiches':
          return _importSandwiches(jsonData as List);
        case 'smoking':
          return _importSmoking(jsonData as List);
        case 'modernist':
          return _importModernist(jsonData as List);
        case 'cellar':
          return _importCellar(jsonData as List);
        case 'cheese':
          return _importCheese(jsonData as List);
        case 'scratch':
          return _importScratch(jsonData as Map<String, dynamic>);
        default:
          // Assume it's a recipe course file
          if (jsonData is List) {
            return _importRecipeList(jsonData);
          }
          return 0;
      }
    } catch (e) {
      // Skip files that fail to parse
      return 0;
    }
  }

  /// Import pizzas from JSON array
  Future<int> _importPizzas(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final pizza = Pizza.fromJson(json as Map<String, dynamic>);
        if (pizza.source == PizzaSource.memoix) {
          pizza.source = PizzaSource.imported;
        }
        final existing = await _pizzaRepository.getPizzaByUuid(pizza.uuid);
        if (existing != null) {
          pizza.version = existing.version + 1;
          pizza.id = existing.id;
        }
        await _pizzaRepository.savePizza(pizza);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import sandwiches from JSON array
  Future<int> _importSandwiches(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final sandwich = Sandwich.fromJson(json as Map<String, dynamic>);
        if (sandwich.source == SandwichSource.memoix) {
          sandwich.source = SandwichSource.imported;
        }
        final existing = await _sandwichRepository.getSandwichByUuid(sandwich.uuid);
        if (existing != null) {
          sandwich.version = existing.version + 1;
          sandwich.id = existing.id;
        }
        await _sandwichRepository.saveSandwich(sandwich);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import smoking recipes from JSON array
  Future<int> _importSmoking(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final recipe = SmokingRecipe.fromJson(json as Map<String, dynamic>);
        if (recipe.source == SmokingSource.memoix) {
          recipe.source = SmokingSource.imported;
        }
        final existing = await _smokingRepository.getRecipeByUuid(recipe.uuid);
        if (existing != null) {
          recipe.id = existing.id;
        }
        await _smokingRepository.saveRecipe(recipe);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import modernist recipes from JSON array
  Future<int> _importModernist(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final recipe = ModernistRecipe.fromJson(json as Map<String, dynamic>);
        if (recipe.source == ModernistSource.memoix) {
          recipe.source = ModernistSource.imported;
        }
        final existing = await _modernistRepository.getByUuid(recipe.uuid);
        if (existing != null) {
          recipe.id = existing.id;
        }
        await _modernistRepository.save(recipe);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import cellar entries from JSON array
  Future<int> _importCellar(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final entry = CellarEntry.fromJson(json as Map<String, dynamic>);
        if (entry.source == CellarSource.personal) {
          entry.source = CellarSource.imported;
        }
        final existing = await _cellarRepository.getEntryByUuid(entry.uuid);
        if (existing != null) {
          entry.version = existing.version + 1;
          entry.id = existing.id;
        }
        await _cellarRepository.saveEntry(entry);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import cheese entries from JSON array
  Future<int> _importCheese(List jsonList) async {
    int imported = 0;
    for (final json in jsonList) {
      try {
        final entry = CheeseEntry.fromJson(json as Map<String, dynamic>);
        if (entry.source == CheeseSource.personal) {
          entry.source = CheeseSource.imported;
        }
        final existing = await _cheeseRepository.getEntryByUuid(entry.uuid);
        if (existing != null) {
          entry.version = existing.version + 1;
          entry.id = existing.id;
        }
        await _cheeseRepository.saveEntry(entry);
        imported++;
      } catch (_) {
        continue;
      }
    }
    return imported;
  }

  /// Import scratch pad data from JSON object
  Future<int> _importScratch(Map<String, dynamic> json) async {
    int imported = 0;
    
    // Import quick notes
    final quickNotes = json['quickNotes'] as String?;
    if (quickNotes != null && quickNotes.isNotEmpty) {
      await _scratchPadRepository.saveQuickNotes(quickNotes);
      imported++;
    }
    
    // Import drafts
    final drafts = json['drafts'] as List?;
    if (drafts != null) {
      for (final draftJson in drafts) {
        try {
          final draft = RecipeDraft()
            ..uuid = draftJson['uuid'] as String
            ..name = draftJson['name'] as String? ?? ''
            ..imagePath = draftJson['imagePath'] as String?
            ..serves = draftJson['serves'] as String?
            ..time = draftJson['time'] as String?
            ..ingredients = draftJson['ingredients'] as String? ?? ''
            ..directions = draftJson['directions'] as String? ?? ''
            ..comments = draftJson['comments'] as String? ?? '';
          
          if (draftJson['createdAt'] != null) {
            draft.createdAt = DateTime.parse(draftJson['createdAt'] as String);
          }
          if (draftJson['updatedAt'] != null) {
            draft.updatedAt = DateTime.parse(draftJson['updatedAt'] as String);
          }
          
          await _scratchPadRepository.updateDraft(draft);
          imported++;
        } catch (_) {
          continue;
        }
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
