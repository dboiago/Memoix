import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/utils/collection_utils.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../../personal_storage/services/tombstone_store.dart';

/// Repository for cellar entry data operations
class CellarRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  CellarRepository(this._db, this._ref);

  /// Get all cellar entries
  Future<List<CellarEntry>> getAllEntries() =>
      _db.cellarDao.getAllEntries();

  /// Get entries by category
  Future<List<CellarEntry>> getEntriesByCategory(String category) =>
      _db.cellarDao.getEntriesByCategory(category);

  /// Get entries marked as "would buy again"
  Future<List<CellarEntry>> getBuyAgainEntries() =>
      _db.cellarDao.getBuyAgainEntries();

  /// Get favorite entries
  Future<List<CellarEntry>> getFavorites() =>
      _db.cellarDao.getFavorites();

  /// Search entries by name, producer, or category
  Future<List<CellarEntry>> searchEntries(String query) {
    if (query.isEmpty) return getAllEntries();
    return _db.cellarDao.searchEntries(query);
  }

  /// Get a single entry by ID
  Future<CellarEntry?> getEntryById(int id) =>
      _db.cellarDao.getEntryById(id);

  /// Get a single entry by UUID
  Future<CellarEntry?> getEntryByUuid(String uuid) =>
      _db.cellarDao.getEntryByUuid(uuid);

  /// Save an entry (insert or update)
  Future<void> saveEntry(CellarEntry entry, {bool preserveTimestamp = false}) async {
    final entryUuid = entry.uuid.isEmpty ? _uuid.v4() : entry.uuid;
    await _db.cellarDao.saveEntry(CellarEntriesCompanion(
      id: entry.id > 0 ? Value(entry.id) : const Value.absent(),
      uuid: Value(entryUuid),
      name: Value(entry.name),
      producer: Value(entry.producer),
      category: Value(entry.category),
      buy: Value(entry.buy),
      tastingNotes: Value(entry.tastingNotes),
      abv: Value(entry.abv),
      ageVintage: Value(entry.ageVintage),
      priceRange: Value(entry.priceRange),
      imageUrl: Value(entry.imageUrl),
      source: Value(entry.source),
      isFavorite: Value(entry.isFavorite),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(preserveTimestamp ? entry.updatedAt : DateTime.now()),
      version: Value(entry.version),
    ),);

    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete an entry by ID
  Future<bool> deleteEntry(int id) async {
    final deleted = await _db.cellarDao.deleteEntry(id);
    final result = deleted > 0;

    // Notify personal storage service of change
    if (result) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }

    return result;
  }

  /// Delete an entry by UUID
  Future<bool> deleteEntryByUuid(String uuid, {bool fromMerge = false}) async {
    if (!fromMerge) {
      await TombstoneStore.add(TombstoneDomain.cellar, uuid);
    }
    final deleted = await _db.cellarDao.deleteEntryByUuid(uuid);
    final result = deleted > 0;
    if (result) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
      unawaited(SupabaseSyncService.notifyDeleted('cellar_entries', uuid));
    }
    return result;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(CellarEntry entry) async {
    final wasFavorited = entry.isFavorite;
    await _db.cellarDao.toggleFavorite(entry.id, entry.isFavorite);

    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();

    // Report favorite toggle
    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': entry.uuid,
        'is_adding': !wasFavorited,
      },
    );
  }

  /// Toggle buy status
  Future<void> toggleBuy(CellarEntry entry) async {
    await _db.cellarDao.toggleBuy(entry.id, entry.buy);

    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all entries (stream for Riverpod)
  Stream<List<CellarEntry>> watchAllEntries() =>
      _db.cellarDao.watchAllEntries();

  /// Watch favorites
  Stream<List<CellarEntry>> watchFavorites() =>
      _db.cellarDao.watchFavorites();

  /// Get count of all entries
  Future<int> getEntryCount() =>
      _db.cellarDao.getEntryCount();

  /// Get all unique categories
  Future<List<String>> getAllCategories() async {
    final entries = await getAllEntries();
    return extractUniqueStrings(entries, (e) => e.category);
  }

  /// Get all unique producers
  Future<List<String>> getAllProducers() async {
    final entries = await getAllEntries();
    return extractUniqueStrings(entries, (e) => e.producer);
  }
}

// ============ PROVIDERS ============

/// Provider for the CellarRepository
final cellarRepositoryProvider = Provider<CellarRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CellarRepository(db, ref);
});

/// Watch all cellar entries
final allCellarEntriesProvider = StreamProvider<List<CellarEntry>>((ref) {
  final repository = ref.watch(cellarRepositoryProvider);
  return repository.watchAllEntries();
});

/// Watch favorite cellar entries
final favoriteCellarEntriesProvider = StreamProvider<List<CellarEntry>>((ref) {
  final repository = ref.watch(cellarRepositoryProvider);
  return repository.watchFavorites();
});

/// Get cellar entry count (derived from stream for auto-update)
final cellarCountProvider = Provider<AsyncValue<int>>((ref) {
  final entriesAsync = ref.watch(allCellarEntriesProvider);
  return entriesAsync.whenData((entries) => entries.length);
});

/// Get all unique categories
final cellarCategoriesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cellarRepositoryProvider);
  return repository.getAllCategories();
});

/// Get all unique producers
final cellarProducersProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cellarRepositoryProvider);
  return repository.getAllProducers();
});
