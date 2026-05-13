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

  Future<List<Pizza>> getFavouritePizzas() =>
      (select(pizzas)..where((t) => t.isFavourite.equals(true))).get();

  /// Converts a raw user query into a safe FTS5 prefix MATCH expression.
  /// Shared by all search methods in this DAO.
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

  Future<List<Pizza>> searchPizzas(String query) async {
    if (query.isEmpty) return getAllPizzas();
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) return [];

    final idRows = await customSelect(
      'SELECT pizzas.id FROM pizzas '
      'JOIN pizzas_fts ON pizzas.id = pizzas_fts.rowid '
      'WHERE pizzas_fts MATCH ? '
      'ORDER BY bm25(pizzas_fts)',
      variables: [Variable.withString(matchQuery)],
      readsFrom: {pizzas},
    ).get();

    final ids = idRows.map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return [];
    final idOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    final rows = await (select(pizzas)..where((t) => t.id.isIn(ids))).get();
    rows.sort((a, b) => (idOrder[a.id] ?? 0).compareTo(idOrder[b.id] ?? 0));
    return rows;
  }

  Future<Pizza?> getPizzaById(int id) =>
      (select(pizzas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Pizza?> getPizzaByUuid(String uuid) =>
      (select(pizzas)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  Future<int> savePizza(PizzasCompanion pizza) async {
    if (pizza.id != const Value.absent() && pizza.id.value > 0) {
      await (update(pizzas)..where((t) => t.id.equals(pizza.id.value)))
          .write(pizza);
      return pizza.id.value;
    }
    final forInsert = pizza.id == const Value(0)
        ? pizza.copyWith(id: const Value.absent())
        : pizza;
    return into(pizzas).insert(
      forInsert,
      onConflict: DoUpdate(
        (old) => forInsert.copyWith(id: const Value.absent()),
        target: [pizzas.uuid],
      ),
    );
  }

  Future<int> deletePizza(int id) async {
    final count = await (delete(pizzas)..where((t) => t.id.equals(id))).go();
    await deletePizzaFts(id);
    return count;
  }

  Future<int> deletePizzaByUuid(String uuid) async {
    final pizza = await getPizzaByUuid(uuid);
    if (pizza == null) return 0;
    return deletePizza(pizza.id);
  }

  Future<void> togglePizzaFavourite(int id, bool current) async {
    // Atomic NOT flip — avoids a read-then-write race condition.
    await customUpdate(
      'UPDATE pizzas SET is_favourite = NOT is_favourite WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {pizzas},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> incrementPizzaCookCount(int id) async {
    // Single atomic increment — no read required.
    await customUpdate(
      'UPDATE pizzas SET cook_count = cook_count + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {pizzas},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updatePizzaRating(int id, int rating) =>
      (update(pizzas)..where((t) => t.id.equals(id)))
          .write(PizzasCompanion(rating: Value(rating)));

  Stream<List<Pizza>> watchAllPizzas() => select(pizzas).watch();

  Stream<List<Pizza>> watchPizzasByBase(String base) =>
      (select(pizzas)..where((t) => t.base.equals(base))).watch();

  Stream<List<Pizza>> watchFavouritePizzas() =>
      (select(pizzas)..where((t) => t.isFavourite.equals(true))).watch();

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

  Future<void> importPizzas(List<PizzasCompanion> pizzaList) async {
    for (final pizza in pizzaList) {
      final id = await into(this.pizzas).insertOnConflictUpdate(pizza);
      await upsertPizzaFts(
        id,
        name: pizza.name.value,
        tags: pizza.tags.value,
        cheeses: pizza.cheeses.value,
        proteins: pizza.proteins.value,
        vegetables: pizza.vegetables.value,
        notes: pizza.notes.present ? pizza.notes.value : null,
      );
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

  Future<List<Sandwich>> getFavouriteSandwiches() =>
      (select(sandwiches)..where((t) => t.isFavourite.equals(true))).get();

  Future<List<Sandwich>> searchSandwiches(String query) async {
    if (query.isEmpty) return getAllSandwiches();
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) return [];

    final idRows = await customSelect(
      'SELECT sandwiches.id FROM sandwiches '
      'JOIN sandwiches_fts ON sandwiches.id = sandwiches_fts.rowid '
      'WHERE sandwiches_fts MATCH ? '
      'ORDER BY bm25(sandwiches_fts)',
      variables: [Variable.withString(matchQuery)],
      readsFrom: {sandwiches},
    ).get();

    final ids = idRows.map((r) => r.read<int>('id')).toList();
    if (ids.isEmpty) return [];
    final idOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    final rows =
        await (select(sandwiches)..where((t) => t.id.isIn(ids))).get();
    rows.sort((a, b) => (idOrder[a.id] ?? 0).compareTo(idOrder[b.id] ?? 0));
    return rows;
  }

  Future<Sandwich?> getSandwichById(int id) =>
      (select(sandwiches)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Sandwich?> getSandwichByUuid(String uuid) =>
      (select(sandwiches)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveSandwich(SandwichesCompanion sandwich) async {
    if (sandwich.id != const Value.absent() && sandwich.id.value > 0) {
      await (update(sandwiches)..where((t) => t.id.equals(sandwich.id.value)))
          .write(sandwich);
      return sandwich.id.value;
    }
    final forInsert = sandwich.id == const Value(0)
        ? sandwich.copyWith(id: const Value.absent())
        : sandwich;
    return into(sandwiches).insert(
      forInsert,
      onConflict: DoUpdate(
        (old) => forInsert.copyWith(id: const Value.absent()),
        target: [sandwiches.uuid],
      ),
    );
  }

  Future<int> deleteSandwich(int id) async {
    final count =
        await (delete(sandwiches)..where((t) => t.id.equals(id))).go();
    await deleteSandwichFts(id);
    return count;
  }

  Future<int> deleteSandwichByUuid(String uuid) async {
    final sandwich = await getSandwichByUuid(uuid);
    if (sandwich == null) return 0;
    return deleteSandwich(sandwich.id);
  }

  Future<void> toggleSandwichFavourite(int id, bool current) async {
    final sandwich = await getSandwichById(id);
    if (sandwich == null) return;
    await (update(sandwiches)..where((t) => t.id.equals(id)))
        .write(SandwichesCompanion(isFavourite: Value(!sandwich.isFavourite)));
  }

  Future<void> incrementSandwichCookCount(int id) async {
    // Single atomic increment — no read required.
    await customUpdate(
      'UPDATE sandwiches SET cook_count = cook_count + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {sandwiches},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateSandwichRating(int id, int rating) =>
      (update(sandwiches)..where((t) => t.id.equals(id)))
          .write(SandwichesCompanion(rating: Value(rating)));

  Stream<List<Sandwich>> watchAllSandwiches() => select(sandwiches).watch();

  Stream<List<Sandwich>> watchFavouriteSandwiches() =>
      (select(sandwiches)..where((t) => t.isFavourite.equals(true))).watch();

  Future<int> getSandwichCount() async {
    final count = countAll();
    final query = selectOnly(sandwiches)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> importSandwiches(List<SandwichesCompanion> sandwichList) async {
    for (final sandwich in sandwichList) {
      final id = await into(this.sandwiches).insertOnConflictUpdate(sandwich);
      await upsertSandwichFts(
        id,
        name: sandwich.name.value,
        tags: sandwich.tags.value,
        bread: sandwich.bread.value,
        proteins: sandwich.proteins.value,
        vegetables: sandwich.vegetables.value,
        cheeses: sandwich.cheeses.value,
        condiments: sandwich.condiments.value,
        notes: sandwich.notes.present ? sandwich.notes.value : null,
      );
    }
  }

  // ── FTS5 maintenance ───────────────────────────────────────────────────────

  /// Upserts the [pizzas_fts] row for [id].
  Future<void> upsertPizzaFts(
    int id, {
    required String name,
    required String tags,
    required String cheeses,
    required String proteins,
    required String vegetables,
    required String? notes,
  }) async {
    await customStatement(
      'INSERT OR REPLACE INTO pizzas_fts'
      '(rowid, name, tags, cheeses, proteins, vegetables, notes) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, name, tags, cheeses, proteins, vegetables, notes ?? ''],
    );
  }

  /// Removes the [pizzas_fts] row for [id].
  Future<void> deletePizzaFts(int id) async {
    await customStatement('DELETE FROM pizzas_fts WHERE rowid = ?', [id]);
  }

  /// Upserts the [sandwiches_fts] row for [id].
  Future<void> upsertSandwichFts(
    int id, {
    required String name,
    required String tags,
    required String bread,
    required String proteins,
    required String vegetables,
    required String cheeses,
    required String condiments,
    required String? notes,
  }) async {
    await customStatement(
      'INSERT OR REPLACE INTO sandwiches_fts'
      '(rowid, name, tags, bread, proteins, vegetables, cheeses, condiments, notes) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, name, tags, bread, proteins, vegetables, cheeses, condiments, notes ?? ''],
    );
  }

  /// Removes the [sandwiches_fts] row for [id].
  Future<void> deleteSandwichFts(int id) async {
    await customStatement('DELETE FROM sandwiches_fts WHERE rowid = ?', [id]);
  }
}
