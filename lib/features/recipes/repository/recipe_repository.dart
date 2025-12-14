import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/category.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';

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
    
    // Normalize ingredient units
    _normalizeIngredientUnits(recipe);

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
      // Normalize ingredient units
      _normalizeIngredientUnits(recipe);
    }
    await _db.writeTxn(() => _db.recipes.putAll(recipes));
  }
  
  /// Normalize ingredient units to standard abbreviations
  void _normalizeIngredientUnits(Recipe recipe) {
    for (final ingredient in recipe.ingredients) {
      if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
        ingredient.unit = UnitNormalizer.normalize(ingredient.unit);
      }
    }
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

  /// Watch recipes by course (sorted by cuisine region, country, province, then name)
  Stream<List<Recipe>> watchRecipesByCourse(String course) {
    return _db.recipes
        .filter()
        .courseEqualTo(course, caseSensitive: false)
        .watch(fireImmediately: true)
        .map((recipes) {
          // Define continent order for sorting
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
          
          // Sort by: 1) Continent, 2) Country, 3) Subcategory (province), 4) Recipe name
          recipes.sort((a, b) {
            // 1. Compare by continent
            final aCont = Cuisine.continentFor(a.cuisine);
            final bCont = Cuisine.continentFor(b.cuisine);
            
            final aContIndex = aCont != null ? continentOrder.indexOf(aCont) : continentOrder.length;
            final bContIndex = bCont != null ? continentOrder.indexOf(bCont) : continentOrder.length;
            final aOrder = aContIndex == -1 ? continentOrder.length : aContIndex;
            final bOrder = bContIndex == -1 ? continentOrder.length : bContIndex;
            
            if (aOrder != bOrder) {
              return aOrder.compareTo(bOrder);
            }
            
            // 2. Same continent, compare by country name
            final aCountry = Cuisine.toAdjective(a.cuisine);
            final bCountry = Cuisine.toAdjective(b.cuisine);
            
            if (aCountry != bCountry) {
              return aCountry.toLowerCase().compareTo(bCountry.toLowerCase());
            }
            
            // 3. Same country, compare by subcategory (province/region)
            final aProvince = a.subcategory ?? '';
            final bProvince = b.subcategory ?? '';
            
            if (aProvince != bProvince) {
              return aProvince.toLowerCase().compareTo(bProvince.toLowerCase());
            }
            
            // 4. Same province, sort by recipe name
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          return recipes;
        });
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
