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
      final results = <Recipe>[];
      for (final e in list.whereType<Map<String, dynamic>>()) {
        try {
          final r = Recipe.fromJson(e)..source = RecipeSource.memoix;
          if (r.name.isNotEmpty) results.add(r);
        } catch (parseError) {
          debugPrint('MemoixRecipeService._loadRecipeFile($filename): skipping record: $parseError');
        }
      }
      return results;
    } catch (e) {
      debugPrint('MemoixRecipeService._loadRecipeFile($filename): $e');
      return [];
    }
  }

  Future<List<Pizza>> fetchPizzas() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/pizzas.json');
      final data = jsonDecode(raw) as List<dynamic>;
      final results = <Pizza>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final p = pizzaFromJson(e).copyWith(source: PizzaSource.memoix.name);
          if (p.name.isNotEmpty) results.add(p);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchPizzas: skipping record: $parseError');
        }
      }
      return results;
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
      final results = <Sandwich>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final s = sandwichFromJson(e).copyWith(source: SandwichSource.memoix.name);
          if (s.name.isNotEmpty) results.add(s);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchSandwiches: skipping record: $parseError');
        }
      }
      return results;
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchSandwiches: $e');
      return [];
    }
  }

  Future<List<SmokingRecipe>> fetchSmokingRecipes() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/smoking.json');
      final data = jsonDecode(raw) as List<dynamic>;
      final results = <SmokingRecipe>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final s = smokingRecipeFromJson(e).copyWith(source: SmokingSource.memoix.name);
          if (s.name.isNotEmpty) results.add(s);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchSmokingRecipes: skipping record: $parseError');
        }
      }
      return results;
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
      final results = <ModernistRecipe>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final m = ModernistRecipe.fromJson(e)..source = ModernistSource.memoix;
          if (m.name.isNotEmpty) results.add(m);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchModernistRecipes: skipping record: $parseError');
        }
      }
      return results;
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchModernistRecipes: $e');
      return [];
    }
  }

  Future<List<CheeseEntry>> fetchCheeseEntries() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/cheese.json');
      final data = jsonDecode(raw) as List<dynamic>;
      final results = <CheeseEntry>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final c = cheeseEntryFromJson(e).copyWith(source: CheeseSource.memoix.name);
          if (c.name.isNotEmpty) results.add(c);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchCheeseEntries: skipping record: $parseError');
        }
      }
      return results;
    } catch (e) {
      debugPrint('MemoixRecipeService.fetchCheeseEntries: $e');
      return [];
    }
  }

  Future<List<CellarEntry>> fetchCellarEntries() async {
    try {
      final raw = await rootBundle.loadString('assets/recipes/cellar.json');
      final data = jsonDecode(raw) as List<dynamic>;
      final results = <CellarEntry>[];
      for (final e in data.whereType<Map<String, dynamic>>()) {
        try {
          final c = cellarEntryFromJson(e).copyWith(source: CellarSource.memoix.name);
          if (c.name.isNotEmpty) results.add(c);
        } catch (parseError) {
          debugPrint('MemoixRecipeService.fetchCellarEntries: skipping record: $parseError');
        }
      }
      return results;
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

/// Provider to sync all data (recipes + specialized domains).
/// Delegates to [syncNotifierProvider] so the parallel execution logic
/// lives in a single place ([SyncNotifier.sync]).
final syncRecipesProvider = FutureProvider<void>((ref) async {
  await ref.read(syncNotifierProvider.notifier).sync();
});

/// Seed pizzas — insert only if UUID is not already present.
Future<void> _syncPizzas(PizzaRepository repo, List<Pizza> pizzas) async {
  for (final pizza in pizzas) {
    try {
      final existing = await repo.getPizzaByUuid(pizza.uuid);
      if (existing == null) await repo.savePizza(pizza);
    } catch (e) {
      debugPrint('_syncPizzas: skipping ${pizza.uuid}: $e');
    }
  }
}

/// Seed sandwiches — insert only if UUID is not already present.
Future<void> _syncSandwiches(
    SandwichRepository repo, List<Sandwich> sandwiches) async {
  for (final sandwich in sandwiches) {
    try {
      final existing = await repo.getSandwichByUuid(sandwich.uuid);
      if (existing == null) await repo.saveSandwich(sandwich);
    } catch (e) {
      debugPrint('_syncSandwiches: skipping ${sandwich.uuid}: $e');
    }
  }
}

/// Seed smoking recipes — insert only if UUID is not already present.
Future<void> _syncSmokingRecipes(
    SmokingRepository repo, List<SmokingRecipe> recipes) async {
  for (final recipe in recipes) {
    try {
      final existing = await repo.getRecipeByUuid(recipe.uuid);
      if (existing == null) await repo.saveRecipe(recipe);
    } catch (e) {
      debugPrint('_syncSmokingRecipes: skipping ${recipe.uuid}: $e');
    }
  }
}

/// Seed modernist recipes — insert only if UUID is not already present.
Future<void> _syncModernistRecipes(
    ModernistRepository repo, List<ModernistRecipe> recipes) async {
  for (final recipe in recipes) {
    try {
      final existing = await repo.getByUuid(recipe.uuid);
      if (existing == null) await repo.save(recipe);
    } catch (e) {
      debugPrint('_syncModernistRecipes: skipping ${recipe.uuid}: $e');
    }
  }
}

/// Seed cheese entries — insert only if UUID is not already present.
Future<void> _syncCheeseEntries(
    CheeseRepository repo, List<CheeseEntry> entries) async {
  for (final entry in entries) {
    try {
      final existing = await repo.getEntryByUuid(entry.uuid);
      if (existing == null) await repo.saveEntry(entry);
    } catch (e) {
      debugPrint('_syncCheeseEntries: skipping ${entry.uuid}: $e');
    }
  }
}

/// Seed cellar entries — insert only if UUID is not already present.
Future<void> _syncCellarEntries(
    CellarRepository repo, List<CellarEntry> entries) async {
  for (final entry in entries) {
    try {
      final existing = await repo.getEntryByUuid(entry.uuid);
      if (existing == null) await repo.saveEntry(entry);
    } catch (e) {
      debugPrint('_syncCellarEntries: skipping ${entry.uuid}: $e');
    }
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
