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

  Future<List<Recipe>> getFavoriteRecipes() =>
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
  Future<void> toggleFavorite(int id, bool current) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(isFavorite: Value(!current)),
      );

  /// Replaces all memoix-sourced recipes atomically.
  Future<void> syncMemoixRecipes(List<RecipesCompanion> incoming) =>
      transaction(() async {
        final incomingUuids = <String>[];

        for (var row in incoming) {
          final uuid = row.uuid.value;
          incomingUuids.add(uuid);

          final existing = await (select(recipes)
                ..where((r) => r.uuid.equals(uuid)))
              .getSingleOrNull();

          if (existing != null) {
            row = row.copyWith(
              isFavorite: Value(existing.isFavorite),
              rating: Value(existing.rating),
              cookCount: Value(existing.cookCount),
              headerImage: Value(existing.headerImage),
            );
          }

          await into(recipes).insert(
            row,
            onConflict: DoUpdate((old) => row, target: [recipes.uuid]),
          );
        }

        if (incomingUuids.isNotEmpty) {
          await (delete(recipes)
                ..where(
                  (r) =>
                      r.source.equals('memoix') &
                      r.uuid.isNotIn(incomingUuids),
                ))
              .go();
        }
      });

  // ── Recipe watch ───────────────────────────────────────────────────────────

  /// Watches both [recipes] and [ingredients] tables so that the stream
  /// re-emits whenever either table is written to (e.g. after saveRecipe()
  /// deletes and reinserts ingredient rows). The left-outer join includes
  /// recipes that have no ingredients. Results are de-duplicated by recipe.id
  /// because the join produces one row per ingredient.
  Stream<List<Recipe>> watchAllRecipes() {
    return select(recipes).join([
      leftOuterJoin(ingredients, ingredients.recipeId.equalsExp(recipes.id)),
    ]).watch().map((rows) {
      final seen = <int>{};
      final result = <Recipe>[];
      for (final row in rows) {
        final recipe = row.readTable(recipes);
        if (seen.add(recipe.id)) {
          result.add(recipe);
        }
      }
      return result;
    });
  }

  Stream<List<Recipe>> watchFavoriteRecipes() =>
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

  // ── Ingredient methods ─────────────────────────────────────────────────────

  Future<List<Ingredient>> getIngredientsForRecipe(int recipeId) =>
      (select(ingredients)
            ..where((i) => i.recipeId.equals(recipeId)))
          .get();

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
