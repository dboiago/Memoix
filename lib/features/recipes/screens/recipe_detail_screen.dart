import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
import '../widgets/ingredient_list.dart';
import '../widgets/direction_list.dart';
import '../../sharing/services/share_service.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../settings/screens/settings_screen.dart';
import 'recipe_cooking_view.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the recipes stream to get live updates on favourite changes
    final recipesAsync = ref.watch(allRecipesProvider);

    return recipesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (recipes) {
        final recipe = recipes.firstWhere(
          (r) => r.uuid == recipeId,
          orElse: () => Recipe()..name = '',
        );
        
        if (recipe.name.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        return RecipeDetailView(recipe: recipe);
      },
    );
  }
}

class RecipeDetailView extends ConsumerWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cuisineColor = recipe.cuisine != null
        ? MemoixColors.forCuisine(recipe.cuisine!)
        : theme.colorScheme.primaryContainer;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeCookingView(recipe: recipe),
            ),
          );
        },
        icon: const Icon(Icons.restaurant),
        label: const Text('Start Cooking'),
      ),
      body: CustomScrollView(
        slivers: [
          // Hero header with recipe image or colored header
          SliverAppBar(
            expandedHeight: recipe.imageUrl != null ? 250 : 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                ),
              ),
              background: recipe.imageUrl != null
                  ? Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: cuisineColor),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cuisineColor,
                            MemoixColors.forCourse(recipe.course),
                          ],
                        ),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'I made this',
                onPressed: () async {
                  await ref.read(cookingStatsServiceProvider).logCook(
                    recipeId: recipe.uuid,
                    recipeName: recipe.name,
                    course: recipe.course,
                    cuisine: recipe.cuisine,
                  );
                  // Invalidate stats providers so they refresh
                  ref.invalidate(cookingStatsProvider);
                  ref.invalidate(recipeCookCountProvider(recipe.uuid));
                  ref.invalidate(recipeLastCookProvider(recipe.uuid));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logged cook for ${recipe.name}! 🎉'),
                        action: SnackBarAction(
                          label: 'Stats',
                          onPressed: () => AppRoutes.toStatistics(context),
                        ),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareRecipe(context, ref),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),

          // Recipe metadata
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (recipe.cuisine != null)
                        Chip(
                          label: Text(recipe.cuisine!),
                          backgroundColor: cuisineColor,
                          visualDensity: VisualDensity.compact,
                        ),
                      Chip(
                        label: Text(recipe.course),
                        backgroundColor: MemoixColors.forCourse(recipe.course),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (recipe.serves != null)
                        Chip(
                          avatar: const Icon(Icons.people, size: 16),
                          label: Text(recipe.serves!),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.time != null)
                        Chip(
                          avatar: const Icon(Icons.timer, size: 16),
                          label: Text(recipe.time!),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),

                  // Pairs with
                  if (recipe.pairsWith.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Pairs With',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: recipe.pairsWith
                          .map((p) => ActionChip(
                                label: Text(p),
                                onPressed: () {
                                  // Could navigate to paired recipe
                                },
                              ))
                          .toList(),
                    ),
                  ],

                  // Notes
                  if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Notes',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(recipe.notes!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Ingredients and Directions - split on wide screens
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use side-by-side layout on wide screens (>800px)
                if (constraints.maxWidth > 800) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ingredients on the left
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ingredients',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  IngredientList(ingredients: recipe.ingredients),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Directions on the right
                        Expanded(
                          flex: 3,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Directions',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DirectionList(directions: recipe.directions),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Stacked layout for narrow screens
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Ingredients',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      IngredientList(ingredients: recipe.ingredients),
                      const SizedBox(height: 24),
                      Text(
                        'Directions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DirectionList(directions: recipe.directions),
                    ],
                  ),
                );
              },
            ),
          ),

          // Source URL
          if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Original Recipe'),
                  onPressed: () async {
                    final url = Uri.tryParse(recipe.sourceUrl!);
                    if (url != null && await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  void _shareRecipe(BuildContext context, WidgetRef ref) {
    final shareService = ref.read(shareServiceProvider);
    shareService.shareRecipe(recipe);
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        AppRoutes.toRecipeEdit(context, recipeId: recipe.uuid);
        break;
      case 'duplicate':
        _duplicateRecipe(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _duplicateRecipe(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(recipeRepositoryProvider);
    final newRecipe = Recipe()
      ..uuid = ''  // Will be generated on save
      ..name = '${recipe.name} (Copy)'
      ..course = recipe.course
      ..cuisine = recipe.cuisine
      ..serves = recipe.serves
      ..time = recipe.time
      ..pairsWith = List.from(recipe.pairsWith)
      ..notes = recipe.notes
      ..ingredients = recipe.ingredients.map((i) => 
        Ingredient()
          ..name = i.name
          ..amount = i.amount
          ..unit = i.unit
          ..preparation = i.preparation
          ..alternative = i.alternative
          ..isOptional = i.isOptional
          ..section = i.section
      ).toList()
      ..directions = List.from(recipe.directions)
      ..source = RecipeSource.personal
      ..tags = List.from(recipe.tags);
    
    await repo.saveRecipe(newRecipe);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created copy: ${newRecipe.name}')),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
