import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../../personal_storage/services/tombstone_store.dart';
import '../models/smoking_recipe.dart';

/// Repository for smoking recipe operations
class SmokingRepository {
  final AppDatabase _db;
  final Ref _ref;

  SmokingRepository(this._db, this._ref);

  /// Get all smoking recipes
  Future<List<SmokingRecipe>> getAllRecipes() =>
      _db.smokingDao.getAllRecipes();

  /// Get recipes by wood type
  Future<List<SmokingRecipe>> getRecipesByWood(String wood) =>
      _db.smokingDao.getRecipesByWood(wood);

  /// Get recipes by type
  Future<List<SmokingRecipe>> getRecipesByType(String type) =>
      _db.smokingDao.getRecipesByType(type);

  /// Get a recipe by UUID
  Future<SmokingRecipe?> getRecipeByUuid(String uuid) =>
      _db.smokingDao.getRecipeByUuid(uuid);

  /// Save a smoking recipe
  Future<void> saveRecipe(SmokingRecipe recipe, {bool preserveTimestamp = false}) async {
    final normalizedSeasoningsJson = jsonEncode(
      _normalizeSeasoningUnits(
        (jsonDecode(recipe.seasoningsJson) as List)
            .map((e) {
              final m = e as Map<String, dynamic>;
              return SmokingSeasoning.create(
                name: m['name']?.toString() ?? '',
                amount: m['amount']?.toString(),
                unit: m['unit']?.toString(),
              );
            })
            .toList(),
      ).map((s) => {'name': s.name, 'amount': s.amount, 'unit': s.unit}).toList(),
    );
    final normalizedIngredientsJson = jsonEncode(
      _normalizeSeasoningUnits(
        (jsonDecode(recipe.ingredientsJson) as List)
            .map((e) {
              final m = e as Map<String, dynamic>;
              return SmokingSeasoning.create(
                name: m['name']?.toString() ?? '',
                amount: m['amount']?.toString(),
                unit: m['unit']?.toString(),
              );
            })
            .toList(),
      ).map((s) => {'name': s.name, 'amount': s.amount, 'unit': s.unit}).toList(),
    );
    await _db.smokingDao.saveRecipe(SmokingRecipesCompanion(
      id: recipe.id > 0 ? Value(recipe.id) : const Value.absent(),
      uuid: Value(recipe.uuid),
      name: Value(recipe.name),
      course: Value(recipe.course),
      type: Value(recipe.type),
      item: Value(recipe.item),
      category: Value(recipe.category),
      temperature: Value(recipe.temperature),
      time: Value(recipe.time),
      wood: Value(recipe.wood),
      seasoningsJson: Value(normalizedSeasoningsJson),
      ingredientsJson: Value(normalizedIngredientsJson),
      serves: Value(recipe.serves),
      directions: Value(recipe.directions),
      notes: Value(recipe.notes),
      headerImage: Value(recipe.headerImage),
      stepImages: Value(recipe.stepImages),
      stepImageMap: Value(recipe.stepImageMap),
      imageUrl: Value(recipe.imageUrl),
      isFavorite: Value(recipe.isFavorite),
      cookCount: Value(recipe.cookCount),
      source: Value(recipe.source),
      pairedRecipeIds: Value(recipe.pairedRecipeIds),
      createdAt: Value(recipe.createdAt),
      updatedAt: Value(preserveTimestamp ? recipe.updatedAt : DateTime.now()),
    ),);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  List<SmokingSeasoning> _normalizeSeasoningUnits(List<SmokingSeasoning> items) {
    UnitNormalizer.normalizeUnitsInList(items);
    return items;
  }

  /// Delete a smoking recipe
  Future<void> deleteRecipe(SmokingRecipe recipe, {bool fromMerge = false}) async {
    if (!fromMerge) {
      await TombstoneStore.add(TombstoneDomain.smoking, recipe.uuid);
    }
    await _db.smokingDao.deleteRecipe(recipe.id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete a smoking recipe by UUID. Pass [fromMerge] = true when called
  /// during a pull merge to prevent recording a tombstone.
  Future<void> deleteRecipeByUuid(String uuid, {bool fromMerge = false}) async {
    final recipe = await getRecipeByUuid(uuid);
    if (recipe != null) {
      await deleteRecipe(recipe, fromMerge: fromMerge);
      unawaited(SupabaseSyncService.notifyDeleted('smoking_recipes', uuid));
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(SmokingRecipe recipe) async {
    final wasFavorited = recipe.isFavorite;
    await _db.smokingDao.toggleFavorite(recipe.id, recipe.isFavorite);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': recipe.uuid,
        'is_adding': !wasFavorited,
      },
    );
  }

  /// Increment cook count
  Future<void> incrementCookCount(SmokingRecipe recipe) =>
      _db.smokingDao.incrementCookCount(recipe.id);

  /// Watch all recipes
  Stream<List<SmokingRecipe>> watchAll() => _db.smokingDao.watchAll();

  /// Watch recipes by type
  Stream<List<SmokingRecipe>> watchByType(String type) =>
      _db.smokingDao.watchByType(type);

  /// Get count of smoking recipes
  Future<int> getCount() => _db.smokingDao.getCount();

  /// Get count of recipes by type
  Future<int> getCountByType(String type) =>
      _db.smokingDao.getCountByType(type);

  /// Get available wood types that have recipes
  Future<Set<String>> getAvailableWoods() async {
    final recipes = await getAllRecipes();
    return recipes.map((r) => r.wood).toSet();
  }

  /// Watch favorite recipes
  Stream<List<SmokingRecipe>> watchFavorites() =>
      _db.smokingDao.watchFavorites();
}

// Providers
final smokingRepositoryProvider = Provider<SmokingRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SmokingRepository(db, ref);
});

final allSmokingRecipesProvider = StreamProvider<List<SmokingRecipe>>((ref) {
  final repo = ref.watch(smokingRepositoryProvider);
  return repo.watchAll();
});

/// Favorite smoking recipes (stream)
final favoriteSmokingRecipesProvider = StreamProvider<List<SmokingRecipe>>((ref) {
  final repo = ref.watch(smokingRepositoryProvider);
  return repo.watchFavorites();
});

/// Smoking recipe count (derived from stream for auto-update)
final smokingCountProvider = Provider<AsyncValue<int>>((ref) {
  final recipesAsync = ref.watch(allSmokingRecipesProvider);
  return recipesAsync.whenData((recipes) => recipes.length);
});

final smokingRecipeByUuidProvider = FutureProvider.family<SmokingRecipe?, String>((ref, uuid) async {
  final repo = ref.watch(smokingRepositoryProvider);
  return repo.getRecipeByUuid(uuid);
});
