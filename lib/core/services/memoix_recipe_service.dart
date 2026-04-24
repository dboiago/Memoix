import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' hide Recipe, Ingredient, Course;
import '../../features/cellar/models/cellar_entry.dart';
import '../../features/cellar/repository/cellar_repository.dart';
import '../../features/cheese/models/cheese_entry.dart';
import '../../features/cheese/repository/cheese_repository.dart';
import '../../features/modernist/models/modernist_recipe.dart';
import '../../features/modernist/repository/modernist_repository.dart';
import '../../features/pizzas/models/pizza.dart';
import '../../features/pizzas/repository/pizza_repository.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/repository/recipe_repository.dart';
import '../../features/sandwiches/models/sandwich.dart';
import '../../features/sandwiches/repository/sandwich_repository.dart';
import '../../features/smoking/models/smoking_recipe.dart';
import '../../features/smoking/repository/smoking_repository.dart';

/// Specialized domain file names that are handled by dedicated parsers.
/// All other files listed in index.json are loaded as standard [Recipe] objects.
const _specializedDomains = {
  'pizzas.json',
  'sandwiches.json',
  'smoking.json',
  'modernist.json',
  'cheese.json',
  'cellar.json',
  'scratch.json', // scratch pad — not a recipe list; no dedicated parser
};

/// Loads bundled Memoix recipe assets and seeds them into the local database.
///
/// All methods read from `assets/recipes/` via [rootBundle] — no network
/// requests are made. Each domain method is called once at startup (and
/// whenever the user triggers a manual refresh) by [syncRecipesProvider] /
/// [SyncNotifier]. Insertion is idempotent: the repository layer skips any
/// recipe whose UUID already exists in Drift.
class MemoixRecipeService {
  /// Loads all standard recipes from bundled asset files.
  ///
  /// Reads `assets/recipes/index.json` to discover file names, then loads
  /// every file that is not in [_specializedDomains].
  Future<List<Recipe>> fetchAllRecipes() async {
    try {
      final indexRaw =
          await rootBundle.loadString('assets/recipes/index.json');
      final index = jsonDecode(indexRaw) as Map<String, dynamic>;
      final files = (index['files'] as List<dynamic>).cast<String>();

      final recipeFiles =
          files.where((f) => !_specializedDomains.contains(f)).toList();

      final results = await Future.wait(recipeFiles.map(_loadRecipeFile));
      return results.expand((list) => list).toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchAllRecipes: $e');
      return [];
    }
  }

  Future<List<Recipe>> _loadRecipeFile(String filename) async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/$filename');
      final data = jsonDecode(raw);
      final list = data is List ? data : [data];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => Recipe.fromJson(e)..source = RecipeSource.memoix)
          .where((r) => r.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService._loadRecipeFile($filename): $e');
      return [];
    }
  }

  Future<List<Pizza>> fetchPizzas() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/pizzas.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) =>
              pizzaFromJson(e).copyWith(source: PizzaSource.memoix.name))
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchPizzas: $e');
      return [];
    }
  }

  Future<List<Sandwich>> fetchSandwiches() async {
    try {
      final raw =
          await rootBundle.loadString('assets/recipes/sandwiches.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) =>
              sandwichFromJson(e).copyWith(source: SandwichSource.memoix.name))
          .where((s) => s.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchSandwiches: $e');
      return [];
    }
  }

  Future<List<SmokingRecipe>> fetchSmokingRecipes() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/smoking.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => smokingRecipeFromJson(e)
              .copyWith(source: SmokingSource.memoix.name))
          .where((s) => s.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchSmokingRecipes: $e');
      return [];
    }
  }

  Future<List<ModernistRecipe>> fetchModernistRecipes() async {
    try {
      final raw =
          await rootBundle.loadString('assets/recipes/modernist.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => ModernistRecipe.fromJson(e)..source = ModernistSource.memoix)
          .where((m) => m.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchModernistRecipes: $e');
      return [];
    }
  }

  Future<List<CheeseEntry>> fetchCheeseEntries() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/cheese.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) =>
              cheeseEntryFromJson(e).copyWith(source: CheeseSource.memoix.name))
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchCheeseEntries: $e');
      return [];
    }
  }

  Future<List<CellarEntry>> fetchCellarEntries() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/cellar.json');
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) =>
              cellarEntryFromJson(e).copyWith(source: CellarSource.memoix.name))
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchCellarEntries: $e');
      return [];
    }
  }
}

// ============ PROVIDERS ============

final MemoixRecipeServiceProvider = Provider<MemoixRecipeService>((ref) {
  return MemoixRecipeService();
});

