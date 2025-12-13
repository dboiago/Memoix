import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../models/recipe.dart';
import '../models/category.dart';

/// Repository for recipe data operations
class RecipeRepository {
  final Isar _db;
  static final _uuid = Uuid();

  RecipeRepository(this._db);

  // ============ RECIPES ============

  /// Get all recipes
  Future<List<Recipe>> getAllRecipes() async {
    return _db.recipes.where().findAll();
  }

  /// Get recipes by course/category
  Future<List<Recipe>> getRecipesByCourse(String course) async {
    return _db.recipes.filter().courseEqualTo(course, caseSensitive: false).findAll();
  }

  /// Get recipes by cuisine
  Future<List<Recipe>> getRecipesByCuisine(String cuisine) async {
    return _db.recipes.filter().cuisineEqualTo(cuisine, caseSensitive: false).findAll();
  }

  /// Get recipes by source
  Future<List<Recipe>> getRecipesBySource(RecipeSource source) async {
    return _db.recipes.filter().sourceEqualTo(source).findAll();
  }

  /// Get personal recipes (user's own)
  Future<List<Recipe>> getPersonalRecipes() async {
    return _db.recipes.filter().sourceEqualTo(RecipeSource.personal).findAll();
  }

  /// Get memoix collection recipes (from GitHub)
  Future<List<Recipe>> getMemoixRecipes() async {
    return _db.recipes.filter().sourceEqualTo(RecipeSource.memoix).findAll();
  }

  /// Get imported/shared recipes
  Future<List<Recipe>> getImportedRecipes() async {
    return _db.recipes.filter().sourceEqualTo(RecipeSource.imported).findAll();
  }

  /// Get favorite recipes
  Future<List<Recipe>> getFavorites() async {
    return _db.recipes.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Search recipes by name
  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) return getAllRecipes();
    
    final allRecipes = await _db.recipes
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .cuisineContains(query, caseSensitive: false)
        .or()
        .tagsElementContains(query, caseSensitive: false)
        .findAll();

    // Sort by relevance: exact matches > starts with > contains
    final lowerQuery = query.toLowerCase();
    allRecipes.sort((a, b) {
      final aNameLower = a.name.toLowerCase();
      final bNameLower = b.name.toLowerCase();
      
      // Exact match on name
      if (aNameLower == lowerQuery && bNameLower != lowerQuery) return -1;
      if (bNameLower == lowerQuery && aNameLower != lowerQuery) return 1;
      
      // Exact match on cuisine
      final aCuisineLower = (a.cuisine ?? '').toLowerCase();
      final bCuisineLower = (b.cuisine ?? '').toLowerCase();
      if (aCuisineLower == lowerQuery && bCuisineLower != lowerQuery) return -1;
      if (bCuisineLower == lowerQuery && aCuisineLower != lowerQuery) return 1;
      
      // Starts with (prefix match)
      if (aNameLower.startsWith(lowerQuery) && !bNameLower.startsWith(lowerQuery)) return -1;
      if (bNameLower.startsWith(lowerQuery) && !aNameLower.startsWith(lowerQuery)) return 1;
      if (aCuisineLower.startsWith(lowerQuery) && !bCuisineLower.startsWith(lowerQuery)) return -1;
      if (bCuisineLower.startsWith(lowerQuery) && !aCuisineLower.startsWith(lowerQuery)) return 1;
      
      // Default: keep original order
      return 0;
    });
    
