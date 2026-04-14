import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'catalogue_dao.g.dart';

@DriftAccessor(tables: [Pizzas, Sandwiches])
class CatalogueDao extends DatabaseAccessor<AppDatabase>
    with _$CatalogueDaoMixin {
  CatalogueDao(super.db);

  // ─── PIZZAS ───────────────────────────────────────────────────────────────

  Future<List<Pizza>> getAllPizzas() => select(pizzas).get();

  Future<List<Pizza>> getPizzasByBase(String base) =>
      (select(pizzas)..where((t) => t.base.equals(base))).get();

  Future<List<Pizza>> getPizzasBySource(String source) =>
      (select(pizzas)..where((t) => t.source.equals(source))).get();

  Future<List<Pizza>> getPersonalPizzas() => getPizzasBySource('personal');

  Future<List<Pizza>> getMemoixPizzas() => getPizzasBySource('memoix');

  Future<List<Pizza>> getFavoritePizzas() =>
      (select(pizzas)..where((t) => t.isFavorite.equals(true))).get();

  Future<List<Pizza>> searchPizzas(String query) {
    if (query.isEmpty) return getAllPizzas();
    final q = '%${query.toLowerCase()}%';
    return (select(pizzas)
          ..where((t) =>
              t.name.lower().like(q) |
              t.cheeses.lower().like(q) |
              t.proteins.lower().like(q) |
              t.vegetables.lower().like(q) |
              t.tags.lower().like(q),))
        .get();
  }

  Future<Pizza?> getPizzaById(int id) =>
      (select(pizzas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Pizza?> getPizzaByUuid(String uuid) =>
      (select(pizzas)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  Future<int> savePizza(PizzasCompanion pizza) =>
      into(pizzas).insertOnConflictUpdate(pizza);

  Future<int> deletePizza(int id) =>
      (delete(pizzas)..where((t) => t.id.equals(id))).go();

  Future<int> deletePizzaByUuid(String uuid) async {
    final pizza = await getPizzaByUuid(uuid);
    if (pizza == null) return 0;
    return deletePizza(pizza.id);
  }

  Future<void> togglePizzaFavorite(int id, bool current) async {
    final pizza = await getPizzaById(id);
    if (pizza == null) return;
    await (update(pizzas)..where((t) => t.id.equals(id)))
        .write(PizzasCompanion(isFavorite: Value(!pizza.isFavorite)));
  }

  Future<void> incrementPizzaCookCount(int id) async {
    final pizza = await getPizzaById(id);
    if (pizza == null) return;
    await (update(pizzas)..where((t) => t.id.equals(id)))
        .write(PizzasCompanion(cookCount: Value(pizza.cookCount + 1)));
  }

  Future<int> updatePizzaRating(int id, int rating) =>
      (update(pizzas)..where((t) => t.id.equals(id)))
          .write(PizzasCompanion(rating: Value(rating)));

  Stream<List<Pizza>> watchAllPizzas() => select(pizzas).watch();

  Stream<List<Pizza>> watchPizzasByBase(String base) =>
      (select(pizzas)..where((t) => t.base.equals(base))).watch();

  Stream<List<Pizza>> watchFavoritePizzas() =>
      (select(pizzas)..where((t) => t.isFavorite.equals(true))).watch();

  Future<int> getPizzaCount() async {
    final count = countAll();
    final query = selectOnly(pizzas)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> getPizzaCountByBase(String base) async {
    final count = countAll();
    final query = selectOnly(pizzas)
      ..addColumns([count])
      ..where(pizzas.base.equals(base));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> importPizzas(List<PizzasCompanion> pizzas) async {
    for (final pizza in pizzas) {
      await into(this.pizzas).insertOnConflictUpdate(pizza);
    }
  }

  // ─── SANDWICHES ───────────────────────────────────────────────────────────

  Future<List<Sandwich>> getAllSandwiches() => select(sandwiches).get();

  Future<List<Sandwich>> getSandwichesBySource(String source) =>
      (select(sandwiches)..where((t) => t.source.equals(source))).get();

  Future<List<Sandwich>> getPersonalSandwiches() =>
      getSandwichesBySource('personal');

  Future<List<Sandwich>> getMemoixSandwiches() =>
      getSandwichesBySource('memoix');

  Future<List<Sandwich>> getFavoriteSandwiches() =>
      (select(sandwiches)..where((t) => t.isFavorite.equals(true))).get();

  Future<List<Sandwich>> searchSandwiches(String query) {
    if (query.isEmpty) return getAllSandwiches();
    final q = '%${query.toLowerCase()}%';
    return (select(sandwiches)
          ..where((t) =>
              t.name.lower().like(q) |
              t.bread.lower().like(q) |
              t.proteins.lower().like(q) |
              t.vegetables.lower().like(q) |
              t.cheeses.lower().like(q) |
              t.condiments.lower().like(q) |
              t.tags.lower().like(q),))
        .get();
  }

  Future<Sandwich?> getSandwichById(int id) =>
      (select(sandwiches)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Sandwich?> getSandwichByUuid(String uuid) =>
      (select(sandwiches)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveSandwich(SandwichesCompanion sandwich) =>
      into(sandwiches).insertOnConflictUpdate(sandwich);

  Future<int> deleteSandwich(int id) =>
      (delete(sandwiches)..where((t) => t.id.equals(id))).go();

  Future<int> deleteSandwichByUuid(String uuid) async {
    final sandwich = await getSandwichByUuid(uuid);
    if (sandwich == null) return 0;
    return deleteSandwich(sandwich.id);
  }

  Future<void> toggleSandwichFavorite(int id, bool current) async {
    final sandwich = await getSandwichById(id);
    if (sandwich == null) return;
    await (update(sandwiches)..where((t) => t.id.equals(id)))
        .write(SandwichesCompanion(isFavorite: Value(!sandwich.isFavorite)));
  }

  Future<void> incrementSandwichCookCount(int id) async {
    final sandwich = await getSandwichById(id);
    if (sandwich == null) return;
    await (update(sandwiches)..where((t) => t.id.equals(id)))
        .write(SandwichesCompanion(cookCount: Value(sandwich.cookCount + 1)));
  }

  Future<int> updateSandwichRating(int id, int rating) =>
      (update(sandwiches)..where((t) => t.id.equals(id)))
          .write(SandwichesCompanion(rating: Value(rating)));

  Stream<List<Sandwich>> watchAllSandwiches() => select(sandwiches).watch();

  Stream<List<Sandwich>> watchFavoriteSandwiches() =>
      (select(sandwiches)..where((t) => t.isFavorite.equals(true))).watch();

  Future<int> getSandwichCount() async {
    final count = countAll();
    final query = selectOnly(sandwiches)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> importSandwiches(List<SandwichesCompanion> sandwiches) async {
    for (final sandwich in sandwiches) {
      await into(this.sandwiches).insertOnConflictUpdate(sandwich);
    }
  }
}
