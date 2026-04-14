import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'smoking_dao.g.dart';

@DriftAccessor(tables: [SmokingRecipes])
class SmokingDao extends DatabaseAccessor<AppDatabase>
    with _$SmokingDaoMixin {
  SmokingDao(super.db);

  Future<List<SmokingRecipe>> getAllRecipes() =>
      (select(smokingRecipes)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<List<SmokingRecipe>> getRecipesByType(String type) =>
      (select(smokingRecipes)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<List<SmokingRecipe>> getRecipesByWood(String wood) =>
      (select(smokingRecipes)
            ..where((t) => t.wood.lower().like(wood.toLowerCase()))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<SmokingRecipe?> getRecipeByUuid(String uuid) =>
      (select(smokingRecipes)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<SmokingRecipe?> getRecipeById(int id) =>
      (select(smokingRecipes)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> saveRecipe(SmokingRecipesCompanion recipe) async {
    if (recipe.id != const Value.absent() && recipe.id.value > 0) {
      await (update(smokingRecipes)..where((t) => t.id.equals(recipe.id.value)))
          .write(recipe);
      return recipe.id.value;
    }
    final forInsert = recipe.id == const Value(0)
        ? recipe.copyWith(id: const Value.absent())
        : recipe;
    return into(smokingRecipes).insert(
      forInsert,
      onConflict: DoUpdate(
        (old) => forInsert.copyWith(id: const Value.absent()),
        target: [smokingRecipes.uuid],
      ),
    );
  }

  Future<int> deleteRecipe(int id) =>
      (delete(smokingRecipes)..where((t) => t.id.equals(id))).go();

  Future<int> deleteRecipeByUuid(String uuid) async {
    final recipe = await getRecipeByUuid(uuid);
    if (recipe == null) return 0;
    return deleteRecipe(recipe.id);
  }

  Future<void> toggleFavorite(int id, bool current) async {
    final recipe = await getRecipeById(id);
    if (recipe == null) return;
    await (update(smokingRecipes)..where((t) => t.id.equals(id)))
        .write(SmokingRecipesCompanion(isFavorite: Value(!recipe.isFavorite)));
  }

  Future<void> incrementCookCount(int id) async {
    final recipe = await getRecipeById(id);
    if (recipe == null) return;
    await (update(smokingRecipes)..where((t) => t.id.equals(id)))
        .write(SmokingRecipesCompanion(cookCount: Value(recipe.cookCount + 1)));
  }

  Stream<List<SmokingRecipe>> watchAll() =>
      (select(smokingRecipes)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<SmokingRecipe>> watchByType(String type) =>
      (select(smokingRecipes)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<SmokingRecipe>> watchFavorites() =>
      (select(smokingRecipes)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<int> getCount() async {
    final count = countAll();
    final query = selectOnly(smokingRecipes)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> getCountByType(String type) async {
    final count = countAll();
    final query = selectOnly(smokingRecipes)
      ..addColumns([count])
      ..where(smokingRecipes.type.equals(type));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
