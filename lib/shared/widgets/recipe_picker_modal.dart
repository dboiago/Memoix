import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/repository/recipe_repository.dart';
import '../../features/smoking/models/smoking_recipe.dart';
import '../../features/smoking/repository/smoking_repository.dart';
import '../../features/modernist/models/modernist_recipe.dart';
import '../../features/modernist/repository/modernist_repository.dart';

/// Modal bottom sheet for picking a recipe from the database
/// 
/// Supports standard recipes, smoking recipes, and modernist concepts
/// Used by the Recipe Comparison tool and other features
class RecipePickerModal extends ConsumerStatefulWidget {
  /// Title shown at the top of the picker
  final String title;
  
  /// Optional filter to restrict which courses/types are shown
  final bool Function(Recipe)? recipeFilter;

  const RecipePickerModal({
    super.key,
    this.title = 'Select Recipe',
    this.recipeFilter,
  });

  @override
  ConsumerState<RecipePickerModal> createState() => _RecipePickerModalState();
}

class _RecipePickerModalState extends ConsumerState<RecipePickerModal> {
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = Recipes, 1 = Smoking, 2 = Modernist

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Tab selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Recipes')),
                      ButtonSegment(value: 1, label: Text('Smoking')),
                      ButtonSegment(value: 2, label: Text('Modernist')),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (Set<int> selection) {
                      setState(() => _selectedTab = selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recipe list
          Expanded(
            child: _buildRecipeList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(ThemeData theme) {
    switch (_selectedTab) {
      case 0:
        return _buildStandardRecipes(theme);
      case 1:
        return _buildSmokingRecipes(theme);
      case 2:
        return _buildModernistRecipes(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStandardRecipes(ThemeData theme) {
    final recipesAsync = ref.watch(allRecipesProvider);

    return recipesAsync.when(
      data: (recipes) {
        // Apply search filter
        var filtered = recipes.where((recipe) {
          final matchesSearch = _searchQuery.isEmpty ||
              recipe.name.toLowerCase().contains(_searchQuery) ||
              (recipe.cuisine?.toLowerCase().contains(_searchQuery) ?? false);
          
          // Apply custom filter if provided
          final matchesCustom = widget.recipeFilter?.call(recipe) ?? true;
          
          return matchesSearch && matchesCustom;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty ? 'No recipes found' : 'No matching recipes',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        // Group by course
        final grouped = <String, List<Recipe>>{};
        for (final recipe in filtered) {
          grouped.putIfAbsent(recipe.course, () => []).add(recipe);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ...entry.value.map((recipe) => _RecipeListItem(
                      name: recipe.name,
                      subtitle: recipe.cuisine ?? '',
                      onTap: () => Navigator.pop(context, recipe),
                    )),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSmokingRecipes(ThemeData theme) {
    final recipesAsync = ref.watch(allSmokingRecipesProvider);

    return recipesAsync.when(
      data: (recipes) {
        var filtered = recipes.where((recipe) {
          return _searchQuery.isEmpty ||
              recipe.name.toLowerCase().contains(_searchQuery) ||
              (recipe.item.toLowerCase().contains(_searchQuery));
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty ? 'No smoking recipes found' : 'No matching recipes',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: filtered.map((recipe) => _RecipeListItem(
                name: recipe.name,
                subtitle: '${recipe.item} • ${recipe.time}',
                onTap: () {
                  // Convert to standard Recipe for comparison
                  final standardRecipe = _convertSmokingToRecipe(recipe);
                  Navigator.pop(context, standardRecipe);
                },
              )).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildModernistRecipes(ThemeData theme) {
    final recipesAsync = ref.watch(allModernistRecipesProvider);

    return recipesAsync.when(
      data: (recipes) {
        var filtered = recipes.where((recipe) {
          return _searchQuery.isEmpty ||
              recipe.name.toLowerCase().contains(_searchQuery) ||
              (recipe.technique?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty ? 'No modernist concepts found' : 'No matching concepts',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: filtered.map((recipe) => _RecipeListItem(
                name: recipe.name,
                subtitle: recipe.technique ?? recipe.type.name,
                onTap: () {
                  // Convert to standard Recipe for comparison
                  final standardRecipe = _convertModernistToRecipe(recipe);
                  Navigator.pop(context, standardRecipe);
                },
              )).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  /// Convert SmokingRecipe to standard Recipe format
  Recipe _convertSmokingToRecipe(SmokingRecipe smoking) {
    return Recipe()
      ..uuid = smoking.uuid
      ..name = smoking.name
      ..course = 'Smoking'
      ..time = smoking.time
      ..ingredients = [
        Ingredient()
          ..name = smoking.item
          ..amount = ''
          ..unit = ''
      ]
      ..directions = smoking.directions.isNotEmpty
          ? smoking.directions
          : ['Smoke at ${smoking.temperature}°F for ${smoking.time}']
      ..comments = smoking.notes;
  }

  /// Convert ModernistRecipe to standard Recipe format
  Recipe _convertModernistToRecipe(ModernistRecipe modernist) {
    return Recipe()
      ..uuid = modernist.uuid
      ..name = modernist.name
      ..course = 'Modernist'
      ..serves = modernist.serves
      ..time = modernist.time
      ..ingredients = modernist.ingredients.map((i) => Ingredient()
        ..name = i.name
        ..amount = i.amount
        ..unit = i.unit
        ..preparation = i.notes
        ..section = i.section
      ).toList()
      ..directions = modernist.directions
      ..comments = modernist.notes;
  }
}

/// Simple recipe list item
class _RecipeListItem extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _RecipeListItem({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
