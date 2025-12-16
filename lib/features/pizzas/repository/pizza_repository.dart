import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../models/pizza.dart';

/// Repository for pizza data operations
class PizzaRepository {
  final Isar _db;
  static const _uuid = Uuid();

  PizzaRepository(this._db);

  // ============ PIZZAS ============

  /// Get all pizzas
  Future<List<Pizza>> getAllPizzas() async {
    return _db.pizzas.where().findAll();
  }

  /// Get pizzas by base sauce
  Future<List<Pizza>> getPizzasByBase(PizzaBase base) async {
    return _db.pizzas.filter().baseEqualTo(base).findAll();
  }

  /// Get pizzas by source
  Future<List<Pizza>> getPizzasBySource(PizzaSource source) async {
    return _db.pizzas.filter().sourceEqualTo(source).findAll();
  }

  /// Get personal pizzas (user's own)
  Future<List<Pizza>> getPersonalPizzas() async {
    return _db.pizzas.filter().sourceEqualTo(PizzaSource.personal).findAll();
  }

  /// Get memoix collection pizzas (from GitHub)
  Future<List<Pizza>> getMemoixPizzas() async {
    return _db.pizzas.filter().sourceEqualTo(PizzaSource.memoix).findAll();
  }

  /// Get favorite pizzas
  Future<List<Pizza>> getFavorites() async {
    return _db.pizzas.filter().isFavoriteEqualTo(true).findAll();
  }

  /// Search pizzas by name, cheese, protein, or vegetable
  Future<List<Pizza>> searchPizzas(String query) async {
    if (query.isEmpty) return getAllPizzas();
    
    return _db.pizzas
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .cheesesElementContains(query, caseSensitive: false)
        .or()
        .proteinsElementContains(query, caseSensitive: false)
        .or()
        .vegetablesElementContains(query, caseSensitive: false)
        .or()
        .tagsElementContains(query, caseSensitive: false)
        .findAll();
  }

  /// Get a single pizza by ID
  Future<Pizza?> getPizzaById(int id) async {
    return _db.pizzas.get(id);
  }

  /// Get a single pizza by UUID
  Future<Pizza?> getPizzaByUuid(String uuid) async {
    return _db.pizzas.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Save a pizza (insert or update)
  Future<void> savePizza(Pizza pizza) async {
    if (pizza.uuid.isEmpty) {
      pizza.uuid = _uuid.v4();
    }
    pizza.updatedAt = DateTime.now();
    
    await _db.writeTxn(() async {
      await _db.pizzas.put(pizza);
    });
  }

  /// Delete a pizza by ID
  Future<bool> deletePizza(int id) async {
    return _db.writeTxn(() async {
      return _db.pizzas.delete(id);
    });
  }

  /// Delete a pizza by UUID
  Future<bool> deletePizzaByUuid(String uuid) async {
    final pizza = await getPizzaByUuid(uuid);
    if (pizza == null) return false;
    return deletePizza(pizza.id);
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(Pizza pizza) async {
    pizza.isFavorite = !pizza.isFavorite;
    pizza.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.pizzas.put(pizza);
    });
  }

  /// Increment cook count
  Future<void> incrementCookCount(Pizza pizza) async {
    pizza.cookCount += 1;
    pizza.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.pizzas.put(pizza);
    });
  }

  /// Update rating
  Future<void> updateRating(Pizza pizza, int rating) async {
    pizza.rating = rating.clamp(0, 5);
    pizza.updatedAt = DateTime.now();
    await _db.writeTxn(() async {
      await _db.pizzas.put(pizza);
    });
  }

  /// Watch all pizzas (stream for Riverpod)
  Stream<List<Pizza>> watchAllPizzas() {
    return _db.pizzas.where().watch(fireImmediately: true);
  }

  /// Watch pizzas by base
  Stream<List<Pizza>> watchPizzasByBase(PizzaBase base) {
    return _db.pizzas.filter().baseEqualTo(base).watch(fireImmediately: true);
  }

  /// Watch favorites
  Stream<List<Pizza>> watchFavorites() {
    return _db.pizzas.filter().isFavoriteEqualTo(true).watch(fireImmediately: true);
  }

  /// Get count of all pizzas
  Future<int> getPizzaCount() async {
    return _db.pizzas.count();
  }

  /// Get count by base
  Future<int> getPizzaCountByBase(PizzaBase base) async {
    return _db.pizzas.filter().baseEqualTo(base).count();
  }

  /// Bulk import pizzas (for GitHub sync)
  Future<void> importPizzas(List<Pizza> pizzas) async {
    await _db.writeTxn(() async {
      for (final pizza in pizzas) {
        // Check if pizza already exists
        final existing = await _db.pizzas.filter().uuidEqualTo(pizza.uuid).findFirst();
        if (existing != null) {
          // Only update if newer version
          if (pizza.version > existing.version) {
            pizza.id = existing.id;
            await _db.pizzas.put(pizza);
          }
        } else {
          await _db.pizzas.put(pizza);
        }
      }
    });
  }

  /// Get all unique cheeses used across pizzas
  Future<List<String>> getAllCheeses() async {
    final pizzas = await getAllPizzas();
    final cheeses = <String>{};
    for (final pizza in pizzas) {
      cheeses.addAll(pizza.cheeses);
    }
    final sorted = cheeses.toList()..sort();
    return sorted;
  }

  /// Get all unique proteins used across pizzas
  Future<List<String>> getAllProteins() async {
    final pizzas = await getAllPizzas();
    final proteins = <String>{};
    for (final pizza in pizzas) {
      proteins.addAll(pizza.proteins);
    }
    final sorted = proteins.toList()..sort();
    return sorted;
  }

  /// Get all unique vegetables used across pizzas
  Future<List<String>> getAllVegetables() async {
    final pizzas = await getAllPizzas();
    final vegetables = <String>{};
    for (final pizza in pizzas) {
      vegetables.addAll(pizza.vegetables);
    }
    final sorted = vegetables.toList()..sort();
    return sorted;
  }
}

// ============ PROVIDERS ============

/// Provider for the PizzaRepository
final pizzaRepositoryProvider = Provider<PizzaRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PizzaRepository(db);
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

/// Get all unique toppings
final allToppingsProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getAllToppings();
});
