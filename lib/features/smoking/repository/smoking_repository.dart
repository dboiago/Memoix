import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/providers.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/smoking_recipe.dart';

/// Repository for smoking recipe operations
class SmokingRepository {
  final Isar _db;

  SmokingRepository(this._db);

  /// Get all smoking recipes
  Future<List<SmokingRecipe>> getAllRecipes() async {
    return await _db.smokingRecipes.where().sortByName().findAll();
  }

  /// Get recipes by wood type
  Future<List<SmokingRecipe>> getRecipesByWood(String wood) async {
    return await _db.smokingRecipes
        .where()
        .filter()
        .woodEqualTo(wood, caseSensitive: false)
        .sortByName()
        .findAll();
  }

  /// Get a recipe by UUID
  Future<SmokingRecipe?> getRecipeByUuid(String uuid) async {
    return await _db.smokingRecipes
        .where()
        .uuidEqualTo(uuid)
        .findFirst();
  }

  /// Save a smoking recipe
  Future<void> saveRecipe(SmokingRecipe recipe) async {
    recipe.updatedAt = DateTime.now();
    // Normalize seasoning units
    _normalizeSeasoningUnits(recipe);
    await _db.writeTxn(() => _db.smokingRecipes.put(recipe));
  }
  
  /// Normalize seasoning units to standard abbreviations
  void _normalizeSeasoningUnits(SmokingRecipe recipe) {
    UnitNormalizer.normalizeUnitsInList(recipe.seasonings);
  }

  /// Delete a smoking recipe by UUID
  Future<void> deleteRecipe(String uuid) async {
    final recipe = await getRecipeByUuid(uuid);
    if (recipe != null) {
      await _db.writeTxn(() => _db.smokingRecipes.delete(recipe.id));
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String uuid) async {
    final recipe = await getRecipeByUuid(uuid);
    if (recipe != null) {
      recipe.isFavorite = !recipe.isFavorite;
      recipe.updatedAt = DateTime.now();
      await _db.writeTxn(() => _db.smokingRecipes.put(recipe));
    }
  }

  /// Increment cook count
  Future<void> incrementCookCount(String uuid) async {
    final recipe = await getRecipeByUuid(uuid);
    if (recipe != null) {
      recipe.cookCount += 1;
      recipe.updatedAt = DateTime.now();
      await _db.writeTxn(() => _db.smokingRecipes.put(recipe));
    }
  }

  /// Watch all recipes
  Stream<List<SmokingRecipe>> watchAll() {
    return _db.smokingRecipes.where().sortByName().watch(fireImmediately: true);
  }

  /// Get count of smoking recipes
  Future<int> getCount() async {
    return await _db.smokingRecipes.count();
  }

  /// Get available wood types that have recipes
  Future<Set<String>> getAvailableWoods() async {
    final recipes = await getAllRecipes();
    return recipes.map((r) => r.wood).toSet();
  }

  /// Watch favorite recipes
  Stream<List<SmokingRecipe>> watchFavorites() {
    return _db.smokingRecipes
        .where()
        .filter()
        .isFavoriteEqualTo(true)
        .sortByName()
        .watch(fireImmediately: true);
  }
}

// Providers
final smokingRepositoryProvider = Provider<SmokingRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SmokingRepository(db);
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
