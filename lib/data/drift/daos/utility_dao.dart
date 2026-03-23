import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

part 'utility_dao.g.dart';

@DriftAccessor(tables: [ScratchPads, RecipeDrafts])
class UtilityDao extends DatabaseAccessor<AppDatabase>
    with _$UtilityDaoMixin {
  UtilityDao(super.db);

  // ─── SCRATCH PAD ──────────────────────────────────────────────────────────

  Future<ScratchPad?> getQuickNotes() =>
      (select(scratchPads)..limit(1)).getSingleOrNull();

  Stream<ScratchPad?> watchQuickNotes() =>
      (select(scratchPads)..limit(1)).watchSingleOrNull();

  Future<int> saveQuickNotes(ScratchPadsCompanion pad) =>
      into(scratchPads).insertOnConflictUpdate(pad);

  // ─── RECIPE DRAFTS ────────────────────────────────────────────────────────

  Future<List<RecipeDraft>> getAllDrafts() =>
      (select(recipeDrafts)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<RecipeDraft>> watchAllDrafts() =>
      (select(recipeDrafts)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<RecipeDraft?> getDraftByUuid(String uuid) =>
      (select(recipeDrafts)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<int> createDraft(RecipeDraftsCompanion draft) =>
      into(recipeDrafts).insert(draft);

  Future<int> updateDraft(RecipeDraftsCompanion draft) =>
      into(recipeDrafts).insertOnConflictUpdate(draft);

  Future<int> deleteDraftByUuid(String uuid) =>
      (delete(recipeDrafts)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteDraftById(int id) =>
      (delete(recipeDrafts)..where((t) => t.id.equals(id))).go();
}
