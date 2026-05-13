import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// Background utility that removes local image files from `recipe_images/`
/// that are no longer referenced by any row in any domain table.
///
/// Safe to call on every app launch — always runs a fresh scan.
/// Any failure is non-fatal: it is logged and execution continues.
class OrphanedImageCleanupService {
  OrphanedImageCleanupService._();

  /// Scan the `recipe_images/` directory and delete any `.jpg` or `.png` file
  /// whose basename is not referenced by any domain table.
  ///
  /// File deletion is performed off the main thread via [Isolate.run].
  static Future<void> run() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(p.join(appDir.path, 'recipe_images'));

      if (!await imageDir.exists()) return;

      final validFilenames = await _buildValidFilenameSet();

      final dirPath = imageDir.path;
      final deleted = await Isolate.run(
        () => _deleteOrphanedFiles(dirPath, validFilenames),
      );

      debugPrint(
        'OrphanedImageCleanupService: deleted $deleted orphaned file(s).',
      );
    } catch (e, st) {
      debugPrint('OrphanedImageCleanupService: non-fatal error — $e\n$st');
    }
  }

  // ─── Valid filename set builder ───────────────────────────────────────────

  /// Queries all domain tables and returns the set of valid basenames.
  static Future<Set<String>> _buildValidFilenameSet() async {
    final db = AppDatabase.instance;
    final valid = <String>{};

    // RecipeImages blob table — filenames are already plain names.
    final imageRows = await db.select(db.recipeImages).get();
    for (final row in imageRows) {
      valid.add(row.fileName);
    }

    // Recipes (covers Modernist — no separate table).
    final recipes = await db.recipeDao.getAllRecipes();
    for (final r in recipes) {
      _addBasename(valid, r.headerImage);
      _addBasename(valid, r.imageUrl);
      _addAllFromJson(valid, r.imageUrls);
      _addAllFromJson(valid, r.stepImages);
    }

    // RecipeDrafts — protect in-progress draft images from deletion.
    final drafts = await db.select(db.recipeDrafts).get();
    for (final d in drafts) {
      _addBasename(valid, d.imagePath);
      _addAllFromJson(valid, d.stepImages);
    }

    // Pizzas.
    final pizzas = await db.select(db.pizzas).get();
    for (final row in pizzas) {
      _addBasename(valid, row.imageUrl);
    }

    // Sandwiches.
    final sandwiches = await db.select(db.sandwiches).get();
    for (final row in sandwiches) {
      _addBasename(valid, row.imageUrl);
    }

    // SmokingRecipes.
    final smokingRecipes = await db.select(db.smokingRecipes).get();
    for (final row in smokingRecipes) {
      _addBasename(valid, row.headerImage);
      _addBasename(valid, row.imageUrl);
      _addAllFromJson(valid, row.stepImages);
    }

    // CellarEntries.
    final cellarEntries = await db.select(db.cellarEntries).get();
    for (final row in cellarEntries) {
      _addBasename(valid, row.imageUrl);
    }

    // CheeseEntries.
    final cheeseEntries = await db.select(db.cheeseEntries).get();
    for (final row in cheeseEntries) {
      _addBasename(valid, row.imageUrl);
    }

    return valid;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Extracts the basename from [path] and adds it to [set].
  ///
  /// Skips nulls, blank strings, and remote URLs (http/https) to avoid
  /// treating URL path segments as local filenames.
  static void _addBasename(Set<String> set, String? path) {
    if (path == null || path.isEmpty) return;
    if (path.startsWith('http://') || path.startsWith('https://')) return;
    final name = p.basename(path);
    if (name.isNotEmpty) set.add(name);
  }

  /// Parses a JSON-encoded `List<String>` and calls [_addBasename] on each
  /// element. Silently ignores malformed JSON (mirrors existing convention).
  static void _addAllFromJson(Set<String> set, String? json) {
    if (json == null || json.isEmpty || json == '[]') return;
    try {
      final list = (jsonDecode(json) as List).cast<String>();
      for (final path in list) {
        _addBasename(set, path);
      }
    } catch (_) {
      // Malformed JSON — skip silently.
    }
  }

  // ─── Isolate worker ──────────────────────────────────────────────────────

  /// Deletes every `.jpg` / `.png` file in [dirPath] whose basename is absent
  /// from [validFilenames]. Returns the count of deleted files.
  ///
  /// Runs in a separate isolate to keep the main thread free.
  static int _deleteOrphanedFiles(
    String dirPath,
    Set<String> validFilenames,
  ) {
    var deleted = 0;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.jpg' && ext != '.png') continue;

      final name = p.basename(entity.path);
      if (!validFilenames.contains(name)) {
        entity.deleteSync();
        deleted++;
      }
    }
    return deleted;
  }
}
