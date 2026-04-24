import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'recipe_dao.g.dart';

@DriftAccessor(tables: [Recipes, Ingredients, Courses])
class RecipeDao extends DatabaseAccessor<AppDatabase>
    with _$RecipeDaoMixin {
  RecipeDao(super.db);

  // ── Recipe read ────────────────────────────────────────────────────────────

  Future<List<Recipe>> getAllRecipes() => select(recipes).get();

  Future<List<Recipe>> getRecipesByCourse(String course) =>
      (select(recipes)
            ..where((r) => r.course.lower().equals(course.toLowerCase())))
          .get();

  Future<List<Recipe>> getRecipesByCuisine(String cuisine) =>
      (select(recipes)
            ..where((r) => r.cuisine.lower().equals(cuisine.toLowerCase())))
          .get();

  Future<List<Recipe>> getRecipesBySource(String source) =>
      (select(recipes)..where((r) => r.source.equals(source))).get();

  Future<List<Recipe>> getPersonalRecipes() =>
      (select(recipes)..where((r) => r.source.equals('personal'))).get();

  Future<List<Recipe>> getMemoixRecipes() =>
      (select(recipes)..where((r) => r.source.equals('memoix'))).get();

  Future<List<Recipe>> getImportedRecipes() =>
      (select(recipes)..where((r) => r.source.equals('imported'))).get();

  Future<List<Recipe>> getFavouriteRecipes() =>
      (select(recipes)..where((r) => r.isFavorite.equals(true))).get();

  Future<Recipe?> getRecipeById(int id) =>
      (select(recipes)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<Recipe?> getRecipeByUuid(String uuid) =>
      (select(recipes)..where((r) => r.uuid.equals(uuid))).getSingleOrNull();

  Future<List<Recipe>> getRecipesByUuids(List<String> uuids) {
    if (uuids.isEmpty) return Future.value([]);
    return (select(recipes)..where((r) => r.uuid.isIn(uuids))).get();
  }

  Future<List<Recipe>> getRecipesByType(String recipeType) =>
      (select(recipes)
            ..where((r) => r.recipeType.equals(recipeType)))
          .get();

  /// Searches recipes across name, tags, cuisine, and ingredient name.
  ///
  /// Uses a LEFT OUTER JOIN on [Ingredients] so recipes without ingredients
  /// are still returned when name/tags/cuisine match. The SQL-level [limit]
  /// is applied to the joined row-set; Dart-side id-based deduplication then
  /// collapses multi-ingredient matches into a single [Recipe] per row.
  Future<List<Recipe>> searchRecipes(String query, {int limit = 50}) async {
    final pattern = '%${query.toLowerCase()}%';

    final joinQuery = select(recipes).join([
      leftOuterJoin(
        ingredients,
        ingredients.recipeId.equalsExp(recipes.id),
      ),
    ]);

    joinQuery.where(
      recipes.name.lower().like(pattern) |
          recipes.tags.lower().like(pattern) |
          recipes.cuisine.lower().like(pattern) |
          ingredients.name.lower().like(pattern),
    );

    final rows = await joinQuery.get();

    final seen = <int>{};
    final result = <Recipe>[];
    for (final row in rows) {
      final recipe = row.readTable(recipes);
      if (seen.add(recipe.id)) {
        result.add(recipe);
      }
    }
    return result.take(limit).toList();
  }

  // ── Recipe write ───────────────────────────────────────────────────────────

  Future<int> saveRecipe(RecipesCompanion companion) async {
    assert(
      companion.id != const Value.absent() || companion.uuid.value.isNotEmpty,
      'saveRecipe called with no id and no uuid',
    );
    if (companion.id != const Value.absent() && companion.id.value > 0) {
      await (update(recipes)..where((r) => r.id.equals(companion.id.value)))
          .write(companion);
      return companion.id.value;
    }
    return into(recipes).insert(
      companion,
      onConflict: DoUpdate((old) => companion, target: [recipes.uuid]),
    );
  }

  Future<int?> getIdByUuid(String uuid) async {
    final row = await (select(recipes)..where((r) => r.uuid.equals(uuid))).getSingleOrNull();
    return row?.id;
  }

  Future<void> saveRecipes(List<RecipesCompanion> rows) =>
      transaction(() async {
        for (final row in rows) {
          await into(recipes).insert(
            row,
            onConflict: DoUpdate((old) => row, target: [recipes.uuid]),
          );
        }
      });

  /// Deletes all [Ingredient] rows for [id] before deleting the [Recipe] row.
  /// No cascade is defined in the schema, so order matters.
  Future<void> deleteRecipe(int id) async {
    await (delete(ingredients)..where((i) => i.recipeId.equals(id))).go();
    await (delete(recipes)..where((r) => r.id.equals(id))).go();
  }

  /// Writes the inverse of [current] directly without a preceding read.
  /// The caller owns the current state, so no read is needed at the DAO level.
  Future<void> toggleFavourite(int id, bool current) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(isFavorite: Value(!current)),
      );

  /// Stamps [updatedAt] to now for a single recipe row. No other fields are
  /// touched. Called after ingredient writes to ensure the parent recipe's
  /// timestamp reflects the time all changes settled.
  Future<void> touchRecipe(int id) =>
      (update(recipes)..where((r) => r.id.equals(id)))
          .write(RecipesCompanion(updatedAt: Value(DateTime.now())));

  /// Seeds Memoix-sourced recipes idempotently.
  ///
  /// Each [RecipesCompanion] is inserted only when its UUID is not already
  /// present in the [recipes] table. Existing rows are never modified so user
  /// edits (copy-on-write promotions to 'personal') and personalisation data
  /// (ratings, favourite flags, cook counts) are always preserved.
  Future<void> syncMemoixRecipes(List<RecipesCompanion> incoming) =>
      transaction(() async {
        for (final row in incoming) {
          final uuid = row.uuid.value;
          final exists = await (select(recipes)
                ..where((r) => r.uuid.equals(uuid)))
              .getSingleOrNull();
          if (exists != null) continue; // UUID already present — no-op.
          await into(recipes).insert(row);
        }
      });

  // ── Recipe watch ───────────────────────────────────────────────────────────

  /// Watches the [recipes] table only — no JOIN amplification.
  /// The stream re-emits on any write to the recipes table, including the
  /// [touchRecipe] stamp that [RecipeRepository.saveRecipe] issues after
  /// writing ingredient rows, so ingredient changes are always propagated.
  Stream<List<Recipe>> watchAllRecipes() => select(recipes).watch();

  Stream<List<Recipe>> watchFavouriteRecipes() =>
      (select(recipes)..where((r) => r.isFavorite.equals(true))).watch();

  /// Returns a stream of recipes filtered by [course] (case-insensitive).
  ///
  /// The Isar implementation sorted results by continent → country →
  /// subcategory → name inside a `.map()` on the stream. That sort is
  /// presentation/business logic and is intentionally omitted here; apply it
  /// in the repository or provider layer.
  Stream<List<Recipe>> watchRecipesByCourse(String course) =>
      (select(recipes)
            ..where((r) => r.course.lower().equals(course.toLowerCase())))
          .watch();

  /// Returns a stream of recipes whose [recipeType] column matches [type].
  /// Used by domain-specific repositories (e.g. Modernist) to avoid scanning
  /// the full table when only one type is needed.
  Stream<List<Recipe>> watchRecipesByType(String type) =>
      (select(recipes)..where((r) => r.recipeType.equals(type))).watch();

  // ── Ingredient methods ─────────────────────────────────────────────────────

  Future<List<Ingredient>> getIngredientsForRecipe(int recipeId) =>
      (select(ingredients)
            ..where((i) => i.recipeId.equals(recipeId)))
          .get();

  /// Fetches all ingredient rows whose [recipeId] is in [recipeIds].
  /// A single `WHERE recipe_id IN (...)` replaces N separate queries.
  Future<List<Ingredient>> getIngredientsForRecipes(
    Iterable<int> recipeIds,
  ) {
    final ids = recipeIds.toList();
    if (ids.isEmpty) return Future.value([]);
    return (select(ingredients)..where((i) => i.recipeId.isIn(ids))).get();
  }

  Future<int> saveIngredient(IngredientsCompanion ingredient) =>
      into(ingredients).insert(ingredient);

  Future<void> saveIngredients(List<IngredientsCompanion> rows) =>
      transaction(() async {
        for (final row in rows) {
          await into(ingredients).insert(row);
        }
      });

  Future<int> deleteIngredientsForRecipe(int recipeId) =>
      (delete(ingredients)..where((i) => i.recipeId.equals(recipeId))).go();

  Future<int> deleteIngredient(int id) =>
      (delete(ingredients)..where((i) => i.id.equals(id))).go();

  // ── Course methods ─────────────────────────────────────────────────────────

  Future<List<Course>> getAllCourses() =>
      (select(courses)
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<List<Course>> getVisibleCourses() =>
      (select(courses)
            ..where((c) => c.isVisible.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<int> saveCourse(CoursesCompanion course) =>
      into(courses).insertOnConflictUpdate(course);

  Future<int> deleteCourse(int id) =>
      (delete(courses)..where((c) => c.id.equals(id))).go();

  Stream<List<Course>> watchCourses() =>
      (select(courses)
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();
}
