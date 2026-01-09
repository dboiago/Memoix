import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../models/sandwich.dart';

/// Repository for sandwich data operations
class SandwichRepository {
  final Isar _db;
  final Ref _ref;
  static const _uuid = Uuid();

  SandwichRepository(this._db, this._ref);

  // ============ SANDWICHES ============

  /// Get all sandwiches
  Future<List<Sandwich>> getAllSandwiches() async {
    return _db.sandwichs.where().findAll();
  }

  /// Get sandwiches by source
  Future<List<Sandwich>> getSandwichesBySource(SandwichSource source) async {
    return _db.sandwichs.filter().sourceEqualTo(source).findAll();
  }

  /// Get personal sandwiches (user's own)
  Future<List<Sandwich>> getPersonalSandwiches() async {
    return _db.sandwichs.filter().sourceEqualTo(SandwichSource.personal).findAll();
  }

  /// Get memoix collection sandwiches (from GitHub)
  Future<List<Sandwich>> getMemoixSandwiches() async {
    return _db.sandwichs.filter().sourceEqualTo(SandwichSource.memoix).findAll();
  }

  /// Get favorite sandwiches
  Future<List<Sandwich>> getFavorites() async {
    return _db.sandwichs.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Search sandwiches by name, bread, protein, cheese, or condiment
  Future<List<Sandwich>> searchSandwiches(String query) async {
    if (query.isEmpty) return getAllSandwiches();
    
    return _db.sandwichs
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .breadContains(query, caseSensitive: false)
        .or()
        .proteinsElementContains(query, caseSensitive: false)
        .or()
        .vegetablesElementContains(query, caseSensitive: false)
        .or()
        .cheesesElementContains(query, caseSensitive: false)
        .or()
        .condimentsElementContains(query, caseSensitive: false)
        .or()
        .tagsElementContains(query, caseSensitive: false)
        .findAll();
  }

  /// Get a single sandwich by ID
  Future<Sandwich?> getSandwichById(int id) async {
    return _db.sandwichs.get(id);
  }

  /// Get a single sandwich by UUID
  Future<Sandwich?> getSandwichByUuid(String uuid) async {
    return _db.sandwichs.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Save a sandwich (insert or update)
  Future<void> saveSandwich(Sandwich sandwich) async {
    if (sandwich.uuid.isEmpty) {
      sandwich.uuid = _uuid.v4();
    }
    sandwich.updatedAt = DateTime.now();
    
    await _db.writeTxn(() async {
      await _db.sandwichs.put(sandwich);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete a sandwich by ID
  Future<bool> deleteSandwich(int id) async {
    final result = await _db.writeTxn(() async {
      return _db.sandwichs.delete(id);
    });
    
    // Notify personal storage service of change
    if (result) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }
    
    return result;
  }

  /// Delete a sandwich by UUID
  Future<bool> deleteSandwichByUuid(String uuid) async {
    final sandwich = await getSandwichByUuid(uuid);
    if (sandwich == null) return false;
    return deleteSandwich(sandwich.id);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(Sandwich sandwich) async {
    sandwich.isFavorite = !sandwich.isFavorite;
    sandwich.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.sandwichs.put(sandwich);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Increment cook count
  Future<void> incrementCookCount(Sandwich sandwich) async {
    sandwich.cookCount += 1;
    sandwich.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.sandwichs.put(sandwich);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Update rating
  Future<void> updateRating(Sandwich sandwich, int rating) async {
    sandwich.rating = rating.clamp(0, 5);
    sandwich.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.sandwichs.put(sandwich);
    });
    
    // Notify personal storage service of change
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all sandwiches (stream for Riverpod)
  Stream<List<Sandwich>> watchAllSandwiches() {
    return _db.sandwichs.where().watch(fireImmediately: true);
  }

  /// Watch favorites
  Stream<List<Sandwich>> watchFavorites() {
    return _db.sandwichs.filter().isFavoriteEqualTo(true).watch(fireImmediately: true);
  }

  /// Get count of all sandwiches
  Future<int> getSandwichCount() async {
    return _db.sandwichs.count();
  }

  /// Bulk import sandwiches (for GitHub sync)
  Future<void> importSandwiches(List<Sandwich> sandwiches) async {
    await _db.writeTxn(() async {
      for (final sandwich in sandwiches) {
        // Check if sandwich already exists
        final existing = await _db.sandwichs.filter().uuidEqualTo(sandwich.uuid).findFirst();
        if (existing != null) {
          // Only update if newer version
          if (sandwich.version > existing.version) {
            sandwich.id = existing.id;
            await _db.sandwichs.put(sandwich);
          }
        } else {
          await _db.sandwichs.put(sandwich);
        }
      }
    });
  }

  /// Get all unique breads used across sandwiches
  Future<List<String>> getAllBreads() async {
    final sandwiches = await getAllSandwiches();
    final breads = <String>{};
    for (final sandwich in sandwiches) {
      if (sandwich.bread.isNotEmpty) {
        breads.add(sandwich.bread);
      }
    }
    final sorted = breads.toList()..sort();
    return sorted;
  }

  /// Get all unique proteins used across sandwiches
  Future<List<String>> getAllProteins() async {
    final sandwiches = await getAllSandwiches();
    final proteins = <String>{};
    for (final sandwich in sandwiches) {
      proteins.addAll(sandwich.proteins);
    }
    final sorted = proteins.toList()..sort();
    return sorted;
  }

  /// Get all unique cheeses used across sandwiches
  Future<List<String>> getAllCheeses() async {
    final sandwiches = await getAllSandwiches();
    final cheeses = <String>{};
    for (final sandwich in sandwiches) {
      cheeses.addAll(sandwich.cheeses);
    }
    final sorted = cheeses.toList()..sort();
    return sorted;
  }

  /// Get all unique condiments used across sandwiches
  Future<List<String>> getAllCondiments() async {
    final sandwiches = await getAllSandwiches();
    final condiments = <String>{};
    for (final sandwich in sandwiches) {
      condiments.addAll(sandwich.condiments);
    }
    final sorted = condiments.toList()..sort();
    return sorted;
  }
}

// ============ PROVIDERS ============

/// Provider for the SandwichRepository
final sandwichRepositoryProvider = Provider<SandwichRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SandwichRepository(db, ref);
});

/// Watch all sandwiches
final allSandwichesProvider = StreamProvider<List<Sandwich>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.watchAllSandwiches();
});

/// Watch favorite sandwiches
final favoriteSandwichesProvider = StreamProvider<List<Sandwich>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.watchFavorites();
});

/// Get sandwich count (derived from stream for auto-update)
final sandwichCountProvider = Provider<AsyncValue<int>>((ref) {
  final sandwichesAsync = ref.watch(allSandwichesProvider);
  return sandwichesAsync.whenData((sandwiches) => sandwiches.length);
});

/// Get all unique breads
final allBreadsProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.getAllBreads();
});

/// Get all unique proteins
final allProteinsProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.getAllProteins();
});

/// Get all unique sandwich cheeses
final allSandwichCheesesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.getAllCheeses();
});

/// Get all unique condiments
final allCondimentsProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.getAllCondiments();
});
