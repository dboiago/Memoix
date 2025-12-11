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

  // Kick off a background sync of the memoix recipes (non-blocking)
  Future(() async {
    try {
      final service = GitHubRecipeService();
      final repo = RecipeRepository(MemoixDatabase.instance);
      final recipes = await service.fetchAllRecipes();
      await repo.syncMemoixRecipes(recipes);
    } catch (e) {
      // Non-fatal; log for debugging
      print('Initial GitHub recipe sync failed: $e');
    }
  });

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}
