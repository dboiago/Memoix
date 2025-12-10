import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card.dart';
import '../../home/screens/home_screen.dart';

/// Screen showing recipes for a specific course/category
class RecipeListScreen extends ConsumerWidget {
  final String course;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;

  const RecipeListScreen({
    super.key,
    required this.course,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesByCourseProvider(course));

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading recipes: $err')),
      data: (allRecipes) {
        // Filter by source if needed
        final recipes = _filterBySource(allRecipes);

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage ?? 'No recipes in this category',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RecipeListView(recipes: recipes);
      },
    );
  }

  List<Recipe> _filterBySource(List<Recipe> recipes) {
    switch (sourceFilter) {
      case RecipeSourceFilter.memoix:
        return recipes.where((r) => r.source == RecipeSource.memoix).toList();
      case RecipeSourceFilter.personal:
        return recipes
            .where((r) =>
                r.source == RecipeSource.personal ||
                r.source == RecipeSource.imported ||
                r.source == RecipeSource.ocr ||
                r.source == RecipeSource.url)
            .toList();
      case RecipeSourceFilter.all:
        return recipes;
    }
  }
}

/// Reusable list view for recipes
class RecipeListView extends StatelessWidget {
  final List<Recipe> recipes;

  const RecipeListView({super.key, required this.recipes});

  @override
  Widget build(BuildContext context) {
    // Group recipes by cuisine
    final grouped = _groupByCuisine(recipes);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final cuisine = entry.key;
        final cuisineRecipes = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cuisine header (like "Korean", "French" in spreadsheet)
            if (cuisine.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(top: 8),
                color: MemoixColors.forCuisine(cuisine),
                child: Text(
                  cuisine,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            // Recipe cards
            ...cuisineRecipes.map((recipe) => RecipeCard(
                  recipe: recipe,
                  onTap: () => AppRoutes.toRecipeDetail(context, recipe.uuid),
                )),
          ],
        );
      },
    );
  }

  Map<String, List<Recipe>> _groupByCuisine(List<Recipe> recipes) {
    final Map<String, List<Recipe>> grouped = {};

    for (final recipe in recipes) {
      final cuisine = recipe.cuisine ?? '';
      grouped.putIfAbsent(cuisine, () => []);
      grouped[cuisine]!.add(recipe);
    }

    // Sort cuisines alphabetically, but put empty cuisine last
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          if (a.key.isEmpty) return 1;
          if (b.key.isEmpty) return -1;
          return a.key.compareTo(b.key);
        }),
    );

    return sorted;
  }
}
