import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Specialized domain file names that need different parsing
const _specializedDomains = {
  'pizzas.json',
  'sandwiches.json',
  'smoking.json',
  'modernist.json',
  'cheese.json',
  'cellar.json',
  'scratch.json',
};

/// Service to fetch recipes from GitHub repository
class GitHubRecipeService {
  /// Base URL for raw GitHub content
  /// Update this to your actual repository
  static const String _baseUrl =
      'https://raw.githubusercontent.com/dboiago/Memoix/main/recipes';

  /// Fetch all standard recipes from GitHub (excludes specialized domains)
  Future<List<Recipe>> fetchAllRecipes() async {
    try {
      // First, fetch the index to know what files to load
      final indexResponse = await http.get(Uri.parse('$_baseUrl/index.json'));
      
      if (indexResponse.statusCode != 200) {
        throw Exception('Failed to fetch recipe index: ${indexResponse.statusCode}');
      }

      final index = jsonDecode(indexResponse.body) as Map<String, dynamic>;
      final files = (index['files'] as List<dynamic>).cast<String>();
      
      // Filter out specialized domains - they have different models
      final recipeFiles = files.where((f) => !_specializedDomains.contains(f)).toList();

      // Fetch all recipe files in parallel
      final futures = recipeFiles.map((file) => _fetchRecipeFile(file));
      final results = await Future.wait(futures);

      // Flatten all recipes into a single list
      return results.expand((list) => list).toList();
    } catch (e) {
      throw Exception('Failed to sync recipes from GitHub: $e');
    }
  }

  /// Fetch a single recipe file
  Future<List<Recipe>> _fetchRecipeFile(String filename) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$filename'));
      
      if (response.statusCode != 200) {
        print('Warning: Failed to fetch $filename');
        return [];
      }

      final data = jsonDecode(response.body);
      
      List<Recipe> recipes = [];
      if (data is List) {
        recipes = data
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>)
              ..source = RecipeSource.memoix,)
            .toList();
      } else if (data is Map<String, dynamic>) {
        recipes = [Recipe.fromJson(data)..source = RecipeSource.memoix];
      }

      // Filter out placeholder/template recipes
      return recipes.where((r) => 
        r.name.isNotEmpty && 
        r.name.toLowerCase() != 'name' &&
        !r.name.toLowerCase().startsWith('template'),
      ).toList();
    } catch (e) {
      print('Error fetching $filename: $e');
      return [];
    }
  }

  /// Fetch pizzas from GitHub
  Future<List<Pizza>> fetchPizzas() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/pizzas.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Pizza.fromJson(e as Map<String, dynamic>)
            ..source = PizzaSource.memoix)
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching pizzas.json: $e');
      return [];
    }
  }

  /// Fetch sandwiches from GitHub
  Future<List<Sandwich>> fetchSandwiches() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/sandwiches.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Sandwich.fromJson(e as Map<String, dynamic>)
            ..source = SandwichSource.memoix)
          .where((s) => s.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching sandwiches.json: $e');
      return [];
    }
  }

  /// Fetch smoking recipes from GitHub
  Future<List<SmokingRecipe>> fetchSmokingRecipes() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/smoking.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => SmokingRecipe.fromJson(e as Map<String, dynamic>)
            ..source = SmokingSource.memoix)
          .where((s) => s.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching smoking.json: $e');
      return [];
    }
  }

  /// Fetch modernist recipes from GitHub
  Future<List<ModernistRecipe>> fetchModernistRecipes() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/modernist.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => ModernistRecipe.fromJson(e as Map<String, dynamic>)
            ..source = ModernistSource.memoix)
          .where((m) => m.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching modernist.json: $e');
      return [];
    }
  }

  /// Fetch cheese entries from GitHub
  Future<List<CheeseEntry>> fetchCheeseEntries() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/cheese.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => CheeseEntry.fromJson(e as Map<String, dynamic>)
            ..source = CheeseSource.memoix)
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching cheese.json: $e');
      return [];
    }
  }

  /// Fetch cellar entries from GitHub
  Future<List<CellarEntry>> fetchCellarEntries() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/cellar.json'));
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => CellarEntry.fromJson(e as Map<String, dynamic>)
            ..source = CellarSource.memoix)
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching cellar.json: $e');
      return [];
    }
  }

  /// Fetch recipes for a specific course
  Future<List<Recipe>> fetchRecipesForCourse(String course) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/${course.toLowerCase()}.json'),
      );
      
      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>)
            ..source = RecipeSource.memoix,)
          .toList();
    } catch (e) {
      print('Error fetching $course recipes: $e');
      return [];
    }
  }

  /// Check if there are updates available
  Future<bool> checkForUpdates(int currentVersion) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/version.json'));
      
      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as int? ?? 0;
      
      return latestVersion > currentVersion;
    } catch (e) {
      return false;
    }
  }
}

