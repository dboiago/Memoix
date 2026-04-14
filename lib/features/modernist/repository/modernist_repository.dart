import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/utils/unit_normalizer.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../../personal_storage/services/tombstone_store.dart';
import '../models/modernist_recipe.dart';

/// Repository for modernist recipe CRUD operations
class ModernistRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  ModernistRepository(this._db, this._ref);

  // ── Private helpers ──────────────────────────────────────────────────────

  ModernistRecipe _toModernistRecipe(Recipe r, List<Ingredient> ings) {
    return ModernistRecipe()
      ..id = r.id
      ..uuid = r.uuid
      ..name = r.name
      ..course = r.course
      ..type = ModernistTypeExtension.fromString(r.modernistType)
      ..technique = r.technique
      ..serves = r.serves
      ..time = r.time
      ..difficulty = r.difficulty
      ..equipment = r.equipmentJson != null
          ? (jsonDecode(r.equipmentJson!) as List).cast<String>()
          : []
      ..ingredients = ings
          .map((i) => ModernistIngredient.create(
                name: i.name,
                amount: i.amount,
                unit: i.unit,
                notes: i.notes,
                section: i.section,
              ),)
          .toList()
      ..directions = (jsonDecode(r.directions) as List).cast<String>()
      ..notes = r.comments
      ..scienceNotes = r.scienceNotes
      ..sourceUrl = r.sourceUrl
      ..headerImage = r.headerImage
      ..stepImages = (jsonDecode(r.stepImages) as List).cast<String>()
      ..stepImageMap = (jsonDecode(r.stepImageMap) as List).cast<String>()
      ..imageUrl = r.imageUrl
      ..imageUrls = (jsonDecode(r.imageUrls) as List).cast<String>()
      ..isFavorite = r.isFavorite
      ..cookCount = r.cookCount
      ..source = ModernistSource.values.firstWhere(
            (s) => s.name == r.source,
            orElse: () => ModernistSource.personal,)
      ..pairedRecipeIds =
          (jsonDecode(r.pairedRecipeIds) as List).cast<String>()
      ..createdAt = r.createdAt
      ..updatedAt = r.updatedAt;
  }

  // ── Watch methods ────────────────────────────────────────────────────────

  Stream<List<ModernistRecipe>> _watchModernistWithIngredients(
      bool Function(Recipe) filter,) {
    return _db.recipeDao.watchRecipesByType('modernist').asyncMap((rows) async {
      final filtered = rows.where(filter).toList();
      if (filtered.isEmpty) return <ModernistRecipe>[];
      final allIngs = await _db.recipeDao
          .getIngredientsForRecipes(filtered.map((r) => r.id));
      final grouped = <int, List<Ingredient>>{};
      for (final ing in allIngs) {
        grouped.putIfAbsent(ing.recipeId, () => []).add(ing);
      }
      return filtered
          .map((r) => _toModernistRecipe(r, grouped[r.id] ?? []))
          .toList();
    });
  }

  /// Watch all modernist recipes
  Stream<List<ModernistRecipe>> watchAll() =>
      _watchModernistWithIngredients((_) => true);

  /// Watch recipes by type (Concept or Technique)
  Stream<List<ModernistRecipe>> watchByType(ModernistType type) =>
      _watchModernistWithIngredients(
          (r) => r.modernistType == type.name,);

  /// Watch recipes by technique category
  Stream<List<ModernistRecipe>> watchByTechnique(String technique) =>
      _watchModernistWithIngredients(
          (r) => r.technique?.toLowerCase() == technique.toLowerCase(),);

  /// Watch favorite recipes
  Stream<List<ModernistRecipe>> watchFavorites() =>
      _watchModernistWithIngredients((r) => r.isFavorite);

  // ── Fetch methods ────────────────────────────────────────────────────────

  /// Get all recipes
  Future<List<ModernistRecipe>> getAll() async {
    final rows = await _db.recipeDao.getRecipesByType('modernist');
    return Future.wait(rows.map((r) async {
      final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
      return _toModernistRecipe(r, ings);
    }),);
  }

  /// Get recipe by ID
  Future<ModernistRecipe?> getById(int id) async {
    final r = await _db.recipeDao.getRecipeById(id);
    if (r == null) return null;
    final ings = await _db.recipeDao.getIngredientsForRecipe(id);
    return _toModernistRecipe(r, ings);
  }

  /// Get recipe by UUID
  Future<ModernistRecipe?> getByUuid(String uuid) async {
    final r = await _db.recipeDao.getRecipeByUuid(uuid);
    if (r == null) return null;
    final ings = await _db.recipeDao.getIngredientsForRecipe(r.id);
    return _toModernistRecipe(r, ings);
  }

  /// Get count of all recipes
  Future<int> getCount() async {
    final all = await getAll();
    return all.length;
  }

  // ── Write methods ────────────────────────────────────────────────────────

  /// Save a recipe (insert or update)
  Future<int> save(ModernistRecipe recipe, {bool preserveTimestamp = false}) async {
    UnitNormalizer.normalizeUnitsInList(recipe.ingredients);
    final entryUuid = recipe.uuid.isEmpty ? _uuid.v4() : recipe.uuid;
    final recipeId = await _db.recipeDao.saveRecipe(RecipesCompanion(
      id: recipe.id > 0 ? Value(recipe.id) : const Value.absent(),
      uuid: Value(entryUuid),
      name: Value(recipe.name),
      course: Value(recipe.course),
      recipeType: const Value('modernist'),
      modernistType: Value(recipe.type.name),
      technique: Value(recipe.technique),
      serves: Value(recipe.serves),
      time: Value(recipe.time),
      difficulty: Value(recipe.difficulty),
      equipmentJson: Value(jsonEncode(recipe.equipment)),
      directions: Value(jsonEncode(recipe.directions)),
      comments: Value(recipe.notes),
      scienceNotes: Value(recipe.scienceNotes),
      sourceUrl: Value(recipe.sourceUrl),
      headerImage: Value(recipe.headerImage),
      stepImages: Value(jsonEncode(recipe.stepImages)),
      stepImageMap: Value(jsonEncode(recipe.stepImageMap)),
      imageUrl: Value(recipe.imageUrl),
      imageUrls: Value(jsonEncode(recipe.imageUrls)),
      isFavorite: Value(recipe.isFavorite),
      cookCount: Value(recipe.cookCount),
      source: Value(recipe.source.name),
      pairedRecipeIds: Value(jsonEncode(recipe.pairedRecipeIds)),
      createdAt: Value(recipe.createdAt),
      updatedAt: Value(preserveTimestamp ? recipe.updatedAt : DateTime.now()),
    ),);
    await _db.recipeDao.deleteIngredientsForRecipe(recipeId);
    final ingredientCompanions = recipe.ingredients
        .map((i) => IngredientsCompanion(
              recipeId: Value(recipeId),
              name: Value(i.name),
              amount: Value(i.amount),
              unit: Value(i.unit),
              notes: Value(i.notes),
              alternative: const Value(null),
              isOptional: const Value(false),
              section: Value(i.section),
              bakerPercent: const Value(null),
            ),)
        .toList();
    await _db.recipeDao.saveIngredients(ingredientCompanions);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    return recipeId;
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
    final dbId = await save(recipe);
    recipe.id = dbId;
    return recipe;
  }

  /// Delete a recipe
  Future<bool> delete(int id) async {
    await _db.recipeDao.deleteRecipe(id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    return true;
  }

  /// Delete by UUID
  Future<bool> deleteByUuid(String uuid, {bool fromMerge = false}) async {
    if (!fromMerge) {
      await TombstoneStore.add(TombstoneDomain.modernist, uuid);
    }
    final recipe = await getByUuid(uuid);
    if (recipe == null) return false;
    return delete(recipe.id);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(int id) async {
    final existing = await _db.recipeDao.getRecipeById(id);
    if (existing == null) return;
    final wasFavorited = existing.isFavorite;
    await _db.recipeDao.toggleFavorite(id, existing.isFavorite);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': id,
        'is_adding': !wasFavorited,
      },
    );
  }

  /// Increment cook count
  Future<void> incrementCookCount(int id) async {
    final existing = await _db.recipeDao.getRecipeById(id);
    if (existing == null) return;
    await _db.recipeDao.saveRecipe(RecipesCompanion(
      id: Value(existing.id),
      uuid: Value(existing.uuid),
      name: Value(existing.name),
      course: Value(existing.course),
      cuisine: Value(existing.cuisine),
      subcategory: Value(existing.subcategory),
      continent: Value(existing.continent),
      country: Value(existing.country),
      serves: Value(existing.serves),
      time: Value(existing.time),
      pairsWith: Value(existing.pairsWith),
      pairedRecipeIds: Value(existing.pairedRecipeIds),
      comments: Value(existing.comments),
      directions: Value(existing.directions),
      sourceUrl: Value(existing.sourceUrl),
      imageUrls: Value(existing.imageUrls),
      imageUrl: Value(existing.imageUrl),
      headerImage: Value(existing.headerImage),
      stepImages: Value(existing.stepImages),
      stepImageMap: Value(existing.stepImageMap),
      source: Value(existing.source),
      colorValue: Value(existing.colorValue),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
      isFavorite: Value(existing.isFavorite),
      rating: Value(existing.rating),
      cookCount: Value(existing.cookCount + 1),
      editCount: Value(existing.editCount),
      firstEditAt: Value(existing.firstEditAt),
      lastEditAt: Value(existing.lastEditAt),
      lastCookedAt: Value(existing.lastCookedAt),
      tags: Value(existing.tags),
      version: Value(existing.version),
      nutrition: Value(existing.nutrition),
      modernistType: Value(existing.modernistType),
      smokingType: Value(existing.smokingType),
      glass: Value(existing.glass),
      garnish: Value(existing.garnish),
      pickleMethod: Value(existing.pickleMethod),
      recipeType: Value(existing.recipeType),
      technique: Value(existing.technique),
      difficulty: Value(existing.difficulty),
      scienceNotes: Value(existing.scienceNotes),
      equipmentJson: Value(existing.equipmentJson),
    ),);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
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
}

// ============ PROVIDERS ============

/// Repository provider
final modernistRepositoryProvider = Provider<ModernistRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ModernistRepository(db, ref);
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
