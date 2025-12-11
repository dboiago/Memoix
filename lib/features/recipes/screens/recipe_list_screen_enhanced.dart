import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../models/recipe.dart';
import '../models/continent_mapping.dart';
import '../models/source_filter.dart';
import '../repository/recipe_repository.dart';
import '../widgets/recipe_card_enhanced.dart';

/// Enhanced recipe list screen with continent filters matching Figma design
class RecipeListScreenEnhanced extends ConsumerStatefulWidget {
  final String course;
  final RecipeSourceFilter sourceFilter;
  final String? emptyMessage;
  final bool showAddButton;

  const RecipeListScreenEnhanced({
    super.key,
    required this.course,
    this.sourceFilter = RecipeSourceFilter.all,
    this.emptyMessage,
    this.showAddButton = false,
  });

  @override
  ConsumerState<RecipeListScreenEnhanced> createState() => _RecipeListScreenEnhancedState();
}

class _RecipeListScreenEnhancedState extends ConsumerState<RecipeListScreenEnhanced>
    with SingleTickerProviderStateMixin {
  late TabController _continentTabController;
  String _selectedContinent = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _continentTabController = TabController(
      length: ContinentMapping.allContinents.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _continentTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipesAsync = ref.watch(
      recipesByCourseProvider(widget.course),
    );

    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Continent filter tabs
          TabBar(
            controller: _continentTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) {
              setState(() {
                _selectedContinent = ContinentMapping.allContinents[index];
              });
            },
            tabs: ContinentMapping.allContinents.map((continent) {
              return Tab(text: continent);
            }).toList(),
          ),

          // Recipe list
          Expanded(
            child: recipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (recipes) {
                // Apply source filter
                var filteredRecipes = _filterBySource(recipes);
                // Apply other filters
                filteredRecipes = _filterRecipes(filteredRecipes);

                if (filteredRecipes.isEmpty) {
                  return _buildEmptyState(context);
                }

                // Group by continent → country → region
                final grouped = _groupRecipesByLocation(filteredRecipes);

                return ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: grouped.entries.map((continentEntry) {
                    return _buildContinentSection(
                      context,
                      continentEntry.key,
                      continentEntry.value,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.showAddButton
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            )
          : null,
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

    // Filter by continent
    if (_selectedContinent != 'All') {
      filtered = filtered.where((r) {
        final continent = ContinentMapping.getContinentFromCuisine(r.cuisine);
        return continent == _selectedContinent;
      }).toList();
    }

    return filtered;
  }

  Map<String, Map<String, List<Recipe>>> _groupRecipesByLocation(List<Recipe> recipes) {
    final Map<String, Map<String, List<Recipe>>> grouped = {};

    for (final recipe in recipes) {
      // Auto-populate continent and country if missing
      final continent = recipe.continent ?? 
          ContinentMapping.getContinentFromCuisine(recipe.cuisine) ?? 
          'Other';
      final country = recipe.country ?? 
          ContinentMapping.getCountryFromCuisine(recipe.cuisine) ?? 
          'Unknown';

      grouped.putIfAbsent(continent, () => {});
      grouped[continent]!.putIfAbsent(country, () => []);
      grouped[continent]![country]!.add(recipe);
    }

    return grouped;
  }

  Widget _buildContinentSection(
    BuildContext context,
    String continent,
    Map<String, List<Recipe>> countriesMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Continent header (only show if "All" is selected)
        if (_selectedContinent == 'All')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              continent,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

        // Countries within continent
        ...countriesMap.entries.map((countryEntry) {
          final country = countryEntry.key;
          final recipes = countryEntry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      country,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${recipes.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),

              // Recipe cards
              ...recipes.map((recipe) {
                return RecipeCardEnhanced(
                  recipe: recipe,
                  onTap: () => AppRoutes.toRecipeDetail(context, recipe.uuid),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
