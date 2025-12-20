import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';

/// Service for exporting and importing recipes as JSON backup files
class RecipeBackupService {
  final RecipeRepository _repository;

  RecipeBackupService(this._repository);

  /// Export all personal recipes to a JSON file
  /// Returns the path to the exported file or null if cancelled/failed
  Future<String?> exportRecipes({bool includeAll = false}) async {
    // Get recipes to export
    List<Recipe> recipes;
    if (includeAll) {
      recipes = await _repository.getAllRecipes();
    } else {
      // Only personal recipes (not memoix collection)
      recipes = await _repository.getPersonalRecipes();
      final imported = await _repository.getImportedRecipes();
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
        final existing = await _repository.getRecipeByUuid(recipe.uuid);
        if (existing != null) {
          // Update version to trigger merge
          recipe.version = existing.version + 1;
          recipe.id = existing.id; // Keep the same Isar ID
        }
        
        await _repository.saveRecipe(recipe);
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
  // TODO(release): Remove this method before public release - dev/maintenance only
  Future<int?> exportByCourse() async {
    // Get ALL recipes including Memoix collection
    final recipes = await _repository.getAllRecipes();

    if (recipes.isEmpty) {
      throw Exception('No recipes to export');
    }

    // Group recipes by course
    final grouped = groupBy(recipes, (Recipe r) => r.course?.toLowerCase() ?? 'uncategorized');

    // On desktop, use folder picker
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder for course JSON files',
      );

      if (outputDir == null) {
        return null; // User cancelled
      }

      int filesWritten = 0;
      for (final entry in grouped.entries) {
        final course = entry.key;
        final courseRecipes = entry.value;

        // Sort by name for consistency
        courseRecipes.sort((a, b) => a.name.compareTo(b.name));

        // Convert to JSON array (matching existing format)
        final jsonList = courseRecipes.map((r) => r.toJson()).toList();
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

        final file = File('$outputDir/$course.json');
        await file.writeAsString(jsonString);
        filesWritten++;
      }

      return filesWritten;
    }

    // On mobile, create files in documents and share as zip or individual files
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/memoix_export');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create();

    final files = <XFile>[];
    for (final entry in grouped.entries) {
      final course = entry.key;
      final courseRecipes = entry.value;

      courseRecipes.sort((a, b) => a.name.compareTo(b.name));

      final jsonList = courseRecipes.map((r) => r.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final file = File('${exportDir.path}/$course.json');
      await file.writeAsString(jsonString);
      files.add(XFile(file.path));
    }

    // Share all files
    await Share.shareXFiles(
      files,
      subject: 'Memoix Recipe Export by Course',
      text: 'Exported ${recipes.length} recipes across ${files.length} course files',
    );

    return files.length;
  }
}

// Provider
final recipeBackupServiceProvider = Provider<RecipeBackupService>((ref) {
  return RecipeBackupService(ref.watch(recipeRepositoryProvider));
});
