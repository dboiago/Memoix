import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart'
    hide Recipe, Ingredient, Course;
import '../../../core/database/app_database.dart'
    show Recipe as DriftRecipe,
        Ingredient as DriftIngredient,
        Course as DriftCourse;
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/utils/suggestions.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../models/course.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';

/// Repository for recipe data operations
class RecipeRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  RecipeRepository(this._db, this._ref);

  // ============ PRIVATE HELPERS ============

  RecipesCompanion _toCompanion(Recipe recipe) {
    return RecipesCompanion(
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
    );
  }

  List<IngredientsCompanion> _toIngredientCompanions(
      int recipeId, List<Ingredient> ingredients) {
    return ingredients
        .map((i) => IngredientsCompanion(
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

  Recipe _toIsarRecipe(DriftRecipe r, List<DriftIngredient> ings) {
    return Recipe()
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
            ..name = i.name
            ..amount = i.amount
            ..unit = i.unit
            ..preparation = i.notes
            ..alternative = i.alternative
            ..isOptional = i.isOptional
            ..section = i.section
            ..bakerPercent = i.bakerPercent)
          .toList();
  }

  void _normalizeIngredientUnits(Recipe recipe) {
    UnitNormalizer.normalizeUnitsInList(recipe.ingredients);
  }

  Course _toCourse(DriftCourse c) {
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

  Future<List<Recipe>> getAllRecipes() async {
    final rows = await _db.recipeDao.getAllRecipes();
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getRecipesByCourse(String course) async {
    final rows = await _db.recipeDao.getRecipesByCourse(course);
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getRecipesByCuisine(String cuisine) async {
    final rows = await _db.recipeDao.getRecipesByCuisine(cuisine);
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getRecipesBySource(RecipeSource source) async {
    final rows = await _db.recipeDao.getRecipesBySource(source.name);
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getPersonalRecipes() async {
    final rows = await _db.recipeDao.getPersonalRecipes();
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getMemoixRecipes() async {
    final rows = await _db.recipeDao.getMemoixRecipes();
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getImportedRecipes() async {
    final rows = await _db.recipeDao.getImportedRecipes();
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
  }

  Future<List<Recipe>> getFavorites() async {
    final rows = await _db.recipeDao.getFavoriteRecipes();
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));
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
    final results = await Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toIsarRecipe(r, ings);
    }));

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

  Future<int> saveRecipe(Recipe recipe) async {
    try {
      if (recipe.uuid.isEmpty) recipe.uuid = _uuid.v4();
    } catch (_) {
      recipe.uuid = _uuid.v4();
    }
    recipe.updatedAt = DateTime.now();
    _normalizeIngredientUnits(recipe);

    final companion = _toCompanion(recipe);
    final recipeId = await _db.recipeDao.saveRecipe(companion);
    await _db.recipeDao.deleteIngredientsForRecipe(recipeId);
    await _db.recipeDao
        .saveIngredients(_toIngredientCompanions(recipeId, recipe.ingredients));

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
    await _db.recipeDao.deleteRecipe(id);
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
      return Future.wait(rows.map((r) async {
        final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
        return _toIsarRecipe(r, ings);
      }));
    });
  }

  Stream<List<Recipe>> watchFavorites() {
    return _db.recipeDao.watchFavoriteRecipes().asyncMap((rows) async {
      return Future.wait(rows.map((r) async {
        final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
        return _toIsarRecipe(r, ings);
      }));
    });
  }

  Stream<List<Recipe>> watchRecipesByCourse(String course) {
    return _db.recipeDao.watchRecipesByCourse(course).asyncMap((rows) async {
      final recipes = await Future.wait(rows.map((r) async {
        final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
        return _toIsarRecipe(r, ings);
      }));

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
