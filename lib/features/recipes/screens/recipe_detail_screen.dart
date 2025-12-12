import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers.dart';
import '../models/cuisine.dart';
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
    // Enable wakelock if setting is on
    final keepScreenOn = ref.watch(keepScreenOnProvider);
    if (keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    
    final theme = Theme.of(context);

    return Scaffold(
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
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? theme.colorScheme.primary : null,
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
                        content: Text('Logged cook for ${recipe.name}!'),
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
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
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
                          label: Text(Cuisine.toAdjective(recipe.cuisine)),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      Chip(
                        label: Text(recipe.course),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (recipe.serves != null)
                        Chip(
                          avatar: Icon(Icons.people, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.serves!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.time != null)
                        Chip(
                          avatar: Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurface),
                          label: Text(recipe.time!),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (recipe.nutrition != null && recipe.nutrition!.hasData)
                        Tooltip(
                          message: _buildNutritionTooltip(recipe.nutrition!),
                          child: ActionChip(
                            avatar: Icon(Icons.local_fire_department, size: 16, color: theme.colorScheme.onSurface),
                            label: Text(recipe.nutrition!.compactDisplay ?? 'Nutrition'),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showNutritionDialog(context, recipe.nutrition!),
                          ),
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
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                                onPressed: () => _navigateToPairedRecipe(context, ref, p),
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
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Share "${recipe.name}"',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.qr_code, color: theme.colorScheme.primary),
              title: const Text('Show QR Code'),
              subtitle: const Text('Others can scan to import'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.showQrCode(context, recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.primary),
              title: const Text('Share Link'),
              subtitle: const Text('Send via any app'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareRecipe(recipe);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy, color: theme.colorScheme.primary),
              title: const Text('Copy Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await shareService.copyShareLink(recipe);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard!')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.text_snippet, color: theme.colorScheme.primary),
              title: const Text('Share as Text'),
              subtitle: const Text('Full recipe in plain text'),
              onTap: () {
                Navigator.pop(ctx);
                shareService.shareAsText(recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigateToPairedRecipe(BuildContext context, WidgetRef ref, String pairName) async {
    final recipes = ref.read(allRecipesProvider).valueOrNull ?? [];
    
    // Search for a recipe with matching name (case-insensitive, partial match)
    final searchLower = pairName.toLowerCase().trim();
    final match = recipes.firstWhere(
      (r) => r.name.toLowerCase() == searchLower ||
             r.name.toLowerCase().contains(searchLower) ||
             searchLower.contains(r.name.toLowerCase()),
      orElse: () => Recipe()..name = '',
    );
    
    if (match.name.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: match.uuid),
        ),
      );
    } else {
      // No match found - offer to search
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe "$pairName" not found'),
          action: SnackBarAction(
            label: 'Search',
            onPressed: () {
              // Could open search with the term
            },
          ),
        ),
      );
    }
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.secondary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _buildNutritionTooltip(NutritionInfo nutrition) {
    final parts = <String>[];
    if (nutrition.calories != null) parts.add('${nutrition.calories} cal');
    if (nutrition.proteinContent != null) parts.add('${nutrition.proteinContent}g protein');
    if (nutrition.carbohydrateContent != null) parts.add('${nutrition.carbohydrateContent}g carbs');
    if (nutrition.fatContent != null) parts.add('${nutrition.fatContent}g fat');
    return parts.join(' • ');
  }

  void _showNutritionDialog(BuildContext context, NutritionInfo nutrition) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            const Text('Nutrition Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nutrition.servingSize != null)
              _nutritionRow('Serving Size', nutrition.servingSize!),
            if (nutrition.calories != null)
              _nutritionRow('Calories', '${nutrition.calories}'),
            if (nutrition.proteinContent != null)
              _nutritionRow('Protein', '${nutrition.proteinContent}g'),
            if (nutrition.carbohydrateContent != null)
              _nutritionRow('Carbohydrates', '${nutrition.carbohydrateContent}g'),
            if (nutrition.fiberContent != null)
              _nutritionRow('Fiber', '${nutrition.fiberContent}g'),
            if (nutrition.sugarContent != null)
              _nutritionRow('Sugar', '${nutrition.sugarContent}g'),
            if (nutrition.fatContent != null)
              _nutritionRow('Total Fat', '${nutrition.fatContent}g'),
            if (nutrition.saturatedFatContent != null)
              _nutritionRow('Saturated Fat', '${nutrition.saturatedFatContent}g'),
            if (nutrition.cholesterolContent != null)
              _nutritionRow('Cholesterol', '${nutrition.cholesterolContent}mg'),
            if (nutrition.sodiumContent != null)
              _nutritionRow('Sodium', '${nutrition.sodiumContent}mg'),
            const SizedBox(height: 16),
            Text(
              'Note: Nutrition information is estimated and may vary based on ingredients and preparation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
