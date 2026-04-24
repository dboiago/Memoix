import 'dart:async';
import 'dart:convert';

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
import '../models/sandwich.dart';

/// Repository for sandwich data operations
class SandwichRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  SandwichRepository(this._db, this._ref);

  // ============ SANDWICHES ============

  /// Get all sandwiches
  Future<List<Sandwich>> getAllSandwiches() =>
      _db.catalogueDao.getAllSandwiches();

  /// Get sandwiches by source
  Future<List<Sandwich>> getSandwichesBySource(SandwichSource source) =>
      _db.catalogueDao.getSandwichesBySource(source.name);

  /// Get personal sandwiches (user's own)
  Future<List<Sandwich>> getPersonalSandwiches() =>
      _db.catalogueDao.getPersonalSandwiches();

  /// Get memoix collection sandwiches (from GitHub)
  Future<List<Sandwich>> getMemoixSandwiches() =>
      _db.catalogueDao.getMemoixSandwiches();

  /// Get favourite sandwiches
  Future<List<Sandwich>> getFavourites() =>
      _db.catalogueDao.getFavouriteSandwiches();

  /// Search sandwiches by name, bread, protein, cheese, or condiment
  Future<List<Sandwich>> searchSandwiches(String query) =>
      _db.catalogueDao.searchSandwiches(query);

  /// Get a single sandwich by ID
  Future<Sandwich?> getSandwichById(int id) =>
      _db.catalogueDao.getSandwichById(id);

  /// Get a single sandwich by UUID
  Future<Sandwich?> getSandwichByUuid(String uuid) =>
      _db.catalogueDao.getSandwichByUuid(uuid);

  /// Save a sandwich (insert or update)
  Future<void> saveSandwich(Sandwich sandwich, {bool preserveTimestamp = false}) async {
    final entryUuid = sandwich.uuid.isEmpty ? _uuid.v4() : sandwich.uuid;
    // Defensive length caps before the DB write.
    final safeName = sandwich.name.length > 120 ? sandwich.name.substring(0, 120).trimRight() : sandwich.name;
    final safeNotes = (sandwich.notes?.length ?? 0) > 4000 ? sandwich.notes!.substring(0, 4000).trimRight() : sandwich.notes;
    await _db.catalogueDao.saveSandwich(SandwichesCompanion(
      id: sandwich.id > 0 ? Value(sandwich.id) : const Value.absent(),
      uuid: Value(entryUuid),
      name: Value(safeName),
      bread: Value(sandwich.bread),
      proteins: Value(sandwich.proteins),
      vegetables: Value(sandwich.vegetables),
      cheeses: Value(sandwich.cheeses),
      condiments: Value(sandwich.condiments),
      notes: Value(safeNotes),
      imageUrl: Value(sandwich.imageUrl),
      source: Value(sandwich.source),
      isFavorite: Value(sandwich.isFavorite),
      cookCount: Value(sandwich.cookCount),
      rating: Value(sandwich.rating),
      tags: Value(sandwich.tags),
      createdAt: Value(sandwich.createdAt),
      updatedAt: Value(preserveTimestamp ? sandwich.updatedAt : DateTime.now()),
      version: Value(sandwich.version),
    ),);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete a sandwich by ID
  Future<bool> deleteSandwich(int id) async {
    final count = await _db.catalogueDao.deleteSandwich(id);
    if (count > 0) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }
    return count > 0;
  }

  /// Delete a sandwich by UUID
  Future<bool> deleteSandwichByUuid(String uuid, {bool fromMerge = false}) async {
    if (!fromMerge) {
      await TombstoneStore.add(TombstoneDomain.sandwiches, uuid);
    }
    final count = await _db.catalogueDao.deleteSandwichByUuid(uuid);
    if (count > 0) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
      unawaited(SupabaseSyncService.notifyDeleted('sandwiches', uuid));
    }
    return count > 0;
  }

  /// Toggle favourite status
  Future<void> toggleFavourite(Sandwich sandwich) async {
    final wasFavorited = sandwich.isFavorite;
    await _db.catalogueDao.toggleSandwichFavourite(sandwich.id, sandwich.isFavorite);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': sandwich.uuid,
        'is_adding': !wasFavorited,
      },
    );
  }

  /// Increment cook count
  Future<void> incrementCookCount(Sandwich sandwich) async {
    await _db.catalogueDao.incrementSandwichCookCount(sandwich.id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Update rating
  Future<void> updateRating(Sandwich sandwich, int rating) async {
    await _db.catalogueDao.updateSandwichRating(sandwich.id, rating.clamp(0, 5));
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all sandwiches (stream for Riverpod)
  Stream<List<Sandwich>> watchAllSandwiches() =>
      _db.catalogueDao.watchAllSandwiches();

  /// Watch favourites
  Stream<List<Sandwich>> watchFavourites() =>
      _db.catalogueDao.watchFavouriteSandwiches();

  /// Get count of all sandwiches
  Future<int> getSandwichCount() => _db.catalogueDao.getSandwichCount();

  /// Bulk import sandwiches (for GitHub sync)
  Future<void> importSandwiches(List<Sandwich> sandwiches) async {
    final companions = sandwiches.map((sandwich) => SandwichesCompanion(
          id: sandwich.id > 0 ? Value(sandwich.id) : const Value.absent(),
          uuid: Value(sandwich.uuid.isEmpty ? _uuid.v4() : sandwich.uuid),
          name: Value(sandwich.name),
          bread: Value(sandwich.bread),
          proteins: Value(sandwich.proteins),
          vegetables: Value(sandwich.vegetables),
          cheeses: Value(sandwich.cheeses),
          condiments: Value(sandwich.condiments),
          notes: Value(sandwich.notes),
          imageUrl: Value(sandwich.imageUrl),
          source: Value(sandwich.source),
          isFavorite: Value(sandwich.isFavorite),
          cookCount: Value(sandwich.cookCount),
          rating: Value(sandwich.rating),
          tags: Value(sandwich.tags),
          createdAt: Value(sandwich.createdAt),
          updatedAt: Value(sandwich.updatedAt),
          version: Value(sandwich.version),
        ),).toList();
    await _db.catalogueDao.importSandwiches(companions);
  }

  /// Get all unique breads used across sandwiches
  Future<List<String>> getAllBreads() async {
    final allSandwiches = await getAllSandwiches();
    return extractUniqueStrings(
        allSandwiches, (s) => s.bread.isEmpty ? null : s.bread,);
  }

  /// Get all unique proteins used across sandwiches
  Future<List<String>> getAllProteins() async {
    final allSandwiches = await getAllSandwiches();
    return extractUniqueStringLists(
        allSandwiches,
        (s) => (jsonDecode(s.proteins) as List).cast<String>(),);
  }

  /// Get all unique cheeses used across sandwiches
  Future<List<String>> getAllCheeses() async {
    final allSandwiches = await getAllSandwiches();
    return extractUniqueStringLists(
        allSandwiches,
        (s) => (jsonDecode(s.cheeses) as List).cast<String>(),);
  }

  /// Get all unique condiments used across sandwiches
  Future<List<String>> getAllCondiments() async {
    final allSandwiches = await getAllSandwiches();
    return extractUniqueStringLists(
        allSandwiches,
        (s) => (jsonDecode(s.condiments) as List).cast<String>(),);
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

/// Watch favourite sandwiches
final favouriteSandwichesProvider = StreamProvider<List<Sandwich>>((ref) {
  final repository = ref.watch(sandwichRepositoryProvider);
  return repository.watchFavourites();
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
