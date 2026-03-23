import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'cellar_dao.g.dart';

@DriftAccessor(tables: [CellarEntries, CheeseEntries])
class CellarDao extends DatabaseAccessor<AppDatabase>
    with _$CellarDaoMixin {
  CellarDao(super.db);

  // ─── CELLAR ENTRIES ───────────────────────────────────────────────────────

  Future<List<CellarEntry>> getAllEntries() =>
      select(cellarEntries).get();

  Future<List<CellarEntry>> getEntriesByCategory(String category) =>
      (select(cellarEntries)
            ..where((t) => t.category.lower().like(category.toLowerCase())))
          .get();

  Future<List<CellarEntry>> getBuyAgainEntries() =>
      (select(cellarEntries)..where((t) => t.buy.equals(true))).get();

  Future<List<CellarEntry>> getFavorites() =>
      (select(cellarEntries)..where((t) => t.isFavorite.equals(true))).get();

  Future<List<CellarEntry>> searchEntries(String query) {
    final q = query.toLowerCase();
    return (select(cellarEntries)
          ..where((t) =>
              t.name.lower().like('%$q%') |
              t.producer.lower().like('%$q%') |
              t.category.lower().like('%$q%')))
        .get();
  }

  Future<CellarEntry?> getEntryById(int id) =>
      (select(cellarEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<CellarEntry?> getEntryByUuid(String uuid) =>
      (select(cellarEntries)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveEntry(CellarEntriesCompanion entry) =>
      into(cellarEntries).insertOnConflictUpdate(entry);

  Future<int> deleteEntry(int id) =>
      (delete(cellarEntries)..where((t) => t.id.equals(id))).go();

  Future<int> deleteEntryByUuid(String uuid) async {
    final entry = await getEntryByUuid(uuid);
    if (entry == null) return 0;
    return deleteEntry(entry.id);
  }

  Future<void> toggleFavorite(int id, bool current) async {
    final entry = await getEntryById(id);
    if (entry == null) return;
    await (update(cellarEntries)..where((t) => t.id.equals(id)))
        .write(CellarEntriesCompanion(isFavorite: Value(!entry.isFavorite)));
  }

  Future<void> toggleBuy(int id, bool current) async {
    final entry = await getEntryById(id);
    if (entry == null) return;
    await (update(cellarEntries)..where((t) => t.id.equals(id)))
        .write(CellarEntriesCompanion(buy: Value(!entry.buy)));
  }

  Stream<List<CellarEntry>> watchAllEntries() =>
      select(cellarEntries).watch();

  Stream<List<CellarEntry>> watchFavorites() =>
      (select(cellarEntries)..where((t) => t.isFavorite.equals(true))).watch();

  Future<int> getEntryCount() async {
    final count = countAll();
    final query = selectOnly(cellarEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ─── CHEESE ENTRIES ───────────────────────────────────────────────────────

  Future<List<CheeseEntry>> getAllCheeseEntries() =>
      select(cheeseEntries).get();

  Future<List<CheeseEntry>> getCheeseEntriesByCountry(String country) =>
      (select(cheeseEntries)
            ..where((t) => t.country.lower().like(country.toLowerCase())))
          .get();

  Future<List<CheeseEntry>> getCheeseEntriesByMilk(String milk) =>
      (select(cheeseEntries)
            ..where((t) => t.milk.lower().like(milk.toLowerCase())))
          .get();

  Future<List<CheeseEntry>> getCheeseBuyAgainEntries() =>
      (select(cheeseEntries)..where((t) => t.buy.equals(true))).get();

  Future<List<CheeseEntry>> getCheeseFavorites() =>
      (select(cheeseEntries)..where((t) => t.isFavorite.equals(true))).get();

  Future<List<CheeseEntry>> searchCheeseEntries(String query) {
    final q = query.toLowerCase();
    return (select(cheeseEntries)
          ..where((t) =>
              t.name.lower().like('%$q%') |
              t.type.lower().like('%$q%') |
              t.country.lower().like('%$q%') |
              t.milk.lower().like('%$q%')))
        .get();
  }

  Future<CheeseEntry?> getCheeseEntryById(int id) =>
      (select(cheeseEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<CheeseEntry?> getCheeseEntryByUuid(String uuid) =>
      (select(cheeseEntries)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveCheeseEntry(CheeseEntriesCompanion entry) =>
      into(cheeseEntries).insertOnConflictUpdate(entry);

  Future<int> deleteCheeseEntry(int id) =>
      (delete(cheeseEntries)..where((t) => t.id.equals(id))).go();

  Future<int> deleteCheeseEntryByUuid(String uuid) async {
    final entry = await getCheeseEntryByUuid(uuid);
    if (entry == null) return 0;
    return deleteCheeseEntry(entry.id);
  }

  Future<void> toggleCheeseFavorite(int id, bool current) async {
    final entry = await getCheeseEntryById(id);
    if (entry == null) return;
    await (update(cheeseEntries)..where((t) => t.id.equals(id)))
        .write(CheeseEntriesCompanion(isFavorite: Value(!entry.isFavorite)));
  }

  Future<void> toggleCheeseBuy(int id, bool current) async {
    final entry = await getCheeseEntryById(id);
    if (entry == null) return;
    await (update(cheeseEntries)..where((t) => t.id.equals(id)))
        .write(CheeseEntriesCompanion(buy: Value(!entry.buy)));
  }

  Stream<List<CheeseEntry>> watchAllCheeseEntries() =>
      select(cheeseEntries).watch();

  Stream<List<CheeseEntry>> watchCheeseFavorites() =>
      (select(cheeseEntries)..where((t) => t.isFavorite.equals(true))).watch();

  Future<int> getCheeseEntryCount() async {
    final count = countAll();
    final query = selectOnly(cheeseEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
