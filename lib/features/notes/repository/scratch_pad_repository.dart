import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_sync_service.dart';

/// Repository for scratch pad data operations
class ScratchPadRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ScratchPadRepository(this._db);

  // ============ QUICK NOTES ============

  /// Get the current quick notes
  Future<String> getQuickNotes() async {
    final pad = await _db.utilityDao.getQuickNotes();
    return pad?.quickNotes ?? '';
  }

  /// Watch quick notes for changes
  Stream<ScratchPad?> watchQuickNotes() =>
      _db.utilityDao.watchQuickNotes();

  /// Save quick notes
  Future<void> saveQuickNotes(String notes) async {
    await _db.utilityDao.saveQuickNotes(ScratchPadsCompanion(
      id: const Value(1),
      quickNotes: Value(notes),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ============ RECIPE DRAFTS ============

  /// Get all recipe drafts
  Future<List<RecipeDraft>> getAllDrafts() =>
      _db.utilityDao.getAllDrafts();

  /// Watch all drafts for changes
  Stream<List<RecipeDraft>> watchAllDrafts() =>
      _db.utilityDao.watchAllDrafts();

  /// Get a draft by UUID
  Future<RecipeDraft?> getDraftByUuid(String uuid) =>
      _db.utilityDao.getDraftByUuid(uuid);

  /// Create a new draft
  Future<RecipeDraft> createDraft({String? name}) async {
    final newUuid = _uuid.v4();
    final now = DateTime.now();
    await _db.utilityDao.createDraft(RecipeDraftsCompanion.insert(
      uuid: newUuid,
      name: Value(name ?? 'New Recipe'),
      createdAt: now,
      updatedAt: now,
    ));
    return (await _db.utilityDao.getDraftByUuid(newUuid))!;
  }

  /// Update an existing draft
  Future<void> updateDraft(RecipeDraft draft) async {
    await _db.utilityDao.updateDraft(RecipeDraftsCompanion(
      id: Value(draft.id),
      uuid: Value(draft.uuid),
      name: Value(draft.name),
      imagePath: Value(draft.imagePath),
      serves: Value(draft.serves),
      time: Value(draft.time),
      course: Value(draft.course),
      structuredIngredients: Value(draft.structuredIngredients),
      structuredDirections: Value(draft.structuredDirections),
      legacyIngredients: Value(draft.legacyIngredients),
      legacyDirections: Value(draft.legacyDirections),
      notes: Value(draft.notes),
      stepImages: Value(draft.stepImages),
      stepImageMap: Value(draft.stepImageMap),
      pairedRecipeIds: Value(draft.pairedRecipeIds),
      createdAt: Value(draft.createdAt),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Delete a draft by UUID
  Future<void> deleteDraft(String uuid) =>
      _db.utilityDao.deleteDraftByUuid(uuid).then((_) {
        unawaited(SupabaseSyncService.notifyDeleted('recipe_drafts', uuid));
      });

  /// Delete a draft by ID
  Future<void> deleteDraftById(int id) =>
      _db.utilityDao.deleteDraftById(id).then((_) {});
}

/// Provider for the scratch pad repository
final scratchPadRepositoryProvider = Provider<ScratchPadRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ScratchPadRepository(db);
});

/// Provider for quick notes stream
final quickNotesProvider = StreamProvider<ScratchPad?>((ref) {
  return ref.watch(scratchPadRepositoryProvider).watchQuickNotes();
});

/// Provider for recipe drafts stream
final recipeDraftsProvider = StreamProvider<List<RecipeDraft>>((ref) {
  return ref.watch(scratchPadRepositoryProvider).watchAllDrafts();
});

/// Service for managing draft deletion with undo capability
/// Stores timers at service level so they persist across widget rebuilds
class DraftDeletionService {
  final ScratchPadRepository _repository;
  
  // Track pending deletes at service level so they persist across widget rebuilds
  final Map<String, Timer> _pendingDeletes = {};

  DraftDeletionService(this._repository);
  
  /// Schedule a draft for deletion with undo capability
  void scheduleDraftDelete({
    required String uuid,
    required Duration undoDuration,
    VoidCallback? onComplete,
  }) {
    // Cancel any existing pending delete for this UUID
    _pendingDeletes[uuid]?.cancel();
    
    // Start timer
    _pendingDeletes[uuid] = Timer(undoDuration, () async {
      _pendingDeletes.remove(uuid);
      await _repository.deleteDraft(uuid);
      onComplete?.call();
    });
  }
  
  /// Cancel a pending delete (undo)
  void cancelPendingDelete(String uuid) {
    _pendingDeletes[uuid]?.cancel();
    _pendingDeletes.remove(uuid);
  }
  
  /// Check if a delete is pending for a UUID
  bool isPendingDelete(String uuid) => _pendingDeletes.containsKey(uuid);
}

/// Provider for the draft deletion service
final draftDeletionServiceProvider = Provider<DraftDeletionService>((ref) {
  final repository = ref.watch(scratchPadRepositoryProvider);
  return DraftDeletionService(repository);
});
