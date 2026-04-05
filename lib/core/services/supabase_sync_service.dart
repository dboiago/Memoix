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
