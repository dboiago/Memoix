import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'supabase_auth_service.dart';

/// Sync service for the invite-only Supabase backend.
///
/// Single public entry point: [sync]. All methods are static. Never throws —
/// per-table errors are caught and logged; a failure on one table does not
/// abort sync of other tables.
///
/// Currently syncs: Recipes, Ingredients.
/// Other tables will be added in follow-up prompts.
abstract class SupabaseSyncService {
  SupabaseSyncService._();

  // SharedPreferences keys for last-sync timestamps (ISO8601 UTC strings).
  static const _keyRecipes = 'supabase_sync_recipes';
  static const _keyIngredients = 'supabase_sync_ingredients';
  static const _keyPizzas = 'supabase_sync_pizzas';
  static const _keySandwiches = 'supabase_sync_sandwiches';
  static const _keyCellarEntries = 'supabase_sync_cellar_entries';
  static const _keyCheeseEntries = 'supabase_sync_cheese_entries';
  static const _keySmokingRecipes = 'supabase_sync_smoking_recipes';
  static const _keyCourses = 'supabase_sync_courses';
  static const _keyScratchPads = 'supabase_sync_scratch_pads';

  // ─────────────────────────────────────────────────────────────────────────
  // Entry point
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> sync() async {
    // Guard: must be signed in.
    if (!SupabaseAuthService.isSignedIn) return;

    // Guard: must have actual network connectivity (connectivity_plus v6
    // returns List<ConnectivityResult>).
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasConnection =
        connectivityResults.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) return;

