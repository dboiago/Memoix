import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../models/modernist_recipe.dart';

/// Repository for modernist recipe CRUD operations
class ModernistRepository {
  final Isar _db;
  static const _uuid = Uuid();

  ModernistRepository(this._db);

  /// Watch all modernist recipes
  Stream<List<ModernistRecipe>> watchAll() {
    return _db.modernistRecipes
        .where()
        .sortByName()
        .watch(fireImmediately: true);
  }

  /// Watch recipes by type (Concept or Technique)
  Stream<List<ModernistRecipe>> watchByType(ModernistType type) {
    return _db.modernistRecipes
        .where()
        .filter()
        .typeEqualTo(type)
        .sortByName()
        .watch(fireImmediately: true);
  }

  /// Watch recipes by technique category
  Stream<List<ModernistRecipe>> watchByTechnique(String technique) {
    return _db.modernistRecipes
        .where()
        .filter()
        .techniqueEqualTo(technique, caseSensitive: false)
        .sortByName()
        .watch(fireImmediately: true);
  }

  /// Get all recipes
  Future<List<ModernistRecipe>> getAll() {
    return _db.modernistRecipes.where().sortByName().findAll();
  }

  /// Get recipe by ID
  Future<ModernistRecipe?> getById(int id) {
    return _db.modernistRecipes.get(id);
  }

  /// Get recipe by UUID
  Future<ModernistRecipe?> getByUuid(String uuid) {
    return _db.modernistRecipes.where().uuidEqualTo(uuid).findFirst();
  }

  /// Get count of all recipes
  Future<int> getCount() {
    return _db.modernistRecipes.count();
  }

  /// Save a recipe (insert or update)
  Future<int> save(ModernistRecipe recipe) async {
    recipe.updatedAt = DateTime.now();
    // Normalize ingredient units
    _normalizeIngredientUnits(recipe);
    return _db.writeTxn(() => _db.modernistRecipes.put(recipe));
  }
  
  /// Normalize ingredient units to standard abbreviations
  void _normalizeIngredientUnits(ModernistRecipe recipe) {
    UnitNormalizer.normalizeUnitsInList(recipe.ingredients);
  }

  /// Create a new recipe with generated UUID
  Future<ModernistRecipe> create({
    required String name,
    String course = 'modernist',
    ModernistType type = ModernistType.concept,
    String? technique,
    String? serves,
    String? time,
    String? difficulty,
    List<String>? equipment,
    List<ModernistIngredient>? ingredients,
    List<String>? directions,
    String? notes,
    String? scienceNotes,
    String? sourceUrl,
    String? headerImage,
    List<String>? stepImages,
    List<String>? stepImageMap,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? pairedRecipeIds,
    ModernistSource source = ModernistSource.personal,
  }) async {
    final recipe = ModernistRecipe.create(
      uuid: _uuid.v4(),
      name: name,
      course: course,
      type: type,
      technique: technique,
      serves: serves,
      time: time,
      difficulty: difficulty,
      equipment: equipment,
      ingredients: ingredients,
      directions: directions,
      notes: notes,
      scienceNotes: scienceNotes,
      sourceUrl: sourceUrl,
      headerImage: headerImage,
      stepImages: stepImages,
      stepImageMap: stepImageMap,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      pairedRecipeIds: pairedRecipeIds,
      source: source,
    );

    await save(recipe);
    return recipe;
  }

  /// Delete a recipe
  Future<bool> delete(int id) {
    return _db.writeTxn(() => _db.modernistRecipes.delete(id));
  }

  /// Delete by UUID
  Future<bool> deleteByUuid(String uuid) async {
    final recipe = await getByUuid(uuid);
    if (recipe == null) return false;
    return delete(recipe.id);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(int id) async {
    await _db.writeTxn(() async {
      final recipe = await _db.modernistRecipes.get(id);
      if (recipe == null) return;

      recipe.isFavorite = !recipe.isFavorite;
      recipe.updatedAt = DateTime.now();
      await _db.modernistRecipes.put(recipe);
    });
  }

  /// Increment cook count
  Future<void> incrementCookCount(int id) async {
    await _db.writeTxn(() async {
      final recipe = await _db.modernistRecipes.get(id);
      if (recipe == null) return;

      recipe.cookCount++;
      recipe.updatedAt = DateTime.now();
      await _db.modernistRecipes.put(recipe);
    });
  }

  /// Get unique technique categories from all recipes
  Future<List<String>> getUniqueTechniques() async {
    final recipes = await getAll();
    final techniques = <String>{};
    for (final recipe in recipes) {
      if (recipe.technique != null && recipe.technique!.isNotEmpty) {
        techniques.add(recipe.technique!);
      }
    }
    return techniques.toList()..sort();
  }

  /// Search recipes
  Future<List<ModernistRecipe>> search(String query) async {
    if (query.isEmpty) return getAll();
    
    final lower = query.toLowerCase();
    final all = await getAll();
    
    return all.where((r) {
      return r.name.toLowerCase().contains(lower) ||
          (r.technique?.toLowerCase().contains(lower) ?? false) ||
          r.equipment.any((e) => e.toLowerCase().contains(lower)) ||
          r.ingredients.any((i) => i.name.toLowerCase().contains(lower));
    }).toList();
  }

  /// Watch favorite recipes
  Stream<List<ModernistRecipe>> watchFavorites() {
    return _db.modernistRecipes
        .where()
        .filter()
        .isFavoriteEqualTo(true)
        .sortByName()
        .watch(fireImmediately: true);
  }
}

// ============ PROVIDERS ============

/// Repository provider
final modernistRepositoryProvider = Provider<ModernistRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ModernistRepository(db);
});

/// All modernist recipes (stream)
final allModernistRecipesProvider = StreamProvider<List<ModernistRecipe>>((ref) {
  return ref.watch(modernistRepositoryProvider).watchAll();
});

/// Favorite modernist recipes (stream)
final favoriteModernistRecipesProvider = StreamProvider<List<ModernistRecipe>>((ref) {
  return ref.watch(modernistRepositoryProvider).watchFavorites();
});

/// Modernist recipes by type
final modernistByTypeProvider = StreamProvider.family<List<ModernistRecipe>, ModernistType>((ref, type) {
  return ref.watch(modernistRepositoryProvider).watchByType(type);
});

/// Modernist recipes by technique
final modernistByTechniqueProvider = StreamProvider.family<List<ModernistRecipe>, String>((ref, technique) {
  return ref.watch(modernistRepositoryProvider).watchByTechnique(technique);
});

/// Total count of modernist recipes (derived from stream for auto-update)
final modernistCountProvider = Provider<AsyncValue<int>>((ref) {
  final recipesAsync = ref.watch(allModernistRecipesProvider);
  return recipesAsync.whenData((recipes) => recipes.length);
});

/// Unique techniques used in recipes
final modernistTechniquesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(modernistRepositoryProvider).getUniqueTechniques();
});

/// Single recipe by ID (for detail view)
final modernistRecipeProvider = FutureProvider.family<ModernistRecipe?, int>((ref, id) {
  return ref.watch(modernistRepositoryProvider).getById(id);
});
