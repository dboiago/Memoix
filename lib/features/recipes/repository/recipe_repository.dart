import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart'
    hide Recipe, Ingredient, Course;
import '../../../core/database/app_database.dart' as db
    show Recipe, Ingredient, Course;
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/utils/suggestions.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../../personal_storage/services/tombstone_store.dart';
import '../models/course.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level isolate helpers (must be top-level so Isolate.run can capture them)
// ─────────────────────────────────────────────────────────────────────────────

/// Groups a flat list of [db.Ingredient] rows by [recipeId].
Map<int, List<db.Ingredient>> _groupIngredientsByRecipe(
    List<db.Ingredient> allIngs) {
  final grouped = <int, List<db.Ingredient>>{};
  for (final ing in allIngs) {
    grouped.putIfAbsent(ing.recipeId, () => []).add(ing);
  }
  return grouped;
}

/// Synchronously resolves an image value against the on-disk cache.
/// Returns the absolute cache path when the file exists, otherwise returns
/// [value] unchanged (bare filename) so the main thread can do a DB lookup.
String _resolvePathSync(String value, String cacheBasePath) {
  if (value.startsWith('http')) return value;
  if (value.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(value)) {
    return value;
  }
  final cached = File('$cacheBasePath/$value');
  return cached.existsSync() ? cached.path : value;
}

String? _resolvePathSyncNullable(String? value, String cacheBasePath) {
  if (value == null || value.isEmpty) return value;
  return _resolvePathSync(value, cacheBasePath);
}

/// Runs inside [Isolate.run].
/// Performs all JSON-heavy decoding and model construction for a batch of
/// recipe rows, then does a synchronous [File.existsSync] cache check for
/// each image value. Images that are already in the on-disk cache are replaced
/// with their absolute path. Images that are not yet cached remain as bare
/// filenames so [RecipeRepository._finalizeImagePaths] can complete them on
/// the main thread with a DB-only existence check (no BLOB read needed on the
/// hot path).
///
/// Returns [null] in the output list for any recipe that fails to decode so
/// a single corrupt row never aborts the entire batch.
List<Recipe?> _batchDecodeRecipes(
    ({
      List<db.Recipe> rawRecipes,
      Map<int, List<db.Ingredient>> grouped,
      String cacheBasePath,
    }) args) {
  final result = <Recipe?>[];
  for (final r in args.rawRecipes) {
    try {
      final ings = args.grouped[r.id] ?? [];
      final recipe = Recipe()
        ..id = r.id
        ..uuid = r.uuid
        ..name = r.name
        ..course = r.course
        ..cuisine = r.cuisine
        ..subcategory = r.subcategory
        ..continent = r.continent
        ..country = r.country
        ..serves = r.serves
        ..time = r.time
        ..pairsWith =
            (jsonDecode(r.pairsWith) as List).cast<String>()
        ..pairedRecipeIds =
            (jsonDecode(r.pairedRecipeIds) as List).cast<String>()
        ..comments = r.comments
        ..directions =
            (jsonDecode(r.directions) as List).cast<String>()
        ..sourceUrl = r.sourceUrl
        ..imageUrls =
            (jsonDecode(r.imageUrls) as List).cast<String>()
        ..imageUrl = r.imageUrl
        ..headerImage = r.headerImage
        ..stepImages =
            (jsonDecode(r.stepImages) as List).cast<String>()
        ..stepImageMap =
            (jsonDecode(r.stepImageMap) as List).cast<String>()
        ..source = RecipeSource.values.firstWhere(
              (s) => s.name == r.source,
              orElse: () => RecipeSource.personal)
        ..colorValue = r.colorValue
        ..createdAt = r.createdAt
        ..updatedAt = r.updatedAt
        ..isFavorite = r.isFavorite
        ..rating = r.rating
        ..cookCount = r.cookCount
        ..editCount = r.editCount
        ..firstEditAt = r.firstEditAt
        ..lastEditAt = r.lastEditAt
        ..lastCookedAt = r.lastCookedAt
        ..tags = (jsonDecode(r.tags) as List).cast<String>()
        ..version = r.version
        ..nutrition = r.nutrition != null
            ? NutritionInfo.fromJson(
                jsonDecode(r.nutrition!) as Map<String, dynamic>)
            : null
        ..modernistType = r.modernistType
        ..smokingType = r.smokingType
        ..glass = r.glass
        ..garnish = (jsonDecode(r.garnish) as List).cast<String>()
        ..pickleMethod = r.pickleMethod
        ..ingredients = ings
            .map((i) => Ingredient()
              ..uuid = i.uuid
              ..name = i.name
              ..amount = i.amount
              ..unit = i.unit
              ..preparation = i.notes
              ..alternative = i.alternative
              ..isOptional = i.isOptional
              ..section = i.section
              ..bakerPercent = i.bakerPercent)
            .toList();

      // Resolve image paths that are already in the on-disk cache.
      // Bare filenames that miss the cache are left unchanged for the
      // main-thread _finalizeImagePaths step.
      recipe.headerImage =
          _resolvePathSyncNullable(recipe.headerImage, args.cacheBasePath);
      recipe.stepImages = recipe.stepImages
          .map((v) => _resolvePathSync(v, args.cacheBasePath))
          .toList();
      recipe.imageUrls = recipe.imageUrls
          .map((v) => _resolvePathSync(v, args.cacheBasePath))
          .toList();

      result.add(recipe);
    } catch (_) {
      result.add(null);
    }
  }
  return result;
}

