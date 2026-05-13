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
      (select(recipes)..where((r) => r.isFavourite.equals(true))).get();

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

  /// Converts a raw user search string into a safe FTS5 prefix MATCH expression.
  ///
  /// Each whitespace-separated token has FTS5 special characters stripped, then
  /// a trailing `*` appended for prefix matching. Returns an empty string when
  /// no valid tokens remain (caller must short-circuit and return an empty list).
  static String _buildFtsQuery(String query) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["\(\)\*\+\-:\^\{\}]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }

  /// Searches recipes using FTS5 full-text search across name, tags, cuisine,
  /// ingredient names, and ingredient notes.
  ///
  /// Each token in [query] is suffix-matched (prefix search) so "chick" matches
  /// "chicken". Results are ordered by BM25 relevance. Returns an empty list
  /// when [query] is blank or produces no valid FTS tokens.
  Future<List<Recipe>> searchRecipes(String query, {int limit = 50}) async {
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) return [];

    final idRows = await customSelect(
      'SELECT recipes.id FROM recipes '
      'JOIN recipes_fts ON recipes.id = recipes_fts.rowid '
      'WHERE recipes_fts MATCH ? '
      'ORDER BY bm25(recipes_fts) '
      'LIMIT ?',
      variables: [Variable.withString(matchQuery), Variable.withInt(limit)],
      readsFrom: {recipes},
    ).get();

    final ids = idRows.map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return [];

    // Preserve BM25 order after the typed fetch.
    final idOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    final rows = await (select(recipes)..where((r) => r.id.isIn(ids))).get();
    rows.sort((a, b) => (idOrder[a.id] ?? 0).compareTo(idOrder[b.id] ?? 0));
    return rows;
  }

  // ── FTS5 maintenance ───────────────────────────────────────────────────────

  /// Upserts the [recipes_fts] row for [recipeId].
  ///
  /// Fetches the recipe row and all current ingredient rows from the DB so that
  /// this can be called immediately after ingredients are written, without the
  /// caller having to pass data through.
  Future<void> upsertRecipeFts(int recipeId) async {
    final recipe =
        await (select(recipes)..where((r) => r.id.equals(recipeId)))
            .getSingleOrNull();
    if (recipe == null) return;

    final ings = await (select(ingredients)
          ..where((i) => i.recipeId.equals(recipeId)))
        .get();

    final ingNames = ings.map((i) => i.name).join(' ');
    final ingNotes = ings
        .map((i) => i.notes ?? '')
        .where((n) => n.isNotEmpty)
        .join(' ');

    await customStatement(
      'INSERT OR REPLACE INTO recipes_fts'
      '(rowid, name, tags, cuisine, ingredient_names, ingredient_notes) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        recipeId,
        recipe.name,
        recipe.tags,
        recipe.cuisine ?? '',
        ingNames,
        ingNotes,
      ],
    );
  }

  /// Removes the [recipes_fts] row for [id].
  Future<void> deleteRecipeFts(int id) async {
    await customStatement(
      'DELETE FROM recipes_fts WHERE rowid = ?',
      [id],
    );
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
    await deleteRecipeFts(id);
  }

  /// Writes the inverse of [current] directly without a preceding read.
  /// The caller owns the current state, so no read is needed at the DAO level.
  Future<void> toggleFavourite(int id, bool current) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(isFavourite: Value(!current)),
      );

  /// Writes the inverse of [current] for the Culinary Intelligence sharing flag.
  Future<void> toggleShared(int id, bool current) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(isShared: Value(!current)),
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
      (select(recipes)..where((r) => r.isFavourite.equals(true))).watch();

  /// Returns a stream of recipes filtered by [course] (case-insensitive).
  ///
  /// Sorting by continent → country → subcategory → name is
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

  /// Replaces the ingredient sets for multiple recipes in one transaction,
  /// eliminating N round-trips compared to calling deleteIngredientsForRecipe
  /// + saveIngredients per recipe in a loop (M-8).
  Future<void> replaceIngredientsForRecipesBatch(
      Map<int, List<IngredientsCompanion>> map) =>
      transaction(() async {
        for (final entry in map.entries) {
          await (delete(ingredients)
                ..where((i) => i.recipeId.equals(entry.key)))
              .go();
          for (final ing in entry.value) {
            await into(ingredients).insert(ing);
          }
        }
      });

  /// Returns all recipe rows where the [pairedRecipeIds] JSON array contains
  /// [uuid]. Uses a SQL LIKE filter so only matching rows are scanned,
  /// instead of loading the full table into Dart for in-memory filtering.
  ///
  /// A secondary Dart-side check in the repository guards against the rare
  /// false-positive where a UUID appears as a substring of a longer value.
  Future<List<Recipe>> getRecipesByPairedId(String uuid) =>
      (select(recipes)
            ..where((r) => r.pairedRecipeIds.like('%"$uuid"%')))
          .get();

  /// Returns up to [limit] distinct ingredient names that contain [query]
  /// (case-insensitive). Queries the DB directly to avoid loading full
  /// Recipe models.
  Future<List<String>> searchIngredientNames(
    String query, {
    int limit = 15,
  }) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await (select(ingredients)
          ..where((i) => i.name.lower().like(pattern))
          ..limit(limit))
        .get();
    return rows
        .map((r) => r.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Returns up to [limit] distinct ingredient prep notes that contain [query]
  /// (case-insensitive). Queries the DB directly to avoid loading full
  /// Recipe models.
  Future<List<String>> searchIngredientNotes(
    String query, {
    int limit = 15,
  }) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await (select(ingredients)
          ..where((i) => i.notes.lower().like(pattern))
          ..limit(limit))
        .get();
    return rows
        .map((r) => r.notes)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
  }

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
