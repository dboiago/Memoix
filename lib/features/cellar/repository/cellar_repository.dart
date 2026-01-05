import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../external_storage/services/external_storage_service.dart';
import '../models/cellar_entry.dart';

/// Repository for cellar entry data operations
class CellarRepository {
  final Isar _db;
  final Ref _ref;
  static const _uuid = Uuid();

  CellarRepository(this._db, this._ref);

  /// Get all cellar entries
  Future<List<CellarEntry>> getAllEntries() async {
    return _db.cellarEntrys.where().findAll();
  }

  /// Get entries by category
  Future<List<CellarEntry>> getEntriesByCategory(String category) async {
    return _db.cellarEntrys.filter().categoryEqualTo(category, caseSensitive: false).findAll();
  }

  /// Get entries marked as "would buy again"
  Future<List<CellarEntry>> getBuyAgainEntries() async {
    return _db.cellarEntrys.filter().buyEqualTo(true).findAll();
  }

  /// Get favorite entries
  Future<List<CellarEntry>> getFavorites() async {
    return _db.cellarEntrys.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Search entries by name, producer, or category
  Future<List<CellarEntry>> searchEntries(String query) async {
    if (query.isEmpty) return getAllEntries();
    
    return _db.cellarEntrys
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .producerContains(query, caseSensitive: false)
        .or()
        .categoryContains(query, caseSensitive: false)
        .findAll();
  }

  /// Get a single entry by ID
  Future<CellarEntry?> getEntryById(int id) async {
    return _db.cellarEntrys.get(id);
  }

  /// Get a single entry by UUID
  Future<CellarEntry?> getEntryByUuid(String uuid) async {
    return _db.cellarEntrys.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Save an entry (insert or update)
  Future<void> saveEntry(CellarEntry entry) async {
    if (entry.uuid.isEmpty) {
      entry.uuid = _uuid.v4();
    }
    entry.updatedAt = DateTime.now();
    
    await _db.writeTxn(() async {
      await _db.cellarEntrys.put(entry);
    });
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete an entry by ID
  Future<bool> deleteEntry(int id) async {
    final result = await _db.writeTxn(() async {
      return _db.cellarEntrys.delete(id);
    });
    
    // Notify external storage service of change
    if (result) {
      _ref.read(externalStorageServiceProvider).onRecipeChanged();
    }
    
    return result;
  }

  /// Delete an entry by UUID
  Future<bool> deleteEntryByUuid(String uuid) async {
    final entry = await getEntryByUuid(uuid);
    if (entry == null) return false;
    return deleteEntry(entry.id);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(CellarEntry entry) async {
    entry.isFavorite = !entry.isFavorite;
    entry.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.cellarEntrys.put(entry);
    });
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
  }

  /// Toggle buy status
  Future<void> toggleBuy(CellarEntry entry) async {
    entry.buy = !entry.buy;
    entry.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.cellarEntrys.put(entry);
    });
    
    // Notify external storage service of change
    _ref.read(externalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all entries (stream for Riverpod)
  Stream<List<CellarEntry>> watchAllEntries() {
    return _db.cellarEntrys.where().watch(fireImmediately: true);
  }

  /// Watch favorites
  Stream<List<CellarEntry>> watchFavorites() {
    return _db.cellarEntrys.filter().isFavoriteEqualTo(true).watch(fireImmediately: true);
  }

  /// Get count of all entries
  Future<int> getEntryCount() async {
    return _db.cellarEntrys.count();
  }

  /// Get all unique categories
  Future<List<String>> getAllCategories() async {
    final entries = await getAllEntries();
    final categories = <String>{};
    for (final entry in entries) {
      if (entry.category != null && entry.category!.isNotEmpty) {
        categories.add(entry.category!);
      }
    }
    final sorted = categories.toList()..sort();
    return sorted;
  }

  /// Get all unique producers
  Future<List<String>> getAllProducers() async {
    final entries = await getAllEntries();
    final producers = <String>{};
    for (final entry in entries) {
      if (entry.producer != null && entry.producer!.isNotEmpty) {
        producers.add(entry.producer!);
      }
    }
    final sorted = producers.toList()..sort();
    return sorted;
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
