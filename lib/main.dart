import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/services/github_recipe_service.dart';
import 'features/recipes/repository/recipe_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await MemoixDatabase.initialize();

  // Perform an initial sync with a short timeout so recipes show on first run.
  try {
    final service = GitHubRecipeService();
    final repo = RecipeRepository(MemoixDatabase.instance);
    final recipes = await service.fetchAllRecipes().timeout(const Duration(seconds: 20));
    await repo.syncMemoixRecipes(recipes);
    print('Initial GitHub recipe sync completed: ${recipes.length} recipes');
  } catch (e) {
    print('Initial GitHub recipe sync failed or timed out: $e');
  }

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}
