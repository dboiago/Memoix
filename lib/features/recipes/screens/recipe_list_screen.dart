import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card.dart';

enum RecipeSourceFilter { memoix, personal, all }

/// Screen showing recipes for a specific course/category
class RecipeListScreen extends ConsumerWidget {
  final String course;
  final RecipeSourceFilter sourceFilter;
  final String? cuisineFilter;
  final String? emptyMessage;
  final bool showAddButton;

  const RecipeListScreen({
    super.key,
    required this.course,
    this.sourceFilter = RecipeSourceFilter.all,
    this.cuisineFilter,
    this.emptyMessage,
    this.showAddButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesByCourseProvider(course));

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading recipes: $err')),
      data: (allRecipes) {
        // Filter by source and cuisine
        var recipes = _filterBySource(allRecipes);
        if (cuisineFilter != null) {
          recipes = recipes.where((r) => r.cuisine == cuisineFilter).toList();
        }

        if (recipes.isEmpty) {
          return Stack(
            children: [
              Center(
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
                      emptyMessage ?? _getEmptyMessage(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showAddButton) _buildAddButton(context),
            ],
          );
        }

        return Stack(
          children: [
            RecipeListView(recipes: recipes, showCuisineHeaders: cuisineFilter == null),
            if (showAddButton) _buildAddButton(context),
          ],
        );
      },
    );
  }

  String _getEmptyMessage() {
    if (cuisineFilter != null) {
      final cuisine = Cuisine.byCode(cuisineFilter!);
      return 'No ${cuisine?.name ?? cuisineFilter} recipes in $course';
    }
    return 'No recipes in this category';
  }

  Widget _buildAddButton(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Create New Recipe'),
              subtitle: const Text('Write a recipe from scratch'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toRecipeEdit(context, course: course);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan from Photo'),
              subtitle: const Text('Use OCR to extract from cookbook or notes'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toOCRScanner(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              subtitle: const Text('Paste a link from a recipe website'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toURLImport(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Import a shared recipe'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toQRScanner(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
  final bool showCuisineHeaders;

  const RecipeListView({
    super.key,
    required this.recipes,
    this.showCuisineHeaders = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCuisineHeaders) {
      // Simple grid without grouping
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          return RecipeCard(
            recipe: recipes[index],
            onTap: () => AppRoutes.toRecipeDetail(context, recipes[index].uuid),
          );
        },
      );
    }

    // Group recipes by cuisine
    final grouped = _groupByCuisine(recipes);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final cuisineCode = entry.key;
        final cuisineRecipes = entry.value;
        final cuisine = Cuisine.byCode(cuisineCode);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cuisine header with flag
            if (cuisineCode.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(top: 8),
                color: cuisine?.colour.withOpacity(0.2) ?? 
                       MemoixColors.forCuisine(cuisineCode),
                child: Row(
                  children: [
                    if (cuisine != null) ...[
                      Text(cuisine.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      cuisine?.name ?? cuisineCode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cuisine?.colour ?? Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${cuisineRecipes.length} recipe${cuisineRecipes.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
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
