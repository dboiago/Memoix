import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/repository/recipe_repository.dart';

/// Service to fetch recipes from GitHub repository
class GitHubRecipeService {
  /// Base URL for raw GitHub content
  /// Update this to your actual repository
  static const String _baseUrl =
      'https://raw.githubusercontent.com/dboiago/Memoix/main/recipes';

  /// Fetch all recipes from GitHub
  Future<List<Recipe>> fetchAllRecipes() async {
    try {
      // First, fetch the index to know what files to load
      final indexResponse = await http.get(Uri.parse('$_baseUrl/index.json'));
      
      if (indexResponse.statusCode != 200) {
        throw Exception('Failed to fetch recipe index: ${indexResponse.statusCode}');
      }

      final index = jsonDecode(indexResponse.body) as Map<String, dynamic>;
      final files = (index['files'] as List<dynamic>).cast<String>();

      // Fetch all recipe files in parallel
      final futures = files.map((file) => _fetchRecipeFile(file));
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

/// Provider to sync recipes from GitHub
final syncRecipesProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(githubRecipeServiceProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  
  final recipes = await service.fetchAllRecipes();
  await repository.syncMemoixRecipes(recipes);
});

/// Sync state notifier for UI feedback
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final GitHubRecipeService _service;
  final RecipeRepository _repository;

  SyncNotifier(this._service, this._repository) : super(const AsyncValue.data(null));

  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      final recipes = await _service.fetchAllRecipes();
      await _repository.syncMemoixRecipes(recipes);
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
  );
});
