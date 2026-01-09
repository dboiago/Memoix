import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/utils/suggestions.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../models/course.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';

/// Repository for recipe data operations
class RecipeRepository {
  final Isar _db;
  final Ref _ref;
  static const _uuid = Uuid();

  RecipeRepository(this._db, this._ref);

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

    final result = await _db.writeTxn(() => _db.recipes.put(recipe));
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
    
    return result;
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
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
  }
  
  /// Normalize ingredient units to standard abbreviations
  void _normalizeIngredientUnits(Recipe recipe) {
    UnitNormalizer.normalizeUnitsInList(recipe.ingredients);
  }

  /// Delete a recipe
  Future<bool> deleteRecipe(int id) async {
    final result = await _db.writeTxn(() => _db.recipes.delete(id));
    
    // Notify external storage service of change
    if (result) {
      _ref.read(externalStorageServiceProvider).onRecipeChanged();
    }
    
    return result;
  }

  /// Get recipes that pair with the given recipe (inverse lookup).
  /// Finds recipes that have this recipe's UUID in their pairedRecipeIds list.
  Future<List<Recipe>> getRecipesPairedWith(String recipeUuid) async {
    final all = await _db.recipes.where().findAll();
    return all.where((r) => r.pairedRecipeIds.contains(recipeUuid)).toList();
  }

  /// Get multiple recipes by their UUIDs
  Future<List<Recipe>> getRecipesByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return [];
    final results = <Recipe>[];
    for (final uuid in uuids) {
      final recipe = await getRecipeByUuid(uuid);
      if (recipe != null) results.add(recipe);
    }
    return results;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(int id) async {
    await _db.writeTxn(() async {
      final recipe = await _db.recipes.get(id);
      if (recipe != null) {
        recipe.isFavorite = !recipe.isFavorite;
        recipe.updatedAt = DateTime.now();
        await _db.recipes.put(recipe);
      }
    });
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
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

  // ============ COURSES ============

  /// Get all courses sorted by order
  Future<List<Course>> getAllCourses() async {
    return _db.courses.where().sortBySortOrder().findAll();
  }

  /// Get visible courses only
  Future<List<Course>> getVisibleCourses() async {
    return _db.courses
        .filter()
        .isVisibleEqualTo(true)
        .sortBySortOrder()
        .findAll();
  }

  /// Save a course
  Future<int> saveCourse(Course course) async {
    return _db.writeTxn(() => _db.courses.put(course));
  }

  /// Watch courses
  Stream<List<Course>> watchCourses() {
    return _db.courses.where().sortBySortOrder().watch(fireImmediately: true);
  }

  // ============ INGREDIENT SUGGESTIONS ============

  /// Get ingredient name suggestions based on user's history + defaults
  /// Returns unique names that match the query, sorted alphabetically
  Future<List<String>> getIngredientNameSuggestions(String query) async {
    // Get all ingredient names from saved recipes
    final allRecipes = await _db.recipes.where().findAll();
    
    // Extract all ingredient names and deduplicate with a Set
    final historyNames = <String>{};
    for (final recipe in allRecipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.name.isNotEmpty) {
          historyNames.add(ingredient.name);
        }
      }
    }
    
    // Merge with essential defaults
    final allNames = <String>{...Suggestions.essentialIngredients, ...historyNames};
    
    // Filter by query (case-insensitive contains match)
    final lowerQuery = query.toLowerCase();
    final filtered = allNames
        .where((name) => name.toLowerCase().contains(lowerQuery))
        .toList();
    
    // Sort with "starts with" matches first, then alphabetically
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

  /// Get prep/notes suggestions based on user's history + defaults
  /// Returns unique prep notes that match the query, sorted alphabetically
  Future<List<String>> getPrepNoteSuggestions(String query) async {
    // Get all preparation notes from saved recipes
    final allRecipes = await _db.recipes.where().findAll();
    
    // Extract all preparation notes and deduplicate with a Set
    final historyNotes = <String>{};
    for (final recipe in allRecipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) {
          historyNotes.add(ingredient.preparation!);
        }
      }
    }
    
    // Merge with essential defaults and the full preparations list
    final allNotes = <String>{
      ...Suggestions.essentialPrepNotes,
      ...Suggestions.preparations,
      ...historyNotes,
    };
    
    // Filter by query (case-insensitive contains match)
    final lowerQuery = query.toLowerCase();
    final filtered = allNotes
        .where((note) => note.toLowerCase().contains(lowerQuery))
        .toList();
    
    // Sort with "starts with" matches first, then alphabetically
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
