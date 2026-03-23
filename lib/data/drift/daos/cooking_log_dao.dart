import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'cooking_log_dao.g.dart';

@DriftAccessor(tables: [CookingLogs])
class CookingLogDao extends DatabaseAccessor<AppDatabase>
    with _$CookingLogDaoMixin {
  CookingLogDao(super.db);

  Future<int> logCook(CookingLogsCompanion log) =>
      into(cookingLogs).insert(log);

  Future<int> getCookCount(String recipeId) async {
    final count = countAll();
    final query = selectOnly(cookingLogs)
      ..addColumns([count])
      ..where(cookingLogs.recipeId.equals(recipeId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<DateTime?> getLastCookDate(String recipeId) async {
    final row = await (select(cookingLogs)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.cookedAt;
  }

  Future<List<CookingLog>> getStats() => select(cookingLogs).get();

  Future<List<CookingLog>> getRecentStats({int limit = 10}) =>
      (select(cookingLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
            ..limit(limit))
          .get();

  Stream<List<CookingLog>> watchChanges() => select(cookingLogs).watch();

  Future<int> deleteLog(int logId) =>
      (delete(cookingLogs)..where((t) => t.id.equals(logId))).go();
}