// ============ PROVIDERS ============

final githubRecipeServiceProvider = Provider<GitHubRecipeService>((ref) {
  return GitHubRecipeService();
});

/// Provider to sync all data from GitHub (recipes + specialized domains)
final syncRecipesProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(githubRecipeServiceProvider);
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

/// Sync pizzas - upsert by UUID
Future<void> _syncPizzas(PizzaRepository repo, List<Pizza> pizzas) async {
  for (final pizza in pizzas) {
    final existing = await repo.getPizzaByUuid(pizza.uuid);
    if (existing != null) {
      pizza.id = existing.id;
    }
    await repo.savePizza(pizza);
  }
}

/// Sync sandwiches - upsert by UUID
Future<void> _syncSandwiches(SandwichRepository repo, List<Sandwich> sandwiches) async {
  for (final sandwich in sandwiches) {
    final existing = await repo.getSandwichByUuid(sandwich.uuid);
    if (existing != null) {
      sandwich.id = existing.id;
    }
    await repo.saveSandwich(sandwich);
  }
}

/// Sync smoking recipes - upsert by UUID
Future<void> _syncSmokingRecipes(SmokingRepository repo, List<SmokingRecipe> recipes) async {
  for (final recipe in recipes) {
    final existing = await repo.getRecipeByUuid(recipe.uuid);
    if (existing != null) {
      recipe.id = existing.id;
    }
    await repo.saveRecipe(recipe);
  }
}

/// Sync modernist recipes - upsert by UUID
Future<void> _syncModernistRecipes(ModernistRepository repo, List<ModernistRecipe> recipes) async {
  for (final recipe in recipes) {
    final existing = await repo.getByUuid(recipe.uuid);
    if (existing != null) {
      recipe.id = existing.id;
    }
    await repo.save(recipe);
  }
}

/// Sync cheese entries - upsert by UUID
Future<void> _syncCheeseEntries(CheeseRepository repo, List<CheeseEntry> entries) async {
  for (final entry in entries) {
    final existing = await repo.getEntryByUuid(entry.uuid);
    if (existing != null) {
      entry.id = existing.id;
    }
    await repo.saveEntry(entry);
  }
}

/// Sync cellar entries - upsert by UUID
Future<void> _syncCellarEntries(CellarRepository repo, List<CellarEntry> entries) async {
  for (final entry in entries) {
    final existing = await repo.getEntryByUuid(entry.uuid);
    if (existing != null) {
      entry.id = existing.id;
    }
    await repo.saveEntry(entry);
  }
}

/// Sync state notifier for UI feedback
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final GitHubRecipeService _service;
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
    ref.watch(githubRecipeServiceProvider),
    ref.watch(recipeRepositoryProvider),
    ref.watch(pizzaRepositoryProvider),
    ref.watch(sandwichRepositoryProvider),
    ref.watch(smokingRepositoryProvider),
    ref.watch(modernistRepositoryProvider),
    ref.watch(cheeseRepositoryProvider),
    ref.watch(cellarRepositoryProvider),
  );
});