/// Repository for recipe data operations
class RecipeRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  RecipeRepository(this._db, this._ref);

  // ============ PRIVATE HELPERS ============

  RecipesCompanion _toCompanion(Recipe recipe) {
    return RecipesCompanion(
      id: recipe.id > 0 ? Value(recipe.id) : const Value.absent(),
      uuid: Value(recipe.uuid),
      name: Value(recipe.name),
      course: Value(recipe.course),
      cuisine: Value(recipe.cuisine),
      subcategory: Value(recipe.subcategory),
      continent: Value(recipe.continent),
      country: Value(recipe.country),
      serves: Value(recipe.serves),
      time: Value(recipe.time),
      pairsWith: Value(jsonEncode(recipe.pairsWith)),
      pairedRecipeIds: Value(jsonEncode(recipe.pairedRecipeIds)),
      comments: Value(recipe.comments),
      directions: Value(jsonEncode(recipe.directions)),
      sourceUrl: Value(recipe.sourceUrl),
      imageUrls: Value(jsonEncode(recipe.imageUrls)),
      imageUrl: Value(recipe.imageUrl),
      headerImage: Value(recipe.headerImage),
      stepImages: Value(jsonEncode(recipe.stepImages)),
      stepImageMap: Value(jsonEncode(recipe.stepImageMap)),
      source: Value(recipe.source.name),
      colorValue: Value(recipe.colorValue),
      createdAt: Value(recipe.createdAt),
      updatedAt: Value(recipe.updatedAt),
      isFavorite: Value(recipe.isFavorite),
      rating: Value(recipe.rating),
      cookCount: Value(recipe.cookCount),
      editCount: Value(recipe.editCount),
      firstEditAt: Value(recipe.firstEditAt),
      lastEditAt: Value(recipe.lastEditAt),
      lastCookedAt: Value(recipe.lastCookedAt),
      tags: Value(jsonEncode(recipe.tags)),
      version: Value(recipe.version),
      nutrition: Value(recipe.nutrition != null ? jsonEncode(recipe.nutrition!.toJson()) : null),
      modernistType: Value(recipe.modernistType),
      smokingType: Value(recipe.smokingType),
      glass: Value(recipe.glass),
      garnish: Value(jsonEncode(recipe.garnish)),
      pickleMethod: Value(recipe.pickleMethod),
      recipeType: const Value('standard'),
      technique: const Value(null),
      difficulty: const Value(null),
      scienceNotes: const Value(null),
      equipmentJson: const Value(null),
    );
  }

  List<IngredientsCompanion> _toIngredientCompanions(
      int recipeId, List<Ingredient> ingredients) {
    return ingredients
        .map((i) => IngredientsCompanion(
              uuid: Value(i.uuid.trim().isNotEmpty ? i.uuid : _uuid.v4()),
              recipeId: Value(recipeId),
              name: Value(i.name),
              amount: Value(i.amount),
              unit: Value(i.unit),
              notes: Value(i.preparation),
              alternative: Value(i.alternative),
              isOptional: Value(i.isOptional),
              section: Value(i.section),
              bakerPercent: Value(i.bakerPercent),
            ))
        .toList();
  }

  Future<Recipe> _toIsarRecipe(db.Recipe r, List<db.Ingredient> ings) async {
    final recipe = Recipe()
      ..id = r.id
      ..uuid = r.uuid
      ..name = r.name
      ..course = r.course
      ..cuisine = r.cuisine
      ..subcategory = r.subcategory
      ..continent = r.continent
      ..country = r.country
      ..serves = r.serves
      ..time = r.time
      ..pairsWith = (jsonDecode(r.pairsWith) as List).cast<String>()
      ..pairedRecipeIds = (jsonDecode(r.pairedRecipeIds) as List).cast<String>()
      ..comments = r.comments
      ..directions = (jsonDecode(r.directions) as List).cast<String>()
      ..sourceUrl = r.sourceUrl
      ..imageUrls = (jsonDecode(r.imageUrls) as List).cast<String>()
      ..imageUrl = r.imageUrl
      ..headerImage = r.headerImage
      ..stepImages = (jsonDecode(r.stepImages) as List).cast<String>()
      ..stepImageMap = (jsonDecode(r.stepImageMap) as List).cast<String>()
      ..source = RecipeSource.values.firstWhere(
            (s) => s.name == r.source,
            orElse: () => RecipeSource.personal)
      ..colorValue = r.colorValue
      ..createdAt = r.createdAt
      ..updatedAt = r.updatedAt
      ..isFavorite = r.isFavorite
      ..rating = r.rating
      ..cookCount = r.cookCount
      ..editCount = r.editCount
      ..firstEditAt = r.firstEditAt
      ..lastEditAt = r.lastEditAt
      ..lastCookedAt = r.lastCookedAt
      ..tags = (jsonDecode(r.tags) as List).cast<String>()
      ..version = r.version
      ..nutrition = r.nutrition != null
          ? NutritionInfo.fromJson(jsonDecode(r.nutrition!) as Map<String, dynamic>)
          : null
      ..modernistType = r.modernistType
      ..smokingType = r.smokingType
      ..glass = r.glass
      ..garnish = (jsonDecode(r.garnish) as List).cast<String>()
      ..pickleMethod = r.pickleMethod
      ..ingredients = ings
          .map((i) => Ingredient()
            ..uuid = i.uuid
            ..name = i.name
            ..amount = i.amount
            ..unit = i.unit
            ..preparation = i.notes
            ..alternative = i.alternative
            ..isOptional = i.isOptional
            ..section = i.section
            ..bakerPercent = i.bakerPercent)
          .toList();

    // Resolve plain filenames → cached local paths from the blob store.
    recipe.headerImage = await _resolveNullableImagePath(recipe.headerImage);
    recipe.stepImages = await Future.wait(
        recipe.stepImages.map((v) => _resolveImagePath(v)));
    recipe.imageUrls = await Future.wait(
        recipe.imageUrls.map((v) => _resolveImagePath(v)));

    return recipe;
  }

  void _normalizeIngredientUnits(Recipe recipe) {
    UnitNormalizer.normalizeUnitsInList(recipe.ingredients);
  }

  // ── Image helpers ──────────────────────────────────────────────────────────

  /// True for absolute file-system paths (Unix leading-slash or Windows
  /// drive-letter prefix).
  bool _isAbsolutePath(String value) =>
      value.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(value);

  /// Replaces absolute-path image values in [recipe] with their basenames and
  /// records the original paths in [out] so blobs can be persisted afterwards.
  void _collectAndNormaliseImagePaths(
      Recipe recipe, Map<String, String> out) {
    String? normalise(String? value) {
      if (value == null || value.isEmpty || value.startsWith('http')) {
        return value;
      }
      if (!_isAbsolutePath(value)) return value; // already a basename
      final fileName = p.basename(value);
      out[fileName] = value;
      return fileName;
    }

    recipe.headerImage = normalise(recipe.headerImage);

    for (int i = 0; i < recipe.stepImages.length; i++) {
      recipe.stepImages[i] =
          normalise(recipe.stepImages[i]) ?? recipe.stepImages[i];
    }

    for (int i = 0; i < recipe.imageUrls.length; i++) {
      recipe.imageUrls[i] =
          normalise(recipe.imageUrls[i]) ?? recipe.imageUrls[i];
    }
  }

  /// Persists image blobs for all local files collected during pre-processing.
  Future<void> _saveImageBlobs(
      int recipeId, Recipe recipe, Map<String, String> fileNameToPath) async {
    Future<void> save(String fileName, String imageType, int? stepIndex) async {
      try {
        final exists = await _db.imageDao.checkImageExists(fileName);
        if (exists) return; // already in the blob store

        final original = fileNameToPath[fileName];
        if (original == null) return;

        final file = File(original);
        if (!await file.exists()) return; // file missing – skip silently

        final bytes = await file.readAsBytes();
        await _db.imageDao.saveImage(RecipeImagesCompanion(
          recipeId: Value(recipeId),
          fileName: Value(fileName),
          imageType: Value(imageType),
          stepIndex:
              stepIndex != null ? Value(stepIndex) : const Value.absent(),
          imageData: Value(bytes),
          mimeType: const Value('image/jpeg'),
          createdAt: Value(DateTime.now()),
        ));
      } catch (e) {
        // Blob write failures must not abort the recipe save.
        debugPrint('RecipeRepository._saveImageBlobs: skipping $fileName — $e');
      }
    }

    if (recipe.headerImage != null &&
        recipe.headerImage!.isNotEmpty &&
        !recipe.headerImage!.startsWith('http')) {
      await save(recipe.headerImage!, 'header', null);
    }

    for (int i = 0; i < recipe.stepImages.length; i++) {
      final v = recipe.stepImages[i];
      if (!v.startsWith('http')) await save(v, 'step', i);
    }

    for (final v in recipe.imageUrls) {
      if (!v.startsWith('http')) await save(v, 'gallery', null);
    }
  }

  /// Completes image path resolution for the [partial] list returned by
  /// [_batchDecodeRecipes] after [Isolate.run].
  ///
  /// The isolate already resolved paths whose files were present in the
  /// on-disk cache (common case). This method handles the remaining bare
  /// filenames via a BLOB-free DB existence check; actual BLOB bytes are only
  /// fetched when the file genuinely needs to be written to the cache.
  /// Null entries (decode failures) are dropped.
  Future<List<Recipe>> _finalizeImagePaths(List<Recipe?> partial) async {
    final result = <Recipe>[];
    for (final recipe in partial) {
      if (recipe == null) continue;
      recipe.headerImage =
          await _resolveNullableImagePath(recipe.headerImage);
      recipe.stepImages =
          await Future.wait(recipe.stepImages.map(_resolveImagePath));
      recipe.imageUrls =
          await Future.wait(recipe.imageUrls.map(_resolveImagePath));
      result.add(recipe);
    }
    return result;
  }

  /// Resolves a nullable image value. See [_resolveImagePath].
  Future<String?> _resolveNullableImagePath(String? value) async {
    if (value == null || value.isEmpty) return value;
    return _resolveImagePath(value);
  }

  /// Resolves a single image value:
  /// - URLs and absolute paths pass through unchanged.
  /// - Plain filenames first check the on-disk cache (fast path).
  /// - On cache miss, [ImageDao.checkImageExists] verifies blob presence
  ///   without fetching the [imageData] BLOB column. The full BLOB is only
  ///   read when the file must be written to the cache.
  /// - If no blob is found (image not yet synced from another device), the
  ///   absolute cache path is returned even though the file does not yet exist
  ///   so image widgets show a placeholder rather than throwing.
  Future<String> _resolveImagePath(String value) async {
    if (value.startsWith('http')) return value;
    if (_isAbsolutePath(value)) return value;

    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/recipe_images');
    final cachedFile = File('${cacheDir.path}/$value');

    if (await cachedFile.exists()) return cachedFile.path;

    // Check existence without pulling the imageData BLOB into memory.
    final exists = await _db.imageDao.checkImageExists(value);
    if (!exists) return cachedFile.path;

    // Only fetch the BLOB now that we know it exists and the cache is cold.
    final blob = await _db.imageDao.getImageByFileName(value);
    if (blob == null) return cachedFile.path; // race-condition safety

    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    await cachedFile.writeAsBytes(blob.imageData);
    return cachedFile.path;
  }

  Course _toCourse(db.Course c) {
    return Course()
      ..id = c.id
      ..slug = c.slug
      ..name = c.name
      ..iconName = c.iconName
      ..sortOrder = c.sortOrder
      ..colorValue = c.colorValue
      ..isVisible = c.isVisible;
  }

  // ============ RECIPES ============

  /// Converts a list of raw [db.Recipe] rows into model [Recipe] objects,
  /// skipping any row that fails to load (e.g. corrupted image reference).
  ///
  /// A single bad recipe must never prevent the rest of a course from loading.
  Future<List<Recipe>> _loadRecipesFrom(List<db.Recipe> rows) async {
    final results = await Future.wait(rows.map((r) async {
      try {
        final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
        return await _toIsarRecipe(r, ings);
      } catch (e) {
        debugPrint('RecipeRepository: skipping recipe ${r.id} (${r.name}): $e');
        return null;
      }
    }));
    return results.whereType<Recipe>().toList();
  }

  Future<List<Recipe>> getAllRecipes() async {
    final rows = await _db.recipeDao.getAllRecipes();
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getRecipesByCourse(String course) async {
    final rows = await _db.recipeDao.getRecipesByCourse(course);
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getRecipesByCuisine(String cuisine) async {
    final rows = await _db.recipeDao.getRecipesByCuisine(cuisine);
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getRecipesBySource(RecipeSource source) async {
    final rows = await _db.recipeDao.getRecipesBySource(source.name);
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getPersonalRecipes() async {
    final rows = await _db.recipeDao.getPersonalRecipes();
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getMemoixRecipes() async {
    final rows = await _db.recipeDao.getMemoixRecipes();
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getImportedRecipes() async {
    final rows = await _db.recipeDao.getImportedRecipes();
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> getFavorites() async {
    final rows = await _db.recipeDao.getFavoriteRecipes();
    return _loadRecipesFrom(rows);
  }

  Future<List<Recipe>> searchRecipes(String query,
      {List<String>? courseFilter}) async {
    if (query.isEmpty) {
      if (courseFilter != null && courseFilter.isNotEmpty) {
        final all = await getAllRecipes();
        return all
            .where((r) => courseFilter
                .any((slug) => r.course.toLowerCase() == slug.toLowerCase()))
            .toList();
      }
      return getAllRecipes();
    }

    final rows = await _db.recipeDao.searchRecipes(query);
    final results = await _loadRecipesFrom(rows);

    if (courseFilter != null && courseFilter.isNotEmpty) {
      return results
          .where((r) => courseFilter
              .any((slug) => r.course.toLowerCase() == slug.toLowerCase()))
          .toList();
    }
    return results;
  }

  Future<Recipe?> getRecipeById(int id) async {
    final row = await _db.recipeDao.getRecipeById(id);
    if (row == null) return null;
    final ings = await _db.recipeDao.getIngredientsForRecipe(id);
    return _toIsarRecipe(row, ings);
  }

  Future<Recipe?> getRecipeByUuid(String uuid) async {
    final row = await _db.recipeDao.getRecipeByUuid(uuid);
    if (row == null) return null;
    final ings = await _db.recipeDao.getIngredientsForRecipe(row.id);
    return _toIsarRecipe(row, ings);
  }

  Future<int> saveRecipe(Recipe recipe, {bool preserveTimestamp = false}) async {
    try {
      if (recipe.uuid.isEmpty) recipe.uuid = _uuid.v4();
    } catch (_) {
      recipe.uuid = _uuid.v4();
    }
    if (!preserveTimestamp) recipe.updatedAt = DateTime.now();
    _normalizeIngredientUnits(recipe);

    // Replace absolute image paths with basenames before persisting.
    // Collect the originals so blobs can be written after we have a recipeId.
    final fileNameToPath = <String, String>{};
    _collectAndNormaliseImagePaths(recipe, fileNameToPath);

    final companion = _toCompanion(recipe);
    await _db.recipeDao.saveRecipe(companion);
    final recipeId = await _db.recipeDao.getIdByUuid(recipe.uuid) ?? 0;
    await _db.recipeDao.deleteIngredientsForRecipe(recipeId);
    await _db.recipeDao
        .saveIngredients(_toIngredientCompanions(recipeId, recipe.ingredients));
    if (recipeId > 0) await _db.recipeDao.touchRecipe(recipeId);

    // Persist image blobs for any new local files.
    if (recipeId > 0 && fileNameToPath.isNotEmpty) {
      await _saveImageBlobs(recipeId, recipe, fileNameToPath);
    }

    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    return recipeId;
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final now = DateTime.now();
    for (final recipe in recipes) {
      try {
        if (recipe.uuid.isEmpty) recipe.uuid = _uuid.v4();
      } catch (_) {
        recipe.uuid = _uuid.v4();
      }
      recipe.updatedAt = now;
      _normalizeIngredientUnits(recipe);
    }

    final companions = recipes.map(_toCompanion).toList();
    await _db.recipeDao.saveRecipes(companions);

    for (final recipe in recipes) {
      final row = await _db.recipeDao.getRecipeByUuid(recipe.uuid);
      if (row != null) {
        await _db.recipeDao.deleteIngredientsForRecipe(row.id);
        await _db.recipeDao.saveIngredients(
            _toIngredientCompanions(row.id, recipe.ingredients));
      }
    }

    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  Future<bool> deleteRecipe(int id) async {
    if (id > 0) {
      final row = await _db.recipeDao.getRecipeById(id);
      if (row != null) {
        await TombstoneStore.add(TombstoneDomain.recipes, row.uuid);
      }
    }
    await _db.recipeDao.deleteRecipe(id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    return true;
  }

  /// Delete a recipe by UUID. Pass [fromMerge] = true when called during a
  /// pull merge to prevent recording a tombstone for a remotely-deleted item.
  Future<bool> deleteRecipeByUuid(String uuid, {bool fromMerge = false}) async {
    final row = await _db.recipeDao.getRecipeByUuid(uuid);
    if (row == null) return false;
    if (!fromMerge) {
      await TombstoneStore.add(TombstoneDomain.recipes, uuid);
    }
    await _db.recipeDao.deleteRecipe(row.id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    return true;
  }

  Future<List<Recipe>> getRecipesPairedWith(
      String recipeUuid) async {
    final all = await _db.recipeDao.getAllRecipes();
    final matched = all.where((r) {
      final ids =
          (jsonDecode(r.pairedRecipeIds) as List).cast<String>();
      return ids.contains(recipeUuid);
    }).toList();
    return Future.wait(matched.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getRecipesByUuids(
      List<String> uuids) async {
    if (uuids.isEmpty) return [];
    final results = <Recipe>[];
    for (final uuid in uuids) {
      final recipe = await getRecipeByUuid(uuid);
      if (recipe != null) results.add(recipe);
    }
    return results;
  }

  Future<List<IntegrityResponse>> toggleFavorite(int id) async {
    final existing = await getRecipeById(id);
    if (existing == null) return [];
    final wasFavorited = existing.isFavorite;

    if (!wasFavorited) {
      final preflight = await IntegrityService.preflightSecondary(
        'activity.recipe_favourite',
        {
          'recipe_id': existing.uuid,
          'ref_count': existing.ingredients.length,
          'node_count': existing.directions.length,
        },
      );
      if (preflight.any((r) => r.type == 'system_message')) {
        await processIntegrityResponseList(preflight, _ref);
      }
      final blocking =
          preflight.where((r) => r.type == 'system_message').toList();
      if (blocking.isNotEmpty) return blocking;
    }

    await _db.recipeDao.toggleFavorite(id, wasFavorited);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();

    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': existing.uuid,
        'is_adding': !wasFavorited,
      },
    );

    return [];
  }

  Stream<List<Recipe>> watchAllRecipes() {
    return _db.recipeDao.watchAllRecipes().asyncMap((rows) async {
      if (rows.isEmpty) return <Recipe>[];
      final allIngs = await _db.recipeDao
          .getIngredientsForRecipes(rows.map((r) => r.id));
      final grouped = _groupIngredientsByRecipe(allIngs);
      final appDir = await getApplicationDocumentsDirectory();
      final cacheBasePath = '${appDir.path}/recipe_images';
      final partial = await Isolate.run(() => _batchDecodeRecipes((
            rawRecipes: rows,
            grouped: grouped,
            cacheBasePath: cacheBasePath,
          )));
      return _finalizeImagePaths(partial);
    });
  }

  Stream<List<Recipe>> watchFavorites() {
    // Fetch only ingredients for the returned favorites — no full table scan.
    return _db.recipeDao.watchFavoriteRecipes().asyncMap((rows) async {
      if (rows.isEmpty) return <Recipe>[];
      final allIngs = await _db.recipeDao
          .getIngredientsForRecipes(rows.map((r) => r.id));
      final grouped = _groupIngredientsByRecipe(allIngs);
      final appDir = await getApplicationDocumentsDirectory();
      final cacheBasePath = '${appDir.path}/recipe_images';
      final partial = await Isolate.run(() => _batchDecodeRecipes((
            rawRecipes: rows,
            grouped: grouped,
            cacheBasePath: cacheBasePath,
          )));
      return _finalizeImagePaths(partial);
    });
  }

  Stream<List<Recipe>> watchRecipesByCourse(String course) {
    // Fetch only ingredients for the course's recipes — no full table scan.
    return _db.recipeDao.watchRecipesByCourse(course).asyncMap((rows) async {
      if (rows.isEmpty) return <Recipe>[];
      final allIngs = await _db.recipeDao
          .getIngredientsForRecipes(rows.map((r) => r.id));
      final grouped = _groupIngredientsByRecipe(allIngs);
      final appDir = await getApplicationDocumentsDirectory();
      final cacheBasePath = '${appDir.path}/recipe_images';
      final partial = await Isolate.run(() => _batchDecodeRecipes((
            rawRecipes: rows,
            grouped: grouped,
            cacheBasePath: cacheBasePath,
          )));
      final recipes = await _finalizeImagePaths(partial);

      const continentOrder = [
        'Asian',
        'Caribbean',
        'European',
        'Middle Eastern',
        'African',
        'North American',
        'Central American',
        'South American',
        'Oceanian',
      ];

      recipes.sort((a, b) {
        final aCont = Cuisine.continentFor(a.cuisine);
        final bCont = Cuisine.continentFor(b.cuisine);

        final aContIndex = aCont != null
            ? continentOrder.indexOf(aCont)
            : continentOrder.length;
        final bContIndex = bCont != null
            ? continentOrder.indexOf(bCont)
            : continentOrder.length;
        final aOrder =
            aContIndex == -1 ? continentOrder.length : aContIndex;
        final bOrder =
            bContIndex == -1 ? continentOrder.length : bContIndex;

        if (aOrder != bOrder) return aOrder.compareTo(bOrder);

        final aCountry = Cuisine.toAdjective(a.cuisine);
        final bCountry = Cuisine.toAdjective(b.cuisine);
        if (aCountry != bCountry) {
          return aCountry.toLowerCase().compareTo(bCountry.toLowerCase());
        }

        final aProvince = a.subcategory ?? '';
        final bProvince = b.subcategory ?? '';
        if (aProvince != bProvince) {
          return aProvince.toLowerCase().compareTo(bProvince.toLowerCase());
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return recipes;
    });
  }

  // ============ COURSES ============

  Future<List<Course>> getAllCourses() async {
    final rows = await _db.recipeDao.getAllCourses();
    return rows.map(_toCourse).toList();
  }

  Future<List<Course>> getVisibleCourses() async {
    final rows = await _db.recipeDao.getVisibleCourses();
    return rows.map(_toCourse).toList();
  }

  Future<int> saveCourse(Course course) async {
    final companion = CoursesCompanion(
      slug: Value(course.slug),
      name: Value(course.name),
      iconName: Value(course.iconName),
      sortOrder: Value(course.sortOrder),
      colorValue: Value(course.colorValue),
      isVisible: Value(course.isVisible),
    );
    return _db.recipeDao.saveCourse(companion);
  }

  Stream<List<Course>> watchCourses() {
    return _db.recipeDao.watchCourses().map((rows) => rows.map(_toCourse).toList());
  }

  // ============ INGREDIENT SUGGESTIONS ============

  Future<List<String>> getIngredientNameSuggestions(String query) async {
    final allRecipes = await getAllRecipes();

    final historyNames = <String>{};
    for (final recipe in allRecipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.name.isNotEmpty) {
          historyNames.add(ingredient.name);
        }
      }
    }

    final allNames = <String>{
      ...Suggestions.essentialIngredients,
      ...historyNames
    };

    final lowerQuery = query.toLowerCase();
    final filtered =
        allNames.where((name) => name.toLowerCase().contains(lowerQuery)).toList();

    filtered.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStartsWith = aLower.startsWith(lowerQuery);
      final bStartsWith = bLower.startsWith(lowerQuery);
      if (aStartsWith && !bStartsWith) return -1;
      if (bStartsWith && !aStartsWith) return 1;
      return aLower.compareTo(bLower);
    });

    return filtered;
  }

  Future<List<String>> getPrepNoteSuggestions(String query) async {
    final allRecipes = await getAllRecipes();

    final historyNotes = <String>{};
    for (final recipe in allRecipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.preparation != null &&
            ingredient.preparation!.isNotEmpty) {
          historyNotes.add(ingredient.preparation!);
        }
      }
    }

    final allNotes = <String>{
      ...Suggestions.essentialPrepNotes,
      ...Suggestions.preparations,
      ...historyNotes,
    };

    final lowerQuery = query.toLowerCase();
    final filtered =
        allNotes.where((note) => note.toLowerCase().contains(lowerQuery)).toList();

    filtered.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStartsWith = aLower.startsWith(lowerQuery);
      final bStartsWith = bLower.startsWith(lowerQuery);
      if (aStartsWith && !bStartsWith) return -1;
      if (bStartsWith && !aStartsWith) return 1;
      return aLower.compareTo(bLower);
    });

    return filtered;
  }

  // ============ SYNC HELPERS ============

  Future<void> syncMemoixRecipes(List<Recipe> recipes) async {
    final companions = recipes.map(_toCompanion).toList();
    await _db.recipeDao.syncMemoixRecipes(companions);

    for (final recipe in recipes) {
      final dbRecipe = await _db.recipeDao.getRecipeByUuid(recipe.uuid);
      if (dbRecipe == null) continue;
      await _db.recipeDao.deleteIngredientsForRecipe(dbRecipe.id);
      final ingredientCompanions = _toIngredientCompanions(dbRecipe.id, recipe.ingredients);
      await _db.recipeDao.saveIngredients(ingredientCompanions);
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    return null;
  }
}

// ============ PROVIDERS ============

/// Provider for recipe repository
/// Provider for recipe repository
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(databaseProvider), ref);
});

/// Provider for all recipes
final allRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchAllRecipes();
});

