import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../personal_storage/services/personal_storage_service.dart';
import '../models/pizza.dart';

/// Repository for pizza data operations
class PizzaRepository {
  final AppDatabase _db;
  final Ref _ref;
  static const _uuid = Uuid();

  PizzaRepository(this._db, this._ref);

  // ============ PIZZAS ============

  /// Get all pizzas
  Future<List<Pizza>> getAllPizzas() => _db.catalogueDao.getAllPizzas();

  /// Get pizzas by base sauce
  Future<List<Pizza>> getPizzasByBase(PizzaBase base) =>
      _db.catalogueDao.getPizzasByBase(base.name);

  /// Get pizzas by source
  Future<List<Pizza>> getPizzasBySource(PizzaSource source) =>
      _db.catalogueDao.getPizzasBySource(source.name);

  /// Get personal pizzas (user's own)
  Future<List<Pizza>> getPersonalPizzas() =>
      _db.catalogueDao.getPersonalPizzas();

  /// Get memoix collection pizzas (from GitHub)
  Future<List<Pizza>> getMemoixPizzas() => _db.catalogueDao.getMemoixPizzas();

  /// Get favorite pizzas
  Future<List<Pizza>> getFavorites() => _db.catalogueDao.getFavoritePizzas();

  /// Search pizzas by name, cheese, protein, or vegetable
  Future<List<Pizza>> searchPizzas(String query) =>
      _db.catalogueDao.searchPizzas(query);

  /// Get a single pizza by ID
  Future<Pizza?> getPizzaById(int id) => _db.catalogueDao.getPizzaById(id);

  /// Get a single pizza by UUID
  Future<Pizza?> getPizzaByUuid(String uuid) =>
      _db.catalogueDao.getPizzaByUuid(uuid);

  /// Save a pizza (insert or update)
  Future<void> savePizza(Pizza pizza) async {
    final entryUuid = pizza.uuid.isEmpty ? _uuid.v4() : pizza.uuid;
    await _db.catalogueDao.savePizza(PizzasCompanion(
      id: Value(pizza.id),
      uuid: Value(entryUuid),
      name: Value(pizza.name),
      base: Value(pizza.base),
      cheeses: Value(pizza.cheeses),
      proteins: Value(pizza.proteins),
      vegetables: Value(pizza.vegetables),
      notes: Value(pizza.notes),
      imageUrl: Value(pizza.imageUrl),
      source: Value(pizza.source),
      isFavorite: Value(pizza.isFavorite),
      cookCount: Value(pizza.cookCount),
      rating: Value(pizza.rating),
      tags: Value(pizza.tags),
      createdAt: Value(pizza.createdAt),
      updatedAt: Value(DateTime.now()),
      version: Value(pizza.version),
    ));
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Delete a pizza by ID
  Future<bool> deletePizza(int id) async {
    final count = await _db.catalogueDao.deletePizza(id);
    if (count > 0) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }
    return count > 0;
  }

