import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'cellar_dao.g.dart';

/// Lightweight projection returned by [CellarDao.searchEntries].
/// Contains only the columns rendered by [CellarCard] list tiles.
class CellarSearchResult {
  final int id;
  final String uuid;
  final String name;
  final String? category;
  final String? producer;
  final bool buy;
  final bool isFavourite;

  const CellarSearchResult({
    required this.id,
    required this.uuid,
    required this.name,
    this.category,
    this.producer,
    required this.buy,
    required this.isFavourite,
  });
}

/// Lightweight projection returned by [CellarDao.searchCheeseEntries].
/// Contains only the columns rendered by [CheeseCard] list tiles.
class CheeseSearchResult {
  final int id;
  final String uuid;
  final String name;
  final String? country;
  final String? milk;
  final bool buy;
  final bool isFavourite;

  const CheeseSearchResult({
    required this.id,
    required this.uuid,
    required this.name,
    this.country,
    this.milk,
    required this.buy,
    required this.isFavourite,
  });
}

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

  Future<List<CellarEntry>> getFavourites() =>
      (select(cellarEntries)..where((t) => t.isFavourite.equals(true))).get();

  /// Converts a raw user query into a safe FTS5 prefix MATCH expression.
  /// Shared by all search methods in this DAO.
  static String _buildFtsQuery(String query) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["\(\)\*\+\-:\^\{\}\.\[\]]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }

  Future<List<CellarSearchResult>> searchEntries(
    String query, {
    int limit = 50,
  }) async {
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) return [];

    // F-05: direct rowid form avoids the base-table JOIN.
    final idRows = await customSelect(
      'SELECT rowid FROM cellar_fts '
      'WHERE cellar_fts MATCH ? '
      'ORDER BY bm25(cellar_fts, 10, 4, 2, 3) '
      'LIMIT ?',
      variables: [Variable.withString(matchQuery), Variable.withInt(limit)],
      readsFrom: {cellarEntries},
    ).get();

    final ids = idRows.map((r) => r.read<int>('rowid')).toList();
    if (ids.isEmpty) return [];
    final idOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};

    // F-03: selectOnly projects only the columns CellarCard tiles render.
    final rows = await (selectOnly(cellarEntries)
          ..addColumns([
            cellarEntries.id,
            cellarEntries.uuid,
            cellarEntries.name,
            cellarEntries.category,
            cellarEntries.producer,
            cellarEntries.buy,
            cellarEntries.isFavourite,
          ])
          ..where(cellarEntries.id.isIn(ids)))
        .get();

    final results = rows
        .map(
          (r) => CellarSearchResult(
            id: r.read(cellarEntries.id)!,
            uuid: r.read(cellarEntries.uuid)!,
            name: r.read(cellarEntries.name)!,
            category: r.read(cellarEntries.category),
            producer: r.read(cellarEntries.producer),
            buy: r.read(cellarEntries.buy)!,
            isFavourite: r.read(cellarEntries.isFavourite)!,
          ),
        )
        .toList();

    results.sort(
        (a, b) => (idOrder[a.id] ?? 0).compareTo(idOrder[b.id] ?? 0));
    return results;
  }

  Future<CellarEntry?> getEntryById(int id) =>
      (select(cellarEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<CellarEntry?> getEntryByUuid(String uuid) =>
      (select(cellarEntries)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveEntry(CellarEntriesCompanion entry) async {
    if (entry.id != const Value.absent() && entry.id.value > 0) {
      await (update(cellarEntries)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);
      return entry.id.value;
    }
    final forInsert = entry.id == const Value(0)
        ? entry.copyWith(id: const Value.absent())
        : entry;
    return into(cellarEntries).insert(
      forInsert,
      onConflict: DoUpdate(
        (old) => forInsert.copyWith(id: const Value.absent()),
        target: [cellarEntries.uuid],
      ),
    );
  }

  Future<int> deleteEntry(int id) async {
    await deleteCellarFts(id);
    final count =
        await (delete(cellarEntries)..where((t) => t.id.equals(id))).go();
    return count;
  }

  Future<int> deleteEntryByUuid(String uuid) async {
    final entry = await getEntryByUuid(uuid);
    if (entry == null) return 0;
    return deleteEntry(entry.id);
  }

  Future<void> toggleFavourite(int id, bool current) async {
    final entry = await getEntryById(id);
    if (entry == null) return;
    await (update(cellarEntries)..where((t) => t.id.equals(id)))
        .write(CellarEntriesCompanion(isFavourite: Value(!entry.isFavourite)));
  }

  Future<void> toggleBuy(int id, bool current) async {
    final entry = await getEntryById(id);
    if (entry == null) return;
    await (update(cellarEntries)..where((t) => t.id.equals(id)))
        .write(CellarEntriesCompanion(buy: Value(!entry.buy)));
  }

  Stream<List<CellarEntry>> watchAllEntries() =>
      select(cellarEntries).watch();

  Stream<List<CellarEntry>> watchFavourites() =>
      (select(cellarEntries)..where((t) => t.isFavourite.equals(true))).watch();

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

  Future<List<CheeseEntry>> getCheeseFavourites() =>
      (select(cheeseEntries)..where((t) => t.isFavourite.equals(true))).get();

  Future<List<CheeseSearchResult>> searchCheeseEntries(
    String query, {
    int limit = 50,
  }) async {
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) return [];

    // F-05: direct rowid form avoids the base-table JOIN.
    final idRows = await customSelect(
      'SELECT rowid FROM cheese_fts '
      'WHERE cheese_fts MATCH ? '
      'ORDER BY bm25(cheese_fts, 10, 5, 2, 3, 4, 4) '
      'LIMIT ?',
      variables: [Variable.withString(matchQuery), Variable.withInt(limit)],
      readsFrom: {cheeseEntries},
    ).get();

    final ids = idRows.map((r) => r.read<int>('rowid')).toList();
    if (ids.isEmpty) return [];
    final idOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};

    // F-03: selectOnly projects only the columns CheeseCard tiles render.
    final rows = await (selectOnly(cheeseEntries)
          ..addColumns([
            cheeseEntries.id,
            cheeseEntries.uuid,
            cheeseEntries.name,
            cheeseEntries.country,
            cheeseEntries.milk,
            cheeseEntries.buy,
            cheeseEntries.isFavourite,
          ])
          ..where(cheeseEntries.id.isIn(ids)))
        .get();

    final results = rows
        .map(
          (r) => CheeseSearchResult(
            id: r.read(cheeseEntries.id)!,
            uuid: r.read(cheeseEntries.uuid)!,
            name: r.read(cheeseEntries.name)!,
            country: r.read(cheeseEntries.country),
            milk: r.read(cheeseEntries.milk),
            buy: r.read(cheeseEntries.buy)!,
            isFavourite: r.read(cheeseEntries.isFavourite)!,
          ),
        )
        .toList();

    results.sort(
        (a, b) => (idOrder[a.id] ?? 0).compareTo(idOrder[b.id] ?? 0));
    return results;
  }

  Future<CheeseEntry?> getCheeseEntryById(int id) =>
      (select(cheeseEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<CheeseEntry?> getCheeseEntryByUuid(String uuid) =>
      (select(cheeseEntries)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> saveCheeseEntry(CheeseEntriesCompanion entry) async {
    if (entry.id != const Value.absent() && entry.id.value > 0) {
      await (update(cheeseEntries)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);
      return entry.id.value;
    }
    final forInsert = entry.id == const Value(0)
        ? entry.copyWith(id: const Value.absent())
        : entry;
    return into(cheeseEntries).insert(
      forInsert,
      onConflict: DoUpdate(
        (old) => forInsert.copyWith(id: const Value.absent()),
        target: [cheeseEntries.uuid],
      ),
    );
  }

  Future<int> deleteCheeseEntry(int id) async {
    await deleteCheeseFts(id);
    final count =
        await (delete(cheeseEntries)..where((t) => t.id.equals(id))).go();
    return count;
  }

  Future<int> deleteCheeseEntryByUuid(String uuid) async {
    final entry = await getCheeseEntryByUuid(uuid);
    if (entry == null) return 0;
    return deleteCheeseEntry(entry.id);
  }

  Future<void> toggleCheeseFavourite(int id, bool current) async {
    final entry = await getCheeseEntryById(id);
    if (entry == null) return;
    await (update(cheeseEntries)..where((t) => t.id.equals(id)))
        .write(CheeseEntriesCompanion(isFavourite: Value(!entry.isFavourite)));
  }

  Future<void> toggleCheeseBuy(int id, bool current) async {
    final entry = await getCheeseEntryById(id);
    if (entry == null) return;
    await (update(cheeseEntries)..where((t) => t.id.equals(id)))
        .write(CheeseEntriesCompanion(buy: Value(!entry.buy)));
  }

  Stream<List<CheeseEntry>> watchAllCheeseEntries() =>
      select(cheeseEntries).watch();

  Stream<List<CheeseEntry>> watchCheeseFavourites() =>
      (select(cheeseEntries)..where((t) => t.isFavourite.equals(true))).watch();

  Future<int> getCheeseEntryCount() async {
    final count = countAll();
    final query = selectOnly(cheeseEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ── FTS5 maintenance ───────────────────────────────────────────────────────

  /// Upserts the [cellar_fts] row for [id].
  Future<void> upsertCellarFts(
    int id, {
    required String name,
    required String? producer,
    required String? category,
    required String? tastingNotes,
  }) async {
    await customStatement(
      'INSERT OR REPLACE INTO cellar_fts'
      '(rowid, name, producer, category, tasting_notes) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, name, producer ?? '', category ?? '', tastingNotes ?? ''],
    );
  }

  /// Removes the [cellar_fts] row for [id] using the correct contentless FTS5
  /// deletion marker. Must be called before the cellar entry row is deleted.
  Future<void> deleteCellarFts(int id) async {
    final entry = await getEntryById(id);
    if (entry == null) return;
    await customStatement(
      'INSERT INTO cellar_fts(cellar_fts, rowid, name, producer, category, tasting_notes) '
      "VALUES ('delete', ?, ?, ?, ?, ?)",
      [id, entry.name, entry.producer ?? '', entry.category ?? '', entry.tastingNotes ?? ''],
    );
  }

  /// Upserts the [cheese_fts] row for [id].
  Future<void> upsertCheeseFts(
    int id, {
    required String name,
    required String? type,
    required String? country,
    required String? milk,
    required String? flavour,
    required String? texture,
  }) async {
    await customStatement(
      'INSERT OR REPLACE INTO cheese_fts'
      '(rowid, name, type, country, milk, flavour, texture) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, name, type ?? '', country ?? '', milk ?? '', flavour ?? '', texture ?? ''],
    );
  }

  /// Removes the [cheese_fts] row for [id] using the correct contentless FTS5
  /// deletion marker. Must be called before the cheese entry row is deleted.
  Future<void> deleteCheeseFts(int id) async {
    final entry = await getCheeseEntryById(id);
    if (entry == null) return;
    await customStatement(
      'INSERT INTO cheese_fts(cheese_fts, rowid, name, type, country, milk, flavour, texture) '
      "VALUES ('delete', ?, ?, ?, ?, ?, ?, ?)",
      [id, entry.name, entry.type ?? '', entry.country ?? '', entry.milk ?? '', entry.flavour ?? '', entry.texture ?? ''],
    );
  }
}