    // Guard: must belong to a sync group.
    final groupId = await SupabaseAuthService.groupId;
    if (groupId == null) {
      debugPrint('SupabaseSyncService: no group_id found — skipping sync.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastSyncRecipes = _getLastSync(prefs, _keyRecipes);
    final lastSyncIngredients = _getLastSync(prefs, _keyIngredients);
    final lastSyncPizzas = _getLastSync(prefs, _keyPizzas);
    final lastSyncSandwiches = _getLastSync(prefs, _keySandwiches);
    final lastSyncCellarEntries = _getLastSync(prefs, _keyCellarEntries);
    final lastSyncCheeseEntries = _getLastSync(prefs, _keyCheeseEntries);
    final lastSyncSmokingRecipes = _getLastSync(prefs, _keySmokingRecipes);
    final lastSyncCourses = _getLastSync(prefs, _keyCourses);
    final lastSyncScratchPads = _getLastSync(prefs, _keyScratchPads);

    // ── Recipes — independent error boundary ──────────────────────────────
    List<String> pulledRecipeUuids = [];
    try {
      pulledRecipeUuids = await _syncRecipes(groupId, lastSyncRecipes);
      await _setLastSync(prefs, _keyRecipes, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: recipe sync error: $e');
    }

    // ── Ingredients — independent error boundary ──────────────────────────
    try {
      await _syncIngredients(groupId, lastSyncIngredients, pulledRecipeUuids);
      await _setLastSync(prefs, _keyIngredients, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: ingredient sync error: $e');
    }

    // ── Pizzas ────────────────────────────────────────────────────────────
    try {
      await _syncPizzas(groupId, lastSyncPizzas);
      await _setLastSync(prefs, _keyPizzas, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: pizza sync error: $e');
    }

    // ── Sandwiches ────────────────────────────────────────────────────────
    try {
      await _syncSandwiches(groupId, lastSyncSandwiches);
      await _setLastSync(prefs, _keySandwiches, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: sandwich sync error: $e');
    }

    // ── Cellar entries ────────────────────────────────────────────────────
    try {
      await _syncCellarEntries(groupId, lastSyncCellarEntries);
      await _setLastSync(prefs, _keyCellarEntries, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: cellar entry sync error: $e');
    }

    // ── Cheese entries ────────────────────────────────────────────────────
    try {
      await _syncCheeseEntries(groupId, lastSyncCheeseEntries);
      await _setLastSync(prefs, _keyCheeseEntries, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: cheese entry sync error: $e');
    }

    // ── Smoking recipes ───────────────────────────────────────────────────
    try {
      await _syncSmokingRecipes(groupId, lastSyncSmokingRecipes);
      await _setLastSync(prefs, _keySmokingRecipes, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: smoking recipe sync error: $e');
    }

    // ── Courses ───────────────────────────────────────────────────────────
    try {
      await _syncCourses(groupId, lastSyncCourses);
      await _setLastSync(prefs, _keyCourses, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: course sync error: $e');
    }

    // ── Scratch pads ──────────────────────────────────────────────────────
    try {
      await _syncScratchPads(groupId, lastSyncScratchPads);
      await _setLastSync(prefs, _keyScratchPads, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('SupabaseSyncService: scratch pad sync error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recipes
  // ─────────────────────────────────────────────────────────────────────────

  /// Push local recipe changes then pull remote recipe changes.
  ///
  /// Returns the UUIDs of recipes successfully pulled from remote so that
  /// [_syncIngredients] can pull their ingredients.
  static Future<List<String>> _syncRecipes(
    String groupId,
    DateTime? lastSync,
  ) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // ── PUSH: local → Supabase ───────────────────────────────────────────
    // RecipeDao has no getRecipesUpdatedSince() — raw Drift query used.
    final localChanged = lastSync == null
        ? await db.select(db.recipes).get()
        : await (db.select(db.recipes)
                ..where((r) => r.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      final pushRows =
          localChanged.map((r) => _recipeToRow(r, groupId, userId)).toList();
      await client
          .schema('memoix')
          .from('recipes')
          .upsert(pushRows, onConflict: 'uuid');
    }

    // ── PULL: Supabase → local ───────────────────────────────────────────
    final remoteQuery = client
        .schema('memoix')
        .from('recipes')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteRows = lastSync == null
        ? await remoteQuery
        : await remoteQuery.gt('updated_at', lastSync.toIso8601String());

    final pulledUuids = <String>[];

    for (final row in remoteRows) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.recipeDao.getRecipeByUuid(remoteUuid);

      if (existing != null) {
        // Local wins if same age or newer — skip.
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;

        // Remote is newer: update, preserving personal fields.
        final companion = _remoteToRecipeCompanion(
          row,
          isFavorite: existing.isFavorite,
          rating: existing.rating,
          cookCount: existing.cookCount,
          lastCookedAt: existing.lastCookedAt,
        );
        await db.recipeDao.saveRecipe(companion.copyWith(id: Value(existing.id)));
      } else {
        // New recipe from remote: insert with clean personal fields.
        final companion = _remoteToRecipeCompanion(
          row,
          isFavorite: false,
          rating: 0,
          cookCount: 0,
          lastCookedAt: null,
        );
        await db.recipeDao.saveRecipe(companion);
      }

      pulledUuids.add(remoteUuid);
    }

    return pulledUuids;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ingredients
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncIngredients(
    String groupId,
    DateTime? lastSync,
    List<String> pulledRecipeUuids,
  ) async {
    final db = AppDatabase.instance;
    final client = _requireClient();

    // ── PUSH: local → Supabase ───────────────────────────────────────────
    // Ingredients that belong to recipes changed since lastSync.
    // RecipeDao has no bulk getIngredientsByRecipeIds() — raw Drift query used.
    final changedRecipes = lastSync == null
        ? await db.select(db.recipes).get()
        : await (db.select(db.recipes)
                ..where((r) => r.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (changedRecipes.isNotEmpty) {
      final changedRecipeIds = changedRecipes.map((r) => r.id).toList();
      // Build recipeId → uuid map to avoid per-ingredient DB lookups.
      final recipeIdToUuid = {for (final r in changedRecipes) r.id: r.uuid};

      final changedIngredients = await (db.select(db.ingredients)
            ..where((i) => i.recipeId.isIn(changedRecipeIds)))
          .get();

      if (changedIngredients.isNotEmpty) {
        final pushRows = changedIngredients.map((ing) {
          final recipeUuid = recipeIdToUuid[ing.recipeId] ?? '';
          return _ingredientToRow(ing, recipeUuid, groupId);
        }).toList();

        await client
            .schema('memoix')
            .from('ingredients')
            .upsert(pushRows, onConflict: 'uuid');
      }
    }

    // ── PULL: Supabase → local ───────────────────────────────────────────
    // Only pull ingredients for recipes that were just pulled.
    if (pulledRecipeUuids.isEmpty) return;

    final List<Map<String, dynamic>> remoteIngredients = await client
        .schema('memoix')
        .from('ingredients')
        .select()
        .inFilter('recipe_uuid', pulledRecipeUuids);

    // Group by recipe_uuid for efficient per-recipe replacement.
    final byRecipe = <String, List<Map<String, dynamic>>>{};
    for (final row in remoteIngredients) {
      final rUuid = row['recipe_uuid'] as String;
      byRecipe.putIfAbsent(rUuid, () => []).add(row);
    }

    for (final entry in byRecipe.entries) {
      final recipe = await db.recipeDao.getRecipeByUuid(entry.key);
      if (recipe == null) continue;

      await db.recipeDao.deleteIngredientsForRecipe(recipe.id);

      final companions = entry.value
          .map((row) => _remoteToIngredientCompanion(row, recipe.id))
          .toList();
      await db.recipeDao.saveIngredients(companions);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column mappers: local → remote
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the Supabase row map for a [Recipe].
  ///
  /// Explicitly excludes device-personal fields: isFavorite, cookCount,
  /// lastCookedAt, rating.
  static Map<String, dynamic> _recipeToRow(
    Recipe r,
    String groupId,
    String? userId,
  ) {
    return {
      'uuid': r.uuid,
      'name': r.name,
      'course': r.course,
      'cuisine': r.cuisine,
      'subcategory': r.subcategory,
      'continent': r.continent,
      'country': r.country,
      'serves': r.serves,
      'time': r.time,
      'pairs_with': r.pairsWith,
      'paired_recipe_ids': r.pairedRecipeIds,
      'comments': r.comments,
      'directions': r.directions,
      'source_url': r.sourceUrl,
      'image_urls': r.imageUrls,
      'image_url': r.imageUrl,
      'header_image': r.headerImage,
      'step_images': r.stepImages,
      'step_image_map': r.stepImageMap,
      'source': r.source,
      'color_value': r.colorValue,
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'updated_at': r.updatedAt.toUtc().toIso8601String(),
      'edit_count': r.editCount,
      'first_edit_at': r.firstEditAt?.toUtc().toIso8601String(),
      'last_edit_at': r.lastEditAt?.toUtc().toIso8601String(),
      'tags': r.tags,
      'version': r.version,
      'nutrition': r.nutrition,
      'modernist_type': r.modernistType,
      'smoking_type': r.smokingType,
      'glass': r.glass,
      'garnish': r.garnish,
      'pickle_method': r.pickleMethod,
      'recipe_type': r.recipeType,
      'technique': r.technique,
      'difficulty': r.difficulty,
      'science_notes': r.scienceNotes,
      'equipment_json': r.equipmentJson,
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _ingredientToRow(
    Ingredient ing,
    String recipeUuid,
    String groupId,
  ) {
    return {
      'uuid': ing.uuid,
      'recipe_uuid': recipeUuid,
      'name': ing.name,
      'amount': ing.amount,
      'unit': ing.unit,
      'notes': ing.notes,
      'alternative': ing.alternative,
      'is_optional': ing.isOptional,
      'section': ing.section,
      'baker_percent': ing.bakerPercent,
      'group_id': groupId,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column mappers: remote → local Companion
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a [RecipesCompanion] from a remote row.
  ///
  /// The companion does NOT include [id] — add it at the call site via
  /// `companion.copyWith(id: Value(existingId))` when updating an existing row.
  ///
  /// The personal fields [isFavorite], [rating], [cookCount], [lastCookedAt]
  /// are always supplied by the caller and are never read from the remote row.
  static RecipesCompanion _remoteToRecipeCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required int rating,
    required int cookCount,
    required DateTime? lastCookedAt,
  }) {
    DateTime? parseNullable(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();

    String text(String key, [String fallback = '']) =>
        row[key] as String? ?? fallback;

    return RecipesCompanion(
      uuid: Value(text('uuid')),
      name: Value(text('name')),
      course: Value(text('course')),
      cuisine: Value(row['cuisine'] as String?),
      subcategory: Value(row['subcategory'] as String?),
      continent: Value(row['continent'] as String?),
      country: Value(row['country'] as String?),
      serves: Value(row['serves'] as String?),
      time: Value(row['time'] as String?),
      pairsWith: Value(text('pairs_with', '[]')),
      pairedRecipeIds: Value(text('paired_recipe_ids', '[]')),
      comments: Value(row['comments'] as String?),
      directions: Value(text('directions', '[]')),
      sourceUrl: Value(row['source_url'] as String?),
      imageUrls: Value(text('image_urls', '[]')),
      imageUrl: Value(row['image_url'] as String?),
      headerImage: Value(row['header_image'] as String?),
      stepImages: Value(text('step_images', '[]')),
      stepImageMap: Value(text('step_image_map', '[]')),
      source: Value(text('source', 'personal')),
      colorValue: Value(row['color_value'] as int?),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      isFavorite: Value(isFavorite),
      rating: Value(rating),
      cookCount: Value(cookCount),
      lastCookedAt: Value(lastCookedAt),
      editCount: Value(row['edit_count'] as int? ?? 0),
      firstEditAt: Value(parseNullable(row['first_edit_at'])),
      lastEditAt: Value(parseNullable(row['last_edit_at'])),
      tags: Value(text('tags', '[]')),
      version: Value(row['version'] as int? ?? 1),
      nutrition: Value(row['nutrition'] as String?),
      modernistType: Value(row['modernist_type'] as String?),
      smokingType: Value(row['smoking_type'] as String?),
      glass: Value(row['glass'] as String?),
      garnish: Value(text('garnish', '[]')),
      pickleMethod: Value(row['pickle_method'] as String?),
      recipeType: Value(text('recipe_type', 'standard')),
      technique: Value(row['technique'] as String?),
      difficulty: Value(row['difficulty'] as String?),
      scienceNotes: Value(row['science_notes'] as String?),
      equipmentJson: Value(row['equipment_json'] as String?),
    );
  }

  static IngredientsCompanion _remoteToIngredientCompanion(
    Map<String, dynamic> row,
    int recipeId,
  ) {
    return IngredientsCompanion(
      uuid: Value(row['uuid'] as String? ?? ''),
      recipeId: Value(recipeId),
      name: Value(row['name'] as String),
      amount: Value(row['amount'] as String?),
      unit: Value(row['unit'] as String?),
      notes: Value(row['notes'] as String?),
      alternative: Value(row['alternative'] as String?),
      isOptional: Value(row['is_optional'] as bool? ?? false),
      section: Value(row['section'] as String?),
      bakerPercent: Value(row['baker_percent'] as String?),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pizzas
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncPizzas(String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — CatalogueDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.pizzas).get()
        : await (db.select(db.pizzas)
                ..where((p) => p.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('pizzas')
          .upsert(
            localChanged.map((p) => _pizzaToRow(p, groupId, userId)).toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQueryPizzas = client
        .schema('memoix')
        .from('pizzas')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remotePizzas = lastSync == null
        ? await remoteQueryPizzas
        : await remoteQueryPizzas.gt('updated_at', lastSync.toIso8601String());

    for (final row in remotePizzas) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.catalogueDao.getPizzaByUuid(remoteUuid);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.catalogueDao.savePizza(_remoteToPizzaCompanion(
          row,
          isFavorite: existing.isFavorite,
          cookCount: existing.cookCount,
          rating: existing.rating,
        ).copyWith(id: Value(existing.id)));
      } else {
        await db.catalogueDao.savePizza(_remoteToPizzaCompanion(
          row,
          isFavorite: false,
          cookCount: 0,
          rating: 0,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sandwiches
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncSandwiches(
      String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — CatalogueDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.sandwiches).get()
        : await (db.select(db.sandwiches)
                ..where((s) => s.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('sandwiches')
          .upsert(
            localChanged.map((s) => _sandwichToRow(s, groupId, userId)).toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQuerySandwiches = client
        .schema('memoix')
        .from('sandwiches')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteSandwiches = lastSync == null
        ? await remoteQuerySandwiches
        : await remoteQuerySandwiches
            .gt('updated_at', lastSync.toIso8601String());

    for (final row in remoteSandwiches) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.catalogueDao.getSandwichByUuid(remoteUuid);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.catalogueDao.saveSandwich(_remoteToSandwichCompanion(
          row,
          isFavorite: existing.isFavorite,
          cookCount: existing.cookCount,
          rating: existing.rating,
        ).copyWith(id: Value(existing.id)));
      } else {
        await db.catalogueDao.saveSandwich(_remoteToSandwichCompanion(
          row,
          isFavorite: false,
          cookCount: 0,
          rating: 0,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cellar entries
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncCellarEntries(
      String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — CellarDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.cellarEntries).get()
        : await (db.select(db.cellarEntries)
                ..where((e) => e.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('cellar_entries')
          .upsert(
            localChanged
                .map((e) => _cellarEntryToRow(e, groupId, userId))
                .toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQueryCellar = client
        .schema('memoix')
        .from('cellar_entries')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteCellar = lastSync == null
        ? await remoteQueryCellar
        : await remoteQueryCellar.gt('updated_at', lastSync.toIso8601String());

    for (final row in remoteCellar) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.cellarDao.getEntryByUuid(remoteUuid);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.cellarDao.saveEntry(_remoteToCellarEntryCompanion(
          row,
          isFavorite: existing.isFavorite,
          buy: existing.buy,
        ).copyWith(id: Value(existing.id)));
      } else {
        await db.cellarDao.saveEntry(_remoteToCellarEntryCompanion(
          row,
          isFavorite: false,
          buy: false,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cheese entries
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncCheeseEntries(
      String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — CellarDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.cheeseEntries).get()
        : await (db.select(db.cheeseEntries)
                ..where((e) => e.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('cheese_entries')
          .upsert(
            localChanged
                .map((e) => _cheeseEntryToRow(e, groupId, userId))
                .toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQueryCheese = client
        .schema('memoix')
        .from('cheese_entries')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteCheese = lastSync == null
        ? await remoteQueryCheese
        : await remoteQueryCheese.gt('updated_at', lastSync.toIso8601String());

    for (final row in remoteCheese) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.cellarDao.getCheeseEntryByUuid(remoteUuid);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.cellarDao.saveCheeseEntry(_remoteToCheeseEntryCompanion(
          row,
          isFavorite: existing.isFavorite,
          buy: existing.buy,
        ).copyWith(id: Value(existing.id)));
      } else {
        await db.cellarDao.saveCheeseEntry(_remoteToCheeseEntryCompanion(
          row,
          isFavorite: false,
          buy: false,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Smoking recipes
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncSmokingRecipes(
      String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — SmokingDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.smokingRecipes).get()
        : await (db.select(db.smokingRecipes)
                ..where((r) => r.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('smoking_recipes')
          .upsert(
            localChanged
                .map((r) => _smokingRecipeToRow(r, groupId, userId))
                .toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQuerySmoking = client
        .schema('memoix')
        .from('smoking_recipes')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteSmoking = lastSync == null
        ? await remoteQuerySmoking
        : await remoteQuerySmoking
            .gt('updated_at', lastSync.toIso8601String());

    for (final row in remoteSmoking) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      final existing = await db.smokingDao.getRecipeByUuid(remoteUuid);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.smokingDao.saveRecipe(_remoteToSmokingRecipeCompanion(
          row,
          isFavorite: existing.isFavorite,
          cookCount: existing.cookCount,
        ).copyWith(id: Value(existing.id)));
      } else {
        await db.smokingDao.saveRecipe(_remoteToSmokingRecipeCompanion(
          row,
          isFavorite: false,
          cookCount: 0,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Courses
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncCourses(String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();

    // PUSH — Courses table has no local updatedAt column; always push all.
    // A client-side timestamp is sent as updated_at so remote can filter.
    final allCourses = await db.recipeDao.getAllCourses();
    if (allCourses.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      await client
          .schema('memoix')
          .from('courses')
          .upsert(
            allCourses.map((c) => _courseToRow(c, groupId, now)).toList(),
            onConflict: 'slug',
          );
    }

    // PULL — inserts/updates only; never deletes local courses.
    // No local updatedAt to compare, so remote always wins on pull.
    final remoteQueryCourses = client
        .schema('memoix')
        .from('courses')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remoteCourses = lastSync == null
        ? await remoteQueryCourses
        : await remoteQueryCourses
            .gt('updated_at', lastSync.toIso8601String());

    for (final row in remoteCourses) {
      await db.recipeDao.saveCourse(_remoteToCourseCompanion(row));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scratch pads
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _syncScratchPads(
      String groupId, DateTime? lastSync) async {
    final db = AppDatabase.instance;
    final client = _requireClient();
    final userId = SupabaseAuthService.currentUserId;

    // PUSH — UtilityDao has no updatedSince method; raw Drift used.
    final localChanged = lastSync == null
        ? await db.select(db.scratchPads).get()
        : await (db.select(db.scratchPads)
                ..where((s) => s.updatedAt.isBiggerThan(Variable(lastSync))))
            .get();

    if (localChanged.isNotEmpty) {
      await client
          .schema('memoix')
          .from('scratch_pads')
          .upsert(
            localChanged
                .map((s) => _scratchPadToRow(s, groupId, userId))
                .toList(),
            onConflict: 'uuid',
          );
    }

    // PULL
    final remoteQueryPads = client
        .schema('memoix')
        .from('scratch_pads')
        .select()
        .eq('group_id', groupId);

    final List<Map<String, dynamic>> remotePads = lastSync == null
        ? await remoteQueryPads
        : await remoteQueryPads.gt('updated_at', lastSync.toIso8601String());

    for (final row in remotePads) {
      final remoteUuid = row['uuid'] as String;
      final remoteUpdatedAt =
          DateTime.parse(row['updated_at'] as String).toUtc();

      // UtilityDao has no getByUuid; raw Drift used.
      final existing = await (db.select(db.scratchPads)
            ..where((s) => s.uuid.equals(remoteUuid)))
          .getSingleOrNull();

      final companion = _remoteToScratchPadCompanion(row);
      if (existing != null) {
        if (!existing.updatedAt.toUtc().isBefore(remoteUpdatedAt)) continue;
        await db.utilityDao
            .saveQuickNotes(companion.copyWith(id: Value(existing.id)));
      } else {
        await db.utilityDao.saveQuickNotes(companion);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column mappers: local → remote
  // (Pizzas, Sandwiches, CellarEntries, CheeseEntries, SmokingRecipes,
  //  Courses, ScratchPads)
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _pizzaToRow(
      Pizza p, String groupId, String? userId) {
    return {
      'uuid': p.uuid,
      'name': p.name,
      'base': p.base,
      'cheeses': p.cheeses,
      'proteins': p.proteins,
      'vegetables': p.vegetables,
      'notes': p.notes,
      'image_url': p.imageUrl,
      'source': p.source,
      'tags': p.tags,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
      'version': p.version,
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _sandwichToRow(
      Sandwich s, String groupId, String? userId) {
    return {
      'uuid': s.uuid,
      'name': s.name,
      'bread': s.bread,
      'proteins': s.proteins,
      'vegetables': s.vegetables,
      'cheeses': s.cheeses,
      'condiments': s.condiments,
      'notes': s.notes,
      'image_url': s.imageUrl,
      'source': s.source,
      'tags': s.tags,
      'created_at': s.createdAt.toUtc().toIso8601String(),
      'updated_at': s.updatedAt.toUtc().toIso8601String(),
      'version': s.version,
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _cellarEntryToRow(
      CellarEntry e, String groupId, String? userId) {
    return {
      'uuid': e.uuid,
      'name': e.name,
      'producer': e.producer,
      'category': e.category,
      'tasting_notes': e.tastingNotes,
      'abv': e.abv,
      'age_vintage': e.ageVintage,
      'price_range': e.priceRange,
      'image_url': e.imageUrl,
      'source': e.source,
      'created_at': e.createdAt.toUtc().toIso8601String(),
      'updated_at': e.updatedAt.toUtc().toIso8601String(),
      'version': e.version,
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _cheeseEntryToRow(
      CheeseEntry e, String groupId, String? userId) {
    return {
      'uuid': e.uuid,
      'name': e.name,
      'country': e.country,
      'milk': e.milk,
      'texture': e.texture,
      'type': e.type,
      'flavour': e.flavour,
      'price_range': e.priceRange,
      'image_url': e.imageUrl,
      'source': e.source,
      'created_at': e.createdAt.toUtc().toIso8601String(),
      'updated_at': e.updatedAt.toUtc().toIso8601String(),
      'version': e.version,
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _smokingRecipeToRow(
      SmokingRecipe r, String groupId, String? userId) {
    return {
      'uuid': r.uuid,
      'name': r.name,
      'course': r.course,
      'type': r.type,
      'item': r.item,
      'category': r.category,
      'temperature': r.temperature,
      'time': r.time,
      'wood': r.wood,
      'seasonings_json': r.seasoningsJson,
      'ingredients_json': r.ingredientsJson,
      'serves': r.serves,
      'directions': r.directions,
      'notes': r.notes,
      'header_image': r.headerImage,
      'step_images': r.stepImages,
      'step_image_map': r.stepImageMap,
      'image_url': r.imageUrl,
      'source': r.source,
      'paired_recipe_ids': r.pairedRecipeIds,
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'updated_at': r.updatedAt.toUtc().toIso8601String(),
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  static Map<String, dynamic> _courseToRow(
      Course c, String groupId, String updatedAt) {
    return {
      'slug': c.slug,
      'name': c.name,
      'icon_name': c.iconName,
      'sort_order': c.sortOrder,
      'color_value': c.colorValue,
      'is_visible': c.isVisible,
      'group_id': groupId,
      'updated_at': updatedAt,
    };
  }

  static Map<String, dynamic> _scratchPadToRow(
      ScratchPad s, String groupId, String? userId) {
    return {
      'uuid': s.uuid,
      'quick_notes': s.quickNotes,
      'updated_at': s.updatedAt.toUtc().toIso8601String(),
      'group_id': groupId,
      'updated_by': userId,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column mappers: remote → local Companion
  // (Pizzas, Sandwiches, CellarEntries, CheeseEntries, SmokingRecipes,
  //  Courses, ScratchPads)
  // ─────────────────────────────────────────────────────────────────────────

  static PizzasCompanion _remoteToPizzaCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required int cookCount,
    required int rating,
  }) {
    String text(String key, [String fallback = '']) =>
        row[key] as String? ?? fallback;
    return PizzasCompanion(
      uuid: Value(text('uuid')),
      name: Value(text('name')),
      base: Value(text('base', 'marinara')),
      cheeses: Value(text('cheeses', '[]')),
      proteins: Value(text('proteins', '[]')),
      vegetables: Value(text('vegetables', '[]')),
      notes: Value(row['notes'] as String?),
      imageUrl: Value(row['image_url'] as String?),
      source: Value(text('source', 'personal')),
      tags: Value(text('tags', '[]')),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      version: Value(row['version'] as int? ?? 1),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
      rating: Value(rating),
    );
  }

  static SandwichesCompanion _remoteToSandwichCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required int cookCount,
    required int rating,
  }) {
    String text(String key, [String fallback = '']) =>
        row[key] as String? ?? fallback;
    return SandwichesCompanion(
      uuid: Value(text('uuid')),
      name: Value(text('name')),
      bread: Value(text('bread')),
      proteins: Value(text('proteins', '[]')),
      vegetables: Value(text('vegetables', '[]')),
      cheeses: Value(text('cheeses', '[]')),
      condiments: Value(text('condiments', '[]')),
      notes: Value(row['notes'] as String?),
      imageUrl: Value(row['image_url'] as String?),
      source: Value(text('source', 'personal')),
      tags: Value(text('tags', '[]')),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      version: Value(row['version'] as int? ?? 1),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
      rating: Value(rating),
    );
  }

  static CellarEntriesCompanion _remoteToCellarEntryCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required bool buy,
  }) {
    return CellarEntriesCompanion(
      uuid: Value(row['uuid'] as String),
      name: Value(row['name'] as String),
      producer: Value(row['producer'] as String?),
      category: Value(row['category'] as String?),
      tastingNotes: Value(row['tasting_notes'] as String?),
      abv: Value(row['abv'] as String?),
      ageVintage: Value(row['age_vintage'] as String?),
      priceRange: Value(row['price_range'] as int?),
      imageUrl: Value(row['image_url'] as String?),
      source: Value(row['source'] as String? ?? 'personal'),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      version: Value(row['version'] as int? ?? 1),
      isFavorite: Value(isFavorite),
      buy: Value(buy),
    );
  }

  static CheeseEntriesCompanion _remoteToCheeseEntryCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required bool buy,
  }) {
    return CheeseEntriesCompanion(
      uuid: Value(row['uuid'] as String),
      name: Value(row['name'] as String),
      country: Value(row['country'] as String?),
      milk: Value(row['milk'] as String?),
      texture: Value(row['texture'] as String?),
      type: Value(row['type'] as String?),
      flavour: Value(row['flavour'] as String?),
      priceRange: Value(row['price_range'] as int?),
      imageUrl: Value(row['image_url'] as String?),
      source: Value(row['source'] as String? ?? 'personal'),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      version: Value(row['version'] as int? ?? 1),
      isFavorite: Value(isFavorite),
      buy: Value(buy),
    );
  }

  static SmokingRecipesCompanion _remoteToSmokingRecipeCompanion(
    Map<String, dynamic> row, {
    required bool isFavorite,
    required int cookCount,
  }) {
    String text(String key, [String fallback = '']) =>
        row[key] as String? ?? fallback;
    return SmokingRecipesCompanion(
      uuid: Value(text('uuid')),
      name: Value(text('name')),
      course: Value(text('course', 'smoking')),
      type: Value(text('type', 'pitNote')),
      item: Value(row['item'] as String?),
      category: Value(row['category'] as String?),
      temperature: Value(text('temperature')),
      time: Value(text('time')),
      wood: Value(text('wood')),
      seasoningsJson: Value(text('seasonings_json', '[]')),
      ingredientsJson: Value(text('ingredients_json', '[]')),
      serves: Value(row['serves'] as String?),
      directions: Value(text('directions', '[]')),
      notes: Value(row['notes'] as String?),
      headerImage: Value(row['header_image'] as String?),
      stepImages: Value(text('step_images', '[]')),
      stepImageMap: Value(text('step_image_map', '[]')),
      imageUrl: Value(row['image_url'] as String?),
      source: Value(text('source', 'personal')),
      pairedRecipeIds: Value(text('paired_recipe_ids', '[]')),
      createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String).toLocal()),
      isFavorite: Value(isFavorite),
      cookCount: Value(cookCount),
    );
  }

  static CoursesCompanion _remoteToCourseCompanion(
      Map<String, dynamic> row) {
    return CoursesCompanion(
      slug: Value(row['slug'] as String),
      name: Value(row['name'] as String),
      iconName: Value(row['icon_name'] as String?),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      colorValue: Value(row['color_value'] as int? ?? 0xFFFFB74D),
      isVisible: Value(row['is_visible'] as bool? ?? true),
    );
  }

  static ScratchPadsCompanion _remoteToScratchPadCompanion(
      Map<String, dynamic> row) {
    return ScratchPadsCompanion(
      uuid: Value(row['uuid'] as String? ?? ''),
      quickNotes: Value(row['quick_notes'] as String? ?? ''),
      updatedAt:
          Value(DateTime.parse(row['updated_at'] as String).toLocal()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the Supabase client, or throws [StateError] if not initialized.
  ///
  /// This is intentionally not null-returning — the caller's per-table
  /// try/catch in [sync] will catch and log the error.
  static SupabaseClient _requireClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('SupabaseSyncService: Supabase not initialized.');
    }
  }

  static DateTime? _getLastSync(SharedPreferences prefs, String key) {
    final iso = prefs.getString(key);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso).toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setLastSync(
    SharedPreferences prefs,
    String key,
    DateTime dt,
  ) async {
    await prefs.setString(key, dt.toIso8601String());
  }
}