  /// Delete a pizza by UUID
  Future<bool> deletePizzaByUuid(String uuid) async {
    final count = await _db.catalogueDao.deletePizzaByUuid(uuid);
    if (count > 0) {
      _ref.read(personalStorageServiceProvider).onRecipeChanged();
    }
    return count > 0;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(Pizza pizza) async {
    final wasFavorited = pizza.isFavorite;
    await _db.catalogueDao.togglePizzaFavorite(pizza.id, pizza.isFavorite);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
    await IntegrityService.reportEvent(
      'activity.recipe_favourited',
      metadata: {
        'recipe_id': pizza.uuid,
        'is_adding': !wasFavorited,
      },
    );
  }

  /// Increment cook count
  Future<void> incrementCookCount(Pizza pizza) async {
    await _db.catalogueDao.incrementPizzaCookCount(pizza.id);
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Update rating
  Future<void> updateRating(Pizza pizza, int rating) async {
    await _db.catalogueDao.updatePizzaRating(pizza.id, rating.clamp(0, 5));
    _ref.read(personalStorageServiceProvider).onRecipeChanged();
  }

  /// Watch all pizzas (stream for Riverpod)
  Stream<List<Pizza>> watchAllPizzas() => _db.catalogueDao.watchAllPizzas();

  /// Watch pizzas by base
  Stream<List<Pizza>> watchPizzasByBase(PizzaBase base) =>
      _db.catalogueDao.watchPizzasByBase(base.name);

  /// Watch favorites
  Stream<List<Pizza>> watchFavorites() =>
      _db.catalogueDao.watchFavoritePizzas();

  /// Get count of all pizzas
  Future<int> getPizzaCount() => _db.catalogueDao.getPizzaCount();

  /// Get count by base
  Future<int> getPizzaCountByBase(PizzaBase base) =>
      _db.catalogueDao.getPizzaCountByBase(base.name);

  /// Bulk import pizzas (for GitHub sync)
  Future<void> importPizzas(List<Pizza> pizzas) async {
    final companions = pizzas.map((pizza) => PizzasCompanion(
          id: Value(pizza.id),
          uuid: Value(pizza.uuid),
          name: Value(pizza.name),
          base: Value(pizza.base),
          cheeses: Value(pizza.cheeses),
          proteins: Value(pizza.proteins),
          vegetables: Value(pizza.vegetables),
          notes: Value(pizza.notes),
          imageUrl: Value(pizza.imageUrl),
          source: Value(pizza.source),
          isFavorite: Value(pizza.isFavorite),
          cookCount: Value(pizza.cookCount),
          rating: Value(pizza.rating),
          tags: Value(pizza.tags),
          createdAt: Value(pizza.createdAt),
          updatedAt: Value(pizza.updatedAt),
          version: Value(pizza.version),
        )).toList();
    await _db.catalogueDao.importPizzas(companions);
  }

  /// Get all unique cheeses used across pizzas
  Future<List<String>> getAllCheeses() async {
    final allPizzas = await getAllPizzas();
    final cheeses = <String>{};
    for (final pizza in allPizzas) {
      cheeses.addAll((jsonDecode(pizza.cheeses) as List).cast<String>());
    }
    return cheeses.toList()..sort();
  }

  /// Get all unique proteins used across pizzas
  Future<List<String>> getAllProteins() async {
    final allPizzas = await getAllPizzas();
    final proteins = <String>{};
    for (final pizza in allPizzas) {
      proteins.addAll((jsonDecode(pizza.proteins) as List).cast<String>());
    }
    return proteins.toList()..sort();
  }

  /// Get all unique vegetables used across pizzas
  Future<List<String>> getAllVegetables() async {
    final allPizzas = await getAllPizzas();
    final vegetables = <String>{};
    for (final pizza in allPizzas) {
      vegetables.addAll((jsonDecode(pizza.vegetables) as List).cast<String>());
    }
    return vegetables.toList()..sort();
  }
}

// ============ PROVIDERS ============

/// Provider for the PizzaRepository
final pizzaRepositoryProvider = Provider<PizzaRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PizzaRepository(db, ref);
});

/// Watch all pizzas
final allPizzasProvider = StreamProvider<List<Pizza>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.watchAllPizzas();
});

/// Watch pizzas by base
final pizzasByBaseProvider = StreamProvider.family<List<Pizza>, PizzaBase>((ref, base) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.watchPizzasByBase(base);
});

/// Watch favorite pizzas
final favoritePizzasProvider = StreamProvider<List<Pizza>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.watchFavorites();
});

/// Get pizza count (derived from stream for auto-update)
final pizzaCountProvider = Provider<AsyncValue<int>>((ref) {
  final pizzasAsync = ref.watch(allPizzasProvider);
  return pizzasAsync.whenData((pizzas) => pizzas.length);
});

/// Get pizza count by base
final pizzaCountByBaseProvider = FutureProvider.family<int, PizzaBase>((ref, base) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getPizzaCountByBase(base);
});

/// Get all unique cheeses
final allCheesesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getAllCheeses();
});

/// Get all unique proteins
final allProteinsProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getAllProteins();
});

/// Get all unique vegetables
final allVegetablesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getAllVegetables();
});
