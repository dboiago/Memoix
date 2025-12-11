import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../models/recipe.dart';
import '../models/continent_mapping.dart';
import '../models/source_filter.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card.dart';

/// Recipe list screen matching Figma design
class RecipeListScreen extends ConsumerStatefulWidget {
  final String course;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;
  final bool showAddButton;

  const RecipeListScreen({
    super.key,
    required this.course,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
    this.showAddButton = false,
  });

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String _selectedCuisine = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(
      recipesByCourseProvider(widget.course),
    );

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (allRecipes) {
          // Apply source filter first
          final recipes = _filterBySource(allRecipes);
          
          // Get cuisines that actually exist in this recipe set
          final availableCuisines = _getAvailableCuisines(recipes);
          
          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),

              // Cuisine filter chips (show if any cuisines exist)
              if (availableCuisines.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCuisineChip('All', recipes.length),
                      ...availableCuisines.map((cuisine) {
                        final count = recipes.where((r) => r.cuisine?.toLowerCase() == cuisine.toLowerCase()).length;
                        return _buildCuisineChip(_displayCuisine(cuisine), count, rawValue: cuisine);
                      }),
                    ],
                  ),
                ),

              // Recipe list
              Expanded(
                child: _buildRecipeList(recipes),
              ),
            ],
          );
      },
    );
  }

  Widget _buildCuisineChip(String cuisineLabel, int count, {String? rawValue}) {
    final value = rawValue ?? cuisineLabel;
    final isSelected = _selectedCuisine == value;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(cuisineLabel),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCuisine = value);
        },
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.secondaryContainer,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected 
              ? theme.colorScheme.onSecondaryContainer 
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<String> _getAvailableCuisines(List<Recipe> recipes) {
    final cuisines = recipes
        .map((r) => r.cuisine)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    cuisines.sort();
    return cuisines;
  }

  String _displayCuisine(String raw) {
    const map = {
      'Korea': 'Korean',
      'Korean': 'Korean',
      'China': 'Chinese',
      'Chinese': 'Chinese',
      'Japan': 'Japanese',
      'Japanese': 'Japanese',
      'Spain': 'Spanish',
      'France': 'French',
      'Italy': 'Italian',
      'Mexico': 'Mexican',
      'Mexican': 'Mexican',
      'United States': 'American',
      'North American': 'North American',
    };
    return map[raw] ?? raw;
  }

  Widget _buildRecipeList(List<Recipe> allRecipes) {
    // Apply filters
    var filteredRecipes = _filterRecipes(allRecipes);

    if (filteredRecipes.isEmpty) {
      return _buildEmptyState();
    }

    // Simple list without grouping for cleaner UI
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        return RecipeCard(
          recipe: filteredRecipes[index],
          onTap: () => AppRoutes.toRecipeDetail(context, filteredRecipes[index].uuid),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
            widget.emptyMessage ?? 'No recipes found',
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

  List<Recipe> _filterBySource(List<Recipe> recipes) {
    switch (widget.sourceFilter) {
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

  List<Recipe> _filterRecipes(List<Recipe> recipes) {
    var filtered = recipes;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            (r.cuisine?.toLowerCase().contains(_searchQuery) ?? false) ||
            (r.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)));
      }).toList();
    }

    // Filter by cuisine
    if (_selectedCuisine != 'All') {
      filtered = filtered.where((r) {
        return r.cuisine?.toLowerCase() == _selectedCuisine.toLowerCase();
      }).toList();
    }

    return filtered;
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
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toRecipeEdit(context, course: widget.course);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan from Photo'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toOCRScanner(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              onTap: () {
                Navigator.pop(ctx);
                AppRoutes.toURLImport(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
