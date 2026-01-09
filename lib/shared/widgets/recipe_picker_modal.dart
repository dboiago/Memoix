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

          // Combined recipe list (no tabs)
          Expanded(
            child: _buildAllRecipes(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildAllRecipes(ThemeData theme) {
    final recipesAsync = ref.watch(allRecipesProvider);
    final smokingAsync = ref.watch(allSmokingRecipesProvider);
    final modernistAsync = ref.watch(allModernistRecipesProvider);

    return recipesAsync.when(
      data: (standardRecipes) {
        return smokingAsync.when(
          data: (smokingRecipes) {
            return modernistAsync.when(
              data: (modernistRecipes) {
                // Combine all recipes into one list (after conversion)
                final allRecipes = <Recipe>[];
                
                // Add standard recipes (exclude Drinks - not comparable)
                for (final recipe in standardRecipes) {
                  // Skip Drinks course
                  if (recipe.course.toLowerCase() == 'drinks') continue;
                  
                  final matchesSearch = _searchQuery.isEmpty ||
                      recipe.name.toLowerCase().contains(_searchQuery) ||
                      (recipe.cuisine?.toLowerCase().contains(_searchQuery) ?? false);
                  final matchesCustom = widget.recipeFilter?.call(recipe) ?? true;
                  if (matchesSearch && matchesCustom) {
                    allRecipes.add(recipe);
                  }
                }
                
                // Convert and add smoking recipes (ONLY full recipes, not pit notes)
                for (final smoking in smokingRecipes) {
                  // Skip pit notes - only include full recipes
                  if (smoking.type != SmokingType.recipe) continue;
                  
                  if (_searchQuery.isEmpty ||
                      smoking.name.toLowerCase().contains(_searchQuery) ||
                      (smoking.item?.toLowerCase().contains(_searchQuery) ?? false)) {
                    allRecipes.add(_convertSmokingToRecipe(smoking));
                  }
                }
                
                // Convert and add modernist recipes (ONLY concepts, not techniques)
                for (final modernist in modernistRecipes) {
                  // Skip techniques - only include concepts
                  if (modernist.type != ModernistType.concept) continue;
                  
                  if (_searchQuery.isEmpty ||
                      modernist.name.toLowerCase().contains(_searchQuery) ||
                      (modernist.technique?.toLowerCase().contains(_searchQuery) ?? false)) {
                    allRecipes.add(_convertModernistToRecipe(modernist));
                  }
                }

                if (allRecipes.isEmpty) {
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
                for (final recipe in allRecipes) {
                  grouped.putIfAbsent(recipe.course, () => []).add(recipe);
                }

                // Define course order matching main screen (sortOrder from course.dart)
                const courseOrder = [
                  'Apps', 'Soups', 'Mains', 'Veg\'n', 'Sides', 'Salads', 
                  'Desserts', 'Brunch', 'Drinks', 'Breads', 'Sauces', 'Rubs', 'Pickles',
                  'Modernist', 'Pizzas', 'Sandwiches', 'Smoking', 'Cheese', 'Cellar', 'Scratch'
                ];

                // Sort courses by defined order
                final sortedCourses = grouped.keys.toList()..sort((a, b) {
                  final aIndex = courseOrder.indexOf(a);
                  final bIndex = courseOrder.indexOf(b);
                  if (aIndex == -1 && bIndex == -1) return a.compareTo(b);
                  if (aIndex == -1) return 1;
                  if (bIndex == -1) return -1;
                  return aIndex.compareTo(bIndex);
                });

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: sortedCourses.map((course) {
                    final recipes = grouped[course]!;
                    // Normalize course display name with proper capitalization
                    // Map lowercase course slugs to display names
                    final displayName = _getCoursDisplayName(course);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        ...recipes.map((recipe) => _RecipeListItem(
                              name: recipe.name,
                              subtitle: recipe.cuisine ?? recipe.course,
                              onTap: () => Navigator.pop(context, recipe),
                            )),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading modernist: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading smoking: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading recipes: $e')),
    );
  }

  /// Get proper display name for course (handles capitalization and special cases)
  String _getCoursDisplayName(String course) {
    // Map of course slugs/names to proper display names
    const courseDisplayNames = {
      'apps': 'Apps',
      'soup': 'Soups',
      'soups': 'Soups',
      'mains': 'Mains',
      'vegn': 'Veg\'n',
      'veg\'n': 'Veg\'n',
      'sides': 'Sides',
      'salad': 'Salads',
      'salads': 'Salads',
      'desserts': 'Desserts',
      'brunch': 'Brunch',
      'drinks': 'Drinks',
      'breads': 'Breads',
      'sauces': 'Sauces',
      'rubs': 'Rubs',
      'pickles': 'Pickles',
      'modernist': 'Modernist',
      'pizzas': 'Pizzas',
      'sandwiches': 'Sandwiches',
      'smoking': 'Smoking',
      'cheese': 'Cheese',
      'cellar': 'Cellar',
      'scratch': 'Scratch',
    };
    
    final lower = course.toLowerCase();
    return courseDisplayNames[lower] ?? course;
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
          ..name = smoking.item ?? 'Unknown Item'
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