    return allRecipes;
  }

  /// Get a single recipe by ID
  Future<Recipe?> getRecipeById(int id) async {
    return _db.recipes.get(id);
  }

  /// Get a single recipe by UUID
  Future<Recipe?> getRecipeByUuid(String uuid) async {
    return _db.recipes.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Save a recipe (insert or update)
  Future<int> saveRecipe(Recipe recipe) async {
    // Ensure the recipe has a UUID
    try {
      if (recipe.uuid.isEmpty) {
        recipe.uuid = _uuid.v4();
      }
    } catch (_) {
      // If uuid was not initialized, set a new one
      recipe.uuid = _uuid.v4();
    }

    recipe.updatedAt = DateTime.now();
    // `createdAt` is initialized in the model; no-op here.

    return _db.writeTxn(() => _db.recipes.put(recipe));
  }

  /// Save multiple recipes
  Future<void> saveRecipes(List<Recipe> recipes) async {
    final now = DateTime.now();
    for (final recipe in recipes) {
      // Ensure each recipe has a uuid
      try {
        if (recipe.uuid.isEmpty) recipe.uuid = _uuid.v4();
      } catch (_) {
        recipe.uuid = _uuid.v4();
      }
      recipe.updatedAt = now;
    }
    await _db.writeTxn(() => _db.recipes.putAll(recipes));
  }

  /// Delete a recipe
  Future<bool> deleteRecipe(int id) async {
    return _db.writeTxn(() => _db.recipes.delete(id));
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(int id) async {
    final recipe = await getRecipeById(id);
    if (recipe != null) {
      recipe.isFavorite = !recipe.isFavorite;
      await saveRecipe(recipe);
    }
  }

  /// Watch all recipes (stream)
  Stream<List<Recipe>> watchAllRecipes() {
    return _db.recipes.where().watch(fireImmediately: true);
  }

  /// Watch favorite recipes (stream)
  Stream<List<Recipe>> watchFavorites() {
    return _db.recipes
        .filter()
        .isFavoriteEqualTo(true)
        .watch(fireImmediately: true);
  }

  /// Watch recipes by course (sorted alphabetically by name)
  Stream<List<Recipe>> watchRecipesByCourse(String course) {
    return _db.recipes
        .filter()
        .courseEqualTo(course, caseSensitive: false)
        .sortByName()
        .watch(fireImmediately: true);
  }

  // ============ CATEGORIES ============

  /// Get all categories sorted by order
  Future<List<Category>> getAllCategories() async {
    return _db.categorys.where().sortBySortOrder().findAll();
  }

  /// Get visible categories only
  Future<List<Category>> getVisibleCategories() async {
    return _db.categorys
        .filter()
        .isVisibleEqualTo(true)
        .sortBySortOrder()
        .findAll();
  }

  /// Save a category
  Future<int> saveCategory(Category category) async {
    return _db.writeTxn(() => _db.categorys.put(category));
  }

  /// Watch categories
  Stream<List<Category>> watchCategories() {
    return _db.categorys.where().sortBySortOrder().watch(fireImmediately: true);
  }

  // ============ SYNC HELPERS ============

  /// Replace all memoix recipes (for sync from GitHub)
  Future<void> syncMemoixRecipes(List<Recipe> recipes) async {
    await _db.writeTxn(() async {
      // Delete existing memoix recipes
      await _db.recipes.filter().sourceEqualTo(RecipeSource.memoix).deleteAll();
      // Insert new ones
      await _db.recipes.putAll(recipes);
    });
  }

  /// Get last sync time (stored as a recipe tag, hacky but works)
  Future<DateTime?> getLastSyncTime() async {
    // Could use SharedPreferences, but keeping it simple
    return null;
  }
}

// ============ PROVIDERS ============

/// Provider for recipe repository
/// Provider for recipe repository
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(databaseProvider));
});

/// Provider for all recipes
final allRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchAllRecipes();
});

/// Provider for recipes filtered by course
final recipesByCourseProvider = StreamProvider.family<List<Recipe>, String>((ref, course) {
  return ref.watch(recipeRepositoryProvider).watchRecipesByCourse(course);
});

/// Provider for categories
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchCategories();
});

/// Provider for favorite recipes (stream-based for real-time updates)
final favoriteRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).watchFavorites();
});

/// Provider for recipe search
final recipeSearchProvider = FutureProvider.family<List<Recipe>, String>((ref, query) {
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