/// Provider to sync all data from GitHub (recipes + specialized domains)
final syncRecipesProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(MemoixRecipeServiceProvider);
  final recipeRepo = ref.watch(recipeRepositoryProvider);
  final pizzaRepo = ref.watch(pizzaRepositoryProvider);
  final sandwichRepo = ref.watch(sandwichRepositoryProvider);
  final smokingRepo = ref.watch(smokingRepositoryProvider);
  final modernistRepo = ref.watch(modernistRepositoryProvider);
  final cheeseRepo = ref.watch(cheeseRepositoryProvider);
  final cellarRepo = ref.watch(cellarRepositoryProvider);
  
  // Sync all domains in parallel
  await Future.wait([
    service.fetchAllRecipes().then((recipes) => recipeRepo.syncMemoixRecipes(recipes)),
    service.fetchPizzas().then((pizzas) => _syncPizzas(pizzaRepo, pizzas)),
    service.fetchSandwiches().then((sandwiches) => _syncSandwiches(sandwichRepo, sandwiches)),
    service.fetchSmokingRecipes().then((recipes) => _syncSmokingRecipes(smokingRepo, recipes)),
    service.fetchModernistRecipes().then((recipes) => _syncModernistRecipes(modernistRepo, recipes)),
    service.fetchCheeseEntries().then((entries) => _syncCheeseEntries(cheeseRepo, entries)),
    service.fetchCellarEntries().then((entries) => _syncCellarEntries(cellarRepo, entries)),
  ]);
});

/// Seed pizzas — insert only if UUID is not already present.
Future<void> _syncPizzas(PizzaRepository repo, List<Pizza> pizzas) async {
  for (final pizza in pizzas) {
    final existing = await repo.getPizzaByUuid(pizza.uuid);
    if (existing == null) await repo.savePizza(pizza);
  }
}

/// Seed sandwiches — insert only if UUID is not already present.
Future<void> _syncSandwiches(
    SandwichRepository repo, List<Sandwich> sandwiches) async {
  for (final sandwich in sandwiches) {
    final existing = await repo.getSandwichByUuid(sandwich.uuid);
    if (existing == null) await repo.saveSandwich(sandwich);
  }
}

/// Seed smoking recipes — insert only if UUID is not already present.
Future<void> _syncSmokingRecipes(
    SmokingRepository repo, List<SmokingRecipe> recipes) async {
  for (final recipe in recipes) {
    final existing = await repo.getRecipeByUuid(recipe.uuid);
    if (existing == null) await repo.saveRecipe(recipe);
  }
}

/// Seed modernist recipes — insert only if UUID is not already present.
Future<void> _syncModernistRecipes(
    ModernistRepository repo, List<ModernistRecipe> recipes) async {
  for (final recipe in recipes) {
    final existing = await repo.getByUuid(recipe.uuid);
    if (existing == null) await repo.save(recipe);
  }
}

/// Seed cheese entries — insert only if UUID is not already present.
Future<void> _syncCheeseEntries(
    CheeseRepository repo, List<CheeseEntry> entries) async {
  for (final entry in entries) {
    final existing = await repo.getEntryByUuid(entry.uuid);
    if (existing == null) await repo.saveEntry(entry);
  }
}

/// Seed cellar entries — insert only if UUID is not already present.
Future<void> _syncCellarEntries(
    CellarRepository repo, List<CellarEntry> entries) async {
  for (final entry in entries) {
    final existing = await repo.getEntryByUuid(entry.uuid);
    if (existing == null) await repo.saveEntry(entry);
  }
}

/// Sync state notifier for UI feedback
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final MemoixRecipeService _service;
  final RecipeRepository _recipeRepo;
  final PizzaRepository _pizzaRepo;
  final SandwichRepository _sandwichRepo;
  final SmokingRepository _smokingRepo;
  final ModernistRepository _modernistRepo;
  final CheeseRepository _cheeseRepo;
  final CellarRepository _cellarRepo;

  SyncNotifier(
    this._service,
    this._recipeRepo,
    this._pizzaRepo,
    this._sandwichRepo,
    this._smokingRepo,
    this._modernistRepo,
    this._cheeseRepo,
    this._cellarRepo,
  ) : super(const AsyncValue.data(null));

  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      // Sync all domains in parallel
      await Future.wait([
        _service.fetchAllRecipes().then((recipes) => _recipeRepo.syncMemoixRecipes(recipes)),
        _service.fetchPizzas().then((pizzas) => _syncPizzas(_pizzaRepo, pizzas)),
        _service.fetchSandwiches().then((sandwiches) => _syncSandwiches(_sandwichRepo, sandwiches)),
        _service.fetchSmokingRecipes().then((recipes) => _syncSmokingRecipes(_smokingRepo, recipes)),
        _service.fetchModernistRecipes().then((recipes) => _syncModernistRecipes(_modernistRepo, recipes)),
        _service.fetchCheeseEntries().then((entries) => _syncCheeseEntries(_cheeseRepo, entries)),
        _service.fetchCellarEntries().then((entries) => _syncCellarEntries(_cellarRepo, entries)),
      ]);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final syncNotifierProvider = StateNotifierProvider<SyncNotifier, AsyncValue<void>>((ref) {
  return SyncNotifier(
    ref.watch(MemoixRecipeServiceProvider),
    ref.watch(recipeRepositoryProvider),
    ref.watch(pizzaRepositoryProvider),
    ref.watch(sandwichRepositoryProvider),
    ref.watch(smokingRepositoryProvider),
    ref.watch(modernistRepositoryProvider),
    ref.watch(cheeseRepositoryProvider),
    ref.watch(cellarRepositoryProvider),
  );
});
