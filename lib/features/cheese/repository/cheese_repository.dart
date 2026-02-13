import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../models/cheese_entry.dart';

/// Repository for cheese entry data operations
class CheeseRepository {
  final Isar _db;
  final Ref _ref;
  static const _uuid = Uuid();

  CheeseRepository(this._db, this._ref);

  /// Get all cheese entries
  Future<List<CheeseEntry>> getAllEntries() async {
    return _db.cheeseEntrys.where().findAll();
  }

  /// Get entries by country
  Future<List<CheeseEntry>> getEntriesByCountry(String country) async {
    return _db.cheeseEntrys.filter().countryEqualTo(country, caseSensitive: false).findAll();
  }

  /// Get entries by milk type
  Future<List<CheeseEntry>> getEntriesByMilk(String milk) async {
    return _db.cheeseEntrys.filter().milkEqualTo(milk, caseSensitive: false).findAll();
  }

  /// Get entries marked as "would buy again"
  Future<List<CheeseEntry>> getBuyAgainEntries() async {
    return _db.cheeseEntrys.filter().buyEqualTo(true).findAll();
  }

  /// Get favorite entries
  Future<List<CheeseEntry>> getFavorites() async {
    return _db.cheeseEntrys.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Search entries by name, type, or country
  Future<List<CheeseEntry>> searchEntries(String query) async {
    if (query.isEmpty) return getAllEntries();
    
    return _db.cheeseEntrys
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .typeContains(query, caseSensitive: false)
        .or()
        .countryContains(query, caseSensitive: false)
        .or()
        .milkContains(query, caseSensitive: false)
        .findAll();
  }

  /// Get a single entry by ID
  Future<CheeseEntry?> getEntryById(int id) async {
    return _db.cheeseEntrys.get(id);
  }

  /// Get a single entry by UUID
  Future<CheeseEntry?> getEntryByUuid(String uuid) async {
    return _db.cheeseEntrys.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Save an entry (insert or update)
  Future<void> saveEntry(CheeseEntry entry) async {
    if (entry.uuid.isEmpty) {
      entry.uuid = _uuid.v4();
    }
    entry.updatedAt = DateTime.now();
    
    await _db.writeTxn(() async {
      await _db.cheeseEntrys.put(entry);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete an entry by ID
  Future<bool> deleteEntry(int id) async {
    final result = await _db.writeTxn(() async {
      return _db.cheeseEntrys.delete(id);
    });
    
    // Notify personal storage service of change
    if (result) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
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
  Future<void> toggleFavorite(CheeseEntry entry) async {
    final wasFavorited = entry.isFavorite;
    entry.isFavorite = !entry.isFavorite;
    entry.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.cheeseEntrys.put(entry);
    });
    
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
    entry.buy = !entry.buy;
    entry.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.cheeseEntrys.put(entry);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all entries (stream for Riverpod)
  Stream<List<CheeseEntry>> watchAllEntries() {
    return _db.cheeseEntrys.where().watch(fireImmediately: true);
  }

  /// Watch favorites
  Stream<List<CheeseEntry>> watchFavorites() {
    return _db.cheeseEntrys.filter().isFavoriteEqualTo(true).watch(fireImmediately: true);
  }

  /// Get count of all entries
  Future<int> getEntryCount() async {
    return _db.cheeseEntrys.count();
  }

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
