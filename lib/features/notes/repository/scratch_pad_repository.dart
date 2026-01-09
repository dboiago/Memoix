import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../models/scratch_pad.dart';

/// Repository for scratch pad data operations
class ScratchPadRepository {
  final Isar _db;
  static const _uuid = Uuid();

  ScratchPadRepository(this._db);

  // ============ QUICK NOTES ============

  /// Get the current quick notes
  Future<String> getQuickNotes() async {
    final pad = await _db.scratchPads.where().findFirst();
    return pad?.quickNotes ?? '';
  }

  /// Watch quick notes for changes
  Stream<String> watchQuickNotes() {
    return _db.scratchPads.where().watch(fireImmediately: true).map((pads) {
      return pads.isNotEmpty ? pads.first.quickNotes : '';
    });
  }

  /// Save quick notes
  Future<void> saveQuickNotes(String notes) async {
    await _db.writeTxn(() async {
      var pad = await _db.scratchPads.where().findFirst();
      pad ??= ScratchPad();
      pad.quickNotes = notes;
      pad.updatedAt = DateTime.now();
      await _db.scratchPads.put(pad);
    });
  }

  // ============ RECIPE DRAFTS ============

  /// Get all recipe drafts
  Future<List<RecipeDraft>> getAllDrafts() async {
    return await _db.recipeDrafts.where().sortByCreatedAtDesc().findAll();
  }

  /// Watch all drafts for changes
  Stream<List<RecipeDraft>> watchAllDrafts() {
    return _db.recipeDrafts.where().sortByCreatedAtDesc().watch(fireImmediately: true);
  }

  /// Get a draft by UUID
  Future<RecipeDraft?> getDraftByUuid(String uuid) async {
    return await _db.recipeDrafts.where().uuidEqualTo(uuid).findFirst();
  }

  /// Create a new draft
  Future<RecipeDraft> createDraft({String? name}) async {
    final draft = RecipeDraft()
      ..uuid = _uuid.v4()
      ..name = name ?? 'New Recipe'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _db.writeTxn(() async {
      await _db.recipeDrafts.put(draft);
    });

    return draft;
  }

  /// Update an existing draft
  Future<void> updateDraft(RecipeDraft draft) async {
    draft.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.recipeDrafts.put(draft);
    });
  }

  /// Delete a draft by UUID
  Future<void> deleteDraft(String uuid) async {
    await _db.writeTxn(() async {
      await _db.recipeDrafts.where().uuidEqualTo(uuid).deleteAll();
    });
  }

  /// Delete a draft by ID
  Future<void> deleteDraftById(int id) async {
    await _db.writeTxn(() async {
      await _db.recipeDrafts.delete(id);
    });
  }
}

/// Provider for the scratch pad repository
final scratchPadRepositoryProvider = Provider<ScratchPadRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ScratchPadRepository(db);
});

/// Provider for quick notes stream
final quickNotesProvider = StreamProvider<String>((ref) {
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