/// Provider for recipes filtered by course
final recipesByCourseProvider = StreamProvider.family<List<Recipe>, String>((ref, course) {
  return ref.watch(recipeRepositoryProvider).watchRecipesByCourse(course);
});

/// Provider for courses
final coursesProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchCourses();
});

/// Provider for favorite recipes (stream-based for real-time updates)
final favoriteRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchFavorites();
});

/// Provider for recipe search - watches allRecipesProvider to auto-refresh when recipes change
final recipeSearchProvider = FutureProvider.family<List<Recipe>, String>((ref, query) {
  // Watch allRecipesProvider to invalidate search when recipes are added/deleted
  ref.watch(allRecipesProvider);
  return ref.watch(recipeRepositoryProvider).searchRecipes(query);
});

/// Provider for available cuisines in the database
final availableCuisinesProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(allRecipesProvider.stream).map((recipes) {
    return recipes
        .map((r) => r.cuisine)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet();
  });
});

/// Provider to get recipes that pair with a given recipe UUID (inverse lookup)
final recipesPairedWithProvider = FutureProvider.family<List<Recipe>, String>((ref, recipeUuid) {
  return ref.watch(recipeRepositoryProvider).getRecipesPairedWith(recipeUuid);
});

/// Provider to get recipes by their UUIDs
final recipesByUuidsProvider = FutureProvider.family<List<Recipe>, List<String>>((ref, uuids) {
  return ref.watch(recipeRepositoryProvider).getRecipesByUuids(uuids);
});
