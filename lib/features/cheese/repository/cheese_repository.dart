import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../../personal_storage/services/tombstone_store.dart';

/// Repository for cheese entry data operations
class CheeseRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  CheeseRepository(this._db, this._ref);

  /// Get all cheese entries
  Future<List<CheeseEntry>> getAllEntries() =>
      _db.cellarDao.getAllCheeseEntries();

  /// Get entries by country
  Future<List<CheeseEntry>> getEntriesByCountry(String country) =>
      _db.cellarDao.getCheeseEntriesByCountry(country);

  /// Get entries by milk type
  Future<List<CheeseEntry>> getEntriesByMilk(String milk) =>
      _db.cellarDao.getCheeseEntriesByMilk(milk);

  /// Get entries marked as "would buy again"
  Future<List<CheeseEntry>> getBuyAgainEntries() =>
      _db.cellarDao.getCheeseBuyAgainEntries();

  /// Get favorite entries
  Future<List<CheeseEntry>> getFavorites() =>
      _db.cellarDao.getCheeseFavorites();

  /// Search entries by name, type, or country
  Future<List<CheeseEntry>> searchEntries(String query) {
    if (query.isEmpty) return getAllEntries();
    return _db.cellarDao.searchCheeseEntries(query);
  }

  /// Get a single entry by ID
  Future<CheeseEntry?> getEntryById(int id) =>
      _db.cellarDao.getCheeseEntryById(id);

  /// Get a single entry by UUID
  Future<CheeseEntry?> getEntryByUuid(String uuid) =>
      _db.cellarDao.getCheeseEntryByUuid(uuid);

  /// Save an entry (insert or update)
  Future<void> saveEntry(CheeseEntry entry, {bool preserveTimestamp = false}) async {
    final entryUuid = entry.uuid.isEmpty ? _uuid.v4() : entry.uuid;
    await _db.cellarDao.saveCheeseEntry(CheeseEntriesCompanion(
      id: entry.id > 0 ? Value(entry.id) : const Value.absent(),
      uuid: Value(entryUuid),
      name: Value(entry.name),
      country: Value(entry.country),
      milk: Value(entry.milk),
      texture: Value(entry.texture),
      type: Value(entry.type),
      buy: Value(entry.buy),
      flavour: Value(entry.flavour),
      priceRange: Value(entry.priceRange),
      imageUrl: Value(entry.imageUrl),
      source: Value(entry.source),
      isFavorite: Value(entry.isFavorite),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(preserveTimestamp ? entry.updatedAt : DateTime.now()),
      version: Value(entry.version),
    ));

    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete an entry by ID
  Future<bool> deleteEntry(int id) async {
    final deleted = await _db.cellarDao.deleteCheeseEntry(id);
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
      await TombstoneStore.add(TombstoneDomain.cheeses, uuid);
    }
    final deleted = await _db.cellarDao.deleteCheeseEntryByUuid(uuid);
    final result = deleted > 0;
    if (result) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }
    return result;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(CheeseEntry entry) async {
    final wasFavorited = entry.isFavorite;
    await _db.cellarDao.toggleCheeseFavorite(entry.id, entry.isFavorite);

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
  Future<void> toggleBuy(CheeseEntry entry) async {
    await _db.cellarDao.toggleCheeseBuy(entry.id, entry.buy);

    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all entries (stream for Riverpod)
  Stream<List<CheeseEntry>> watchAllEntries() =>
      _db.cellarDao.watchAllCheeseEntries();

  /// Watch favorites
  Stream<List<CheeseEntry>> watchFavorites() =>
      _db.cellarDao.watchCheeseFavorites();

  /// Get count of all entries
  Future<int> getEntryCount() =>
      _db.cellarDao.getCheeseEntryCount();

  /// Get all unique countries
  Future<List<String>> getAllCountries() async {
    final entries = await getAllEntries();
    final countries = <String>{};
    for (final entry in entries) {
      if (entry.country != null && entry.country!.isNotEmpty) {
        countries.add(entry.country!);
      }
    }
    final sorted = countries.toList()..sort();
    return sorted;
  }

  /// Get all unique milk types
  Future<List<String>> getAllMilkTypes() async {
    final entries = await getAllEntries();
    final milks = <String>{};
    for (final entry in entries) {
      if (entry.milk != null && entry.milk!.isNotEmpty) {
        milks.add(entry.milk!);
      }
    }
    final sorted = milks.toList()..sort();
    return sorted;
  }

  /// Get all unique textures
  Future<List<String>> getAllTextures() async {
    final entries = await getAllEntries();
    final textures = <String>{};
    for (final entry in entries) {
      if (entry.texture != null && entry.texture!.isNotEmpty) {
        textures.add(entry.texture!);
      }
    }
    final sorted = textures.toList()..sort();
    return sorted;
  }

  /// Get all unique types
  Future<List<String>> getAllTypes() async {
    final entries = await getAllEntries();
    final types = <String>{};
    for (final entry in entries) {
      if (entry.type != null && entry.type!.isNotEmpty) {
        types.add(entry.type!);
      }
    }
    final sorted = types.toList()..sort();
    return sorted;
  }
}

// ============ PROVIDERS ============

/// Provider for the CheeseRepository
final cheeseRepositoryProvider = Provider<CheeseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CheeseRepository(db, ref);
});

/// Watch all cheese entries
final allCheeseEntriesProvider = StreamProvider<List<CheeseEntry>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.watchAllEntries();
});

/// Watch favorite cheese entries
final favoriteCheeseEntriesProvider = StreamProvider<List<CheeseEntry>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.watchFavorites();
});

/// Get cheese entry count (derived from stream for auto-update)
final cheeseCountProvider = Provider<AsyncValue<int>>((ref) {
  final entriesAsync = ref.watch(allCheeseEntriesProvider);
  return entriesAsync.whenData((entries) => entries.length);
});

/// Get all unique countries
final cheeseCountriesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.getAllCountries();
});

/// Get all unique milk types
final cheeseMilkTypesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.getAllMilkTypes();
});

/// Get all unique textures
final cheeseTexturesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.getAllTextures();
});

/// Get all unique types
final cheeseTypesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(cheeseRepositoryProvider);
  return repository.getAllTypes();
});
