import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// One-time migration service that copies local image files into the
/// `recipe_images` blob table (schema v2).
///
/// Safe to call on every app launch — exits immediately if already complete.
/// Any failure is non-fatal: it is logged and the process continues.
class ImageMigrationService {
  ImageMigrationService._();

  static const _prefKey = 'image_migration_v2_complete';

  /// Run the migration if it has not already been completed.
  static Future<void> runIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) == true) return;

      final db = AppDatabase.instance;
      final recipes = await db.recipeDao.getAllRecipes();

      for (final recipe in recipes) {
        await _processRecipe(db, recipe);
      }

      await prefs.setBool(_prefKey, true);
      debugPrint('ImageMigrationService: completed for ${recipes.length} recipes');
    } catch (e, st) {
      debugPrint('ImageMigrationService: non-fatal error — $e\n$st');
    }
  }

  static Future<void> _processRecipe(AppDatabase db, Recipe recipe) async {
    // Header image
    if (_isLocalPath(recipe.headerImage)) {
      await _saveBlob(
        db: db,
        recipeId: recipe.id,
        filePath: recipe.headerImage!,
        imageType: 'header',
        stepIndex: null,
      );
    }

    // Step images (JSON-encoded List<String>)
    try {
      final stepList = (jsonDecode(recipe.stepImages) as List).cast<String>();
      for (var i = 0; i < stepList.length; i++) {
        if (_isLocalPath(stepList[i])) {
          await _saveBlob(
            db: db,
            recipeId: recipe.id,
            filePath: stepList[i],
            imageType: 'step',
            stepIndex: i,
          );
        }
      }
    } catch (_) {
      // Malformed JSON — skip silently
    }

    // Gallery images (imageUrls — JSON-encoded List<String>)
    try {
      final galleryList = (jsonDecode(recipe.imageUrls) as List).cast<String>();
      for (final path in galleryList) {
        if (_isLocalPath(path)) {
          await _saveBlob(
            db: db,
            recipeId: recipe.id,
            filePath: path,
            imageType: 'gallery',
            stepIndex: null,
          );
        }
      }
    } catch (_) {
      // Malformed JSON — skip silently
    }
  }

  static Future<void> _saveBlob({
    required AppDatabase db,
    required int recipeId,
    required String filePath,
    required String imageType,
    required int? stepIndex,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final fileName = p.basename(filePath);
      final mimeType =
          fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      await db.imageDao.saveImage(RecipeImagesCompanion(
        recipeId: Value(recipeId),
        fileName: Value(fileName),
        imageType: Value(imageType),
        stepIndex: Value(stepIndex),
        imageData: Value(bytes),
        mimeType: Value(mimeType),
        createdAt: Value(DateTime.now().toUtc()),
      ),);
    } catch (e) {
      debugPrint(
          'ImageMigrationService: skipping $filePath for recipe $recipeId — $e',);
    }
  }

  /// Returns true if [path] is a non-empty local file system path
  /// (i.e. not a remote URL and not null/empty).
  static bool _isLocalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return !path.startsWith('http://') && !path.startsWith('https://');
  }
}
